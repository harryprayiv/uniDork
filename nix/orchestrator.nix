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

    : "''${UNIDORK_PATH_TV_INTAKE:=${config.paths.tvIntake}}"
    : "''${UNIDORK_PATH_TV_BUFFER:=${config.paths.tvBuffer}}"
    : "''${UNIDORK_PATH_TV_LIBRARY:=${config.paths.tvLibrary}}"
    export UNIDORK_PATH_TV_INTAKE UNIDORK_PATH_TV_BUFFER UNIDORK_PATH_TV_LIBRARY

    : "''${UNIDORK_FORMAT_MOVIE:=${config.rename.movieFormat}}"
    : "''${UNIDORK_FORMAT_TV:=${config.rename.tvFormat}}"
    export UNIDORK_FORMAT_MOVIE UNIDORK_FORMAT_TV

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

    has_flag() {
      flag="$1"; shift
      for a in "$@"; do [ "$a" = "$flag" ] && return 0; done
      return 1
    }

    cmd_start()  { pg-start; }
    cmd_stop()   { pg-stop; }

    cmd_probe()    { ensure_pg; unidork-import probe-stage; }
    cmd_resolve()  { ensure_pg; unidork-import resolve; }
    cmd_identify() { ensure_pg; unidork-import identify; }
    cmd_process()  { ensure_pg; unidork-import process "$@"; }
    cmd_move()     { ensure_pg; unidork-import move "$@"; }

    cmd_reconcile()      { ensure_pg; unidork-import reconcile; }
    cmd_import_library() { ensure_pg; unidork-import import-library "$UNIDORK_PATH_CONFIG"; }
    cmd_import_all()     { ensure_pg; unidork-import import-all "$UNIDORK_PATH_CONFIG"; }

    cmd_rename() {
      ensure_pg
      if has_flag "--dry-run" "$@"; then
        unidork-import rename "$UNIDORK_FORMAT_MOVIE" --dry-run
      elif has_flag "--apply" "$@"; then
        unidork-import rename "$UNIDORK_FORMAT_MOVIE"
      else
        echo "rename is destructive. pass --apply to move files, or --dry-run to preview."
        exit 1
      fi
    }

    cmd_tv_init()     { ensure_pg; unidork-import tv-init; }
    cmd_tv_probe()    { ensure_pg; unidork-import tv-probe; }
    cmd_tv_resolve()  { ensure_pg; unidork-import tv-resolve; }
    cmd_tv_identify() { ensure_pg; unidork-import tv-identify; }
    cmd_tv_process()  { ensure_pg; unidork-import tv-process "$@"; }
    cmd_tv_move()     { ensure_pg; unidork-import tv-move "$@"; }

    cmd_tv_rename() {
      ensure_pg
      if has_flag "--dry-run" "$@"; then
        unidork-import tv-rename --dry-run
      elif has_flag "--apply" "$@"; then
        unidork-import tv-rename
      else
        echo "tv-rename is destructive. pass --apply to move files, or --dry-run to preview."
        exit 1
      fi
    }

    cmd_process_all() {
      ensure_pg
      echo "[orchestrator] === movie process ==="
      unidork-import process
      echo ""
      echo "[orchestrator] === tv process ==="
      unidork-import tv-process
      echo ""
      echo "[orchestrator] both pipelines done."
      echo "  review movie buffer: $UNIDORK_PATH_BUFFER"
      echo "  review tv buffer:    $UNIDORK_PATH_TV_BUFFER"
    }

    cmd_run_all() {
      echo "[orchestrator] start -> import-library -> movie process -> tv process"
      cmd_start
      cmd_import_library
      cmd_process
      cmd_tv_process
      echo "[orchestrator] done."
    }

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

    cmd_status() {
      ensure_pg
      echo "=== files ==="
      psql -At <<'SQL'
SELECT '  total:              ' || COUNT(*)::text FROM files;
SELECT '  staging (movie):    ' || COUNT(*)::text FROM files WHERE stage = 'staging' AND media_kind = 'movie';
SELECT '  staging (episode):  ' || COUNT(*)::text FROM files WHERE stage = 'staging' AND media_kind = 'episode';
SELECT '  buffer:             ' || COUNT(*)::text FROM files WHERE stage = 'buffer';
SELECT '  library:            ' || COUNT(*)::text FROM files WHERE stage = 'library';
SQL
      echo "=== movies ==="
      psql -At <<'SQL'
SELECT '  tmdb movies:        ' || COUNT(*)::text FROM movies;
SELECT '  associations:       ' || COUNT(*)::text FROM associations;
SELECT '  library_movies:     ' || COUNT(*)::text FROM library_movies;
SQL
      if psql -At -c "SELECT 1 FROM information_schema.tables WHERE table_name = 'shows'" 2>/dev/null | grep -q 1; then
        echo "=== tv ==="
        psql -At <<'SQL'
SELECT '  shows:              ' || COUNT(*)::text FROM shows;
SELECT '  episodes:           ' || COUNT(*)::text FROM episodes;
SELECT '  ep associations:    ' || COUNT(*)::text FROM episode_associations;
SQL
      fi
      echo "=== cache ==="
      psql -At <<'SQL'
SELECT '  probe_cache:        ' || COUNT(*)::text FROM probe_cache;
SELECT '  tmdb searches:      ' || COUNT(*)::text FROM tmdb_search_cache;
SQL
      if psql -At -c "SELECT 1 FROM information_schema.tables WHERE table_name = 'tmdb_tv_search_cache'" 2>/dev/null | grep -q 1; then
        psql -At <<'SQL'
SELECT '  tmdb tv searches:   ' || COUNT(*)::text FROM tmdb_tv_search_cache;
SELECT '  season cache:       ' || COUNT(*)::text FROM tmdb_season_cache;
SQL
      fi
    }

    case "$cmd" in
      start)          cmd_start ;;
      stop)           cmd_stop ;;

      probe|probe-stage)   cmd_probe ;;
      resolve)             cmd_resolve ;;
      identify)            cmd_identify ;;
      process)             cmd_process "$@" ;;
      move)                cmd_move "$@" ;;
      rename)              cmd_rename "$@" ;;
      probe-resolve)       cmd_probe_resolve ;;
      reconcile|import-buffer) cmd_reconcile ;;
      import-library)      cmd_import_library ;;
      import-all)          cmd_import_all ;;

      tv-init)             cmd_tv_init ;;
      tv-probe)            cmd_tv_probe ;;
      tv-resolve)          cmd_tv_resolve ;;
      tv-identify)         cmd_tv_identify ;;
      tv-rename)           cmd_tv_rename "$@" ;;
      tv-process)          cmd_tv_process "$@" ;;
      tv-move)             cmd_tv_move "$@" ;;

      process-all)         cmd_process_all ;;
      run-all)             cmd_run_all ;;
      run)                 cmd_run_all ;;

      status)              cmd_status ;;
      psql|connect)        pg-connect ;;
      clean-stage)         cmd_clean_stage ;;
      logs)                ls -la "$log_dir" 2>/dev/null || echo "no logs yet at $log_dir" ;;

      help|--help|-h|"")
        cat <<EOF
unidork - pipeline orchestrator

DRY RUN
  Every destructive verb accepts --dry-run: no file is created, moved, or
  deleted. DB metadata (probe rows, associations, TMDB caches) may still be
  written.

MOVIE PIPELINE
  process [--dry-run]        probe + resolve + rename -> movie buffer   (DESTRUCTIVE without --dry-run)
  probe                      probe movie intake -> files (stage=staging)
  resolve                    associate staging movie files -> tmdb movies
  identify                   read-only resolver report for movie intake
  rename --apply|--dry-run   rename staging movies into buffer          (DESTRUCTIVE with --apply)
  move [folder] [--dry-run]  promote buffer folder(s) into movie library
  reconcile                  probe movie buffer (repair/record existing files)
  import-library             scan library dirs -> files + library_movies
  import-all                 reconcile + import-library

TV PIPELINE
  tv-process [--dry-run]        probe + resolve + rename -> tv buffer   (DESTRUCTIVE without --dry-run)
  tv-probe                      probe tv intake -> files
  tv-resolve                    associate staging episode files -> shows/episodes
  tv-identify                   read-only resolver report for tv intake
  tv-rename --apply|--dry-run   rename staging episodes into tv buffer  (DESTRUCTIVE with --apply)
  tv-move [folder] [--dry-run]  promote tv buffer show folder(s) into tv library
  tv-init                       create tv schema tables

COMBINED
  process-all       movie process then tv process                       (DESTRUCTIVE)
  run               import-library + movie process + tv process

UTILITY
  start | stop      postgres lifecycle
  status            row counts across all tables
  psql              interactive psql session
  clean-stage       truncate probe_cache
  logs              list log files
EOF
        ;;
      *) echo "unknown command: $cmd" >&2; exit 1 ;;
    esac
  '';
}