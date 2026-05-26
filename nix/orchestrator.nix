{ pkgs, lib ? pkgs.lib, config, uniDork, postgres, probe }:

pkgs.writeShellApplication {
  name = "unidork";
  runtimeInputs = [
    pkgs.coreutils
    pkgs.postgresql
    pkgs.unison-ucm
    uniDork
    postgres.pg-start
    postgres.pg-stop
    postgres.pg-connect
    postgres.pg-cleanup
    probe.ffprobe-cache
    probe.ffprobe-cache-clean
    probe.unidork-stage-probe
    probe.unidork-stage-probe-clean
  ];
  text = ''
    set -euo pipefail

    : "''${PGDATA:=${config.database.dataDir}}"
    : "''${PGPORT:=${toString config.database.port}}"
    : "''${PGUSER:=${config.database.user}}"
    : "''${PGDATABASE:=${config.database.name}}"
    : "''${PGHOST:=$PGDATA}"
    export PGDATA PGPORT PGUSER PGDATABASE PGHOST

    : "''${UNIDORK_FFPROBE_CACHE:=${config.cache.ffprobeDir}}"
    : "''${UNIDORK_CONFIG:=${config.library.configFile}}"
    : "''${UNIDORK_STAGING:=${config.staging.movies}}"
    : "''${UNIDORK_RENAME_TARGET:=${config.rename.targetDir}}"
    : "''${UNIDORK_MOVIE_FORMAT:=${config.rename.movieFormat}}"
    export UNIDORK_FFPROBE_CACHE UNIDORK_CONFIG UNIDORK_STAGING UNIDORK_RENAME_TARGET UNIDORK_MOVIE_FORMAT

    log_dir="$HOME/.cache/uniDork/logs"
    mkdir -p "$log_dir"

    cmd="''${1:-help}"; shift || true

    ensure_pg() {
      if ! pg_isready -h "$PGHOST" -p "$PGPORT" -q 2>/dev/null; then
        echo "[orchestrator] starting postgres..."
        pg-start
      fi
    }

    run_unison_subcommand() {
      local sub="$1"; shift || true
      unidork-import "$sub" "$@"
    }

    cmd_start()  { pg-start; }
    cmd_stop()   { pg-stop; }

    cmd_probe_lib()   { ensure_pg; ffprobe-cache; }
    cmd_probe_stage() { ensure_pg; unidork-stage-probe; }
    cmd_probe()       { cmd_probe_lib; cmd_probe_stage; }

    cmd_import()    { ensure_pg; run_unison_subcommand import; }
    cmd_identify()  { ensure_pg; run_unison_subcommand identify; }

    cmd_rename() {
      ensure_pg
      apply=0
      for a in "$@"; do [ "$a" = "--apply" ] && apply=1; done
      if [ "$apply" -ne 1 ]; then
        echo "rename is destructive — pass --apply to actually move files."
        echo "for a read-only TMDB report: unidork identify"
        exit 1
      fi
      if [ -z "''${UNIDORK_MOVIE_FORMAT:-}" ]; then
        echo "UNIDORK_MOVIE_FORMAT not set; check nix/config.nix" >&2
        exit 1
      fi
      run_unison_subcommand rename "$UNIDORK_MOVIE_FORMAT"
    }

    cmd_status() {
      ensure_pg
      psql -At <<'SQL'
SELECT '  movies:           ' || COUNT(*)::text FROM movies;
SELECT '  stage probes:     ' || COUNT(*)::text FROM stage_probes;
SELECT '  tmdb searches:    ' || COUNT(*)::text FROM tmdb_search_cache;
SELECT '  rename log rows:  ' || COUNT(*)::text FROM rename_log;
SELECT '  last rename:      ' || COALESCE(MAX(recorded_at)::text, '(none)') FROM rename_log;
SQL
    }

    cmd_run() {
      echo "[orchestrator] start  -> probe-lib -> probe-stage -> import -> identify"
      cmd_start
      cmd_probe_lib
      cmd_probe_stage
      cmd_import
      cmd_identify
      echo "[orchestrator] done. review identify output, then: unidork rename --apply"
    }

    case "$cmd" in
      start)          cmd_start ;;
      stop)           cmd_stop ;;
      status)         cmd_status ;;
      probe)          cmd_probe ;;
      probe-lib)      cmd_probe_lib ;;
      probe-stage)    cmd_probe_stage ;;
      import)         cmd_import ;;
      identify)       cmd_identify ;;
      rename)         cmd_rename "$@" ;;
      run)            cmd_run ;;
      psql|connect)   pg-connect ;;
      clean-lib)      ffprobe-cache-clean ;;
      clean-stage)    unidork-stage-probe-clean ;;
      logs)           ls -la "$log_dir" 2>/dev/null || echo "no logs yet at $log_dir" ;;
      help|--help|-h|"")
        cat <<EOF
unidork - pipeline orchestrator

Usage: unidork <command>

  run             start + probe-lib + probe-stage + import + identify
  start | stop    postgres lifecycle
  status          counts of movies, probes, cache rows, rename log
  probe           probe-lib then probe-stage
  probe-lib       library ffprobe sidecars (files)
  probe-stage     staging probes -> postgres
  import          unidork-import import (library -> movies table)
  identify        unidork-import identify (staging TMDB report)
  rename --apply  unidork-import rename (DESTRUCTIVE: moves files)
  logs            list stderr log files for past runs
  psql            interactive psql to ''${PGDATABASE}
  clean-lib       wipe library ffprobe cache directory
  clean-stage     truncate stage_probes table
EOF
        ;;
      *) echo "unknown command: $cmd" >&2; exit 1 ;;
    esac
  '';
}