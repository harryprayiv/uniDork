{ pkgs, lib ? pkgs.lib, config, uniDork, postgres }:

pkgs.writeShellApplication {
  name = "unidork";
  runtimeInputs = [
    pkgs.coreutils
    pkgs.postgresql
    pkgs.unison-ucm
    pkgs.rsync
    uniDork
    postgres.pg-start
    postgres.pg-stop
    postgres.pg-connect
    postgres.pg-cleanup
  ];
  text = ''
    set -euo pipefail

    : "''${PGDATA:=${config.database.dataDir}}"
    export PGDATA

    : "''${UNIDORK_DB_HOST:=${config.database.host}}"
    : "''${UNIDORK_DB_PORT:=${toString config.database.port}}"
    : "''${UNIDORK_DB_USER:=${config.database.user}}"
    : "''${UNIDORK_DB_NAME:=${config.database.name}}"
    export UNIDORK_DB_HOST UNIDORK_DB_PORT UNIDORK_DB_USER UNIDORK_DB_NAME

    : "''${UNIDORK_CACHE_FFPROBE:=${config.cache.ffprobeDir}}"
    : "''${UNIDORK_CACHE_STAGE:=${config.cache.stageDir}}"
    export UNIDORK_CACHE_FFPROBE UNIDORK_CACHE_STAGE

    : "''${UNIDORK_PATH_CONFIG:=${config.paths.configFile}}"
    : "''${UNIDORK_PATH_INTAKE:=${config.paths.intake}}"
    : "''${UNIDORK_PATH_BUFFER:=${config.paths.buffer}}"
    : "''${UNIDORK_PATH_LIBRARY:=${config.paths.library}}"
    export UNIDORK_PATH_CONFIG UNIDORK_PATH_INTAKE UNIDORK_PATH_BUFFER UNIDORK_PATH_LIBRARY

    : "''${UNIDORK_FORMAT_MOVIE:=${config.rename.movieFormat}}"
    export UNIDORK_FORMAT_MOVIE

    : "''${UNIDORK_TOKEN_TMDB:=${config.tmdb.tokenFile}}"
    : "''${UNIDORK_TOKEN_SUB:=${config.subs.tokenFile}}"
    export UNIDORK_TOKEN_TMDB UNIDORK_TOKEN_SUB

    : "''${UNIDORK_TUNE_PROBE_JOBS:=${toString config.tuning.probeJobs}}"
    : "''${UNIDORK_TUNE_SUB_LANGS:=${lib.concatStringsSep "," config.subs.languages}}"
    export UNIDORK_TUNE_PROBE_JOBS UNIDORK_TUNE_SUB_LANGS

    export PGPORT="$UNIDORK_DB_PORT"
    export PGUSER="$UNIDORK_DB_USER"
    export PGDATABASE="$UNIDORK_DB_NAME"
    export PGHOST="$PGDATA"

    log_dir="$HOME/.cache/uniDork/logs"
    mkdir -p "$log_dir"

    cmd="''${1:-help}"; shift || true

    ensure_pg() {
      if ! pg_isready -h "$PGHOST" -p "$PGPORT" -q 2>/dev/null; then
        echo "[orchestrator] starting postgres..."
        pg-start
      fi
    }

    cmd_start()  { pg-start; }
    cmd_stop()   { pg-stop; }

    cmd_probe()    { ensure_pg; unidork-import probe-stage; }
    cmd_resolve()  { ensure_pg; unidork-import resolve; }
    cmd_identify() { ensure_pg; unidork-import identify; }

    cmd_import_buffer()  { ensure_pg; unidork-import import-buffer; }
    cmd_import_library() { ensure_pg; unidork-import import-library "$UNIDORK_PATH_CONFIG"; }
    cmd_import_all()     { ensure_pg; unidork-import import-all "$UNIDORK_PATH_CONFIG"; }

    cmd_move() { ensure_pg; unidork-import move "$@"; }

    cmd_probe_resolve() {
      cmd_probe
      cmd_resolve
    }

    cmd_clean_stage() {
      ensure_pg
      echo "[clean-stage] truncating probe_cache"
      psql -At -v ON_ERROR_STOP=1 -c "TRUNCATE probe_cache"
      echo "[clean-stage] done (files + associations left intact)"
    }

    cmd_rename() {
      ensure_pg
      apply=0
      for a in "$@"; do [ "$a" = "--apply" ] && apply=1; done
      if [ "$apply" -ne 1 ]; then
        echo "rename is destructive — pass --apply to actually move files."
        echo "for a read-only TMDB report: unidork identify"
        exit 1
      fi
      unidork-import rename "$UNIDORK_FORMAT_MOVIE"
    }

    cmd_status() {
      ensure_pg
      psql -At <<'SQL'
SELECT '  files:            ' || COUNT(*)::text FROM files;
SELECT '  buffer files:     ' || COUNT(*)::text FROM files WHERE stage = 'buffer';
SELECT '  library files:    ' || COUNT(*)::text FROM files WHERE stage = 'library';
SELECT '  library movies:   ' || COUNT(*)::text FROM library_movies;
SELECT '  crc mismatches:   ' || COUNT(*)::text FROM library_movies WHERE crc32 IS NOT NULL AND crc32 <> folder_checksum;
SELECT '  movies:           ' || COUNT(*)::text FROM movies;
SELECT '  associations:     ' || COUNT(*)::text FROM associations;
SELECT '  probe cache:      ' || COUNT(*)::text FROM probe_cache;
SELECT '  tmdb searches:    ' || COUNT(*)::text FROM tmdb_search_cache;
SQL
    }

    cmd_run() {
      echo "[orchestrator] start -> probe-stage -> import-library -> resolve"
      cmd_start
      cmd_probe
      cmd_import_library
      cmd_resolve
      echo "[orchestrator] done. review, then: unidork rename --apply"
    }

    case "$cmd" in
      start)          cmd_start ;;
      stop)           cmd_stop ;;
      status)         cmd_status ;;
      probe)          cmd_probe ;;
      probe-stage)    cmd_probe ;;
      probe-resolve)  cmd_probe_resolve ;;
      import-buffer)  cmd_import_buffer ;;
      import-library) cmd_import_library ;;
      import-all)     cmd_import_all ;;
      move)           cmd_move "$@" ;;
      resolve)        cmd_resolve ;;
      identify)       cmd_identify ;;
      rename)         cmd_rename "$@" ;;
      run)            cmd_run ;;
      psql|connect)   pg-connect ;;
      clean-stage)    cmd_clean_stage ;;
      logs)           ls -la "$log_dir" 2>/dev/null || echo "no logs yet at $log_dir" ;;
      help|--help|-h|"")
        cat <<EOF
unidork - pipeline orchestrator

Usage: unidork <command>

  run             start + probe-stage + import-library + resolve
  start | stop    postgres lifecycle
  status          row counts (files split by stage)
  probe-stage     intake probes -> files (stage=staging)
  probe-resolve   probe then resolve
  import-buffer   probe buffer -> files (stage=buffer, not resolved)
  import-library  library -> files + library_movies (stage=library)
  import-all      import-buffer then import-library
  move [folder]   promote buffer folder(s) into the library
                  (DESTRUCTIVE: rsync to library + delete from buffer)
  resolve         associate files -> movies (skips stage=buffer)
  identify        read-only TMDB report
  rename --apply  DESTRUCTIVE: moves intake files into the buffer
  logs            list stderr log files
  psql            interactive psql to ''${UNIDORK_DB_NAME}
  clean-stage     truncate probe_cache
EOF
        ;;
      *) echo "unknown command: $cmd" >&2; exit 1 ;;
    esac
  '';
}