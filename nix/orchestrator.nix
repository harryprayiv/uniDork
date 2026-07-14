{ pkgs, lib ? pkgs.lib, config, uniDork, postgres, snapshot, mirror }:

pkgs.writeShellApplication {
  name = "unidork";
  runtimeInputs = [
    pkgs.coreutils
    pkgs.postgresql
    pkgs.unison-ucm
    pkgs.rsync
    pkgs.git
    uniDork
    snapshot
    mirror.unidork-log-change
    mirror.unidork-snapshot
    postgres.pg-ensure
    postgres.pg-start
    postgres.pg-stop
    postgres.pg-connect
    postgres.pg-cleanup
    postgres.pg-backup
    postgres.pg-restore
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
    : "''${UNIDORK_TUNE_SUB_DELAY_MS:=${toString config.subs.delayMs}}"
    export UNIDORK_TUNE_PROBE_JOBS UNIDORK_TUNE_SUB_LANGS UNIDORK_TUNE_SUB_DELAY_MS

    : "''${UNIDORK_MEM_HIGH:=${config.tuning.memoryHigh}}"
    : "''${UNIDORK_MEM_MAX:=${config.tuning.memoryMax}}"
    : "''${UNIDORK_GHCRTS:=${config.tuning.ghcRts}}"
    export UNIDORK_MEM_HIGH UNIDORK_MEM_MAX UNIDORK_GHCRTS

    : "''${UNIDORK_BACKUP_DIR:=${config.database.backup.dir}}"
    : "''${UNIDORK_BACKUP_KEEP:=${toString config.database.backup.keep}}"
    : "''${UNIDORK_BACKUP_AUTO_HOURS:=${toString config.database.backup.autoIntervalHours}}"
    : "''${UNIDORK_AUTO_BACKUP:=1}"
    export UNIDORK_BACKUP_DIR UNIDORK_BACKUP_KEEP UNIDORK_BACKUP_AUTO_HOURS UNIDORK_AUTO_BACKUP

    export PGPORT="$UNIDORK_DB_PORT"
    export PGUSER="$UNIDORK_DB_USER"
    export PGDATABASE="$UNIDORK_DB_NAME"
    export PGHOST="$PGDATA"

    log_dir="$HOME/.cache/uniDork/logs"
    mkdir -p "$log_dir"

    use_scope=0
    if command -v systemd-run >/dev/null 2>&1; then
      if systemd-run --user --scope --quiet --collect true 2>/dev/null; then
        use_scope=1
      fi
    fi
    if [ "$use_scope" = 0 ]; then
      echo "[orchestrator] warn: no user systemd scope available; running without memory cgroup" >&2
    fi

    run_import() {
      if [ "$use_scope" = 1 ]; then
        systemd-run --user --scope --quiet --collect \
          -p "MemoryHigh=$UNIDORK_MEM_HIGH" \
          -p "MemoryMax=$UNIDORK_MEM_MAX" \
          env "GHCRTS=$UNIDORK_GHCRTS" unidork-import "$@"
      else
        GHCRTS="$UNIDORK_GHCRTS" unidork-import "$@"
      fi
    }

    cmd="''${1:-help}"; shift || true

    # Every database-touching command routes through this. pg-ensure is
    # idempotent: running server, stale pid, missing cluster, and missing
    # database are all handled. It never fails because the db is "already
    # running".
    ensure_pg() { pg-ensure; }

    # Throttled safety net taken before destructive verbs. Non-fatal on
    # purpose: an unmounted backup volume should not block a rename you
    # explicitly asked for, but you WILL be yelled at.
    auto_backup() {
      if [ "$UNIDORK_AUTO_BACKUP" = 1 ]; then
        if ! pg-backup --auto; then
          echo "[orchestrator] WARNING: auto-backup failed (backup root missing/unmounted?)." >&2
          echo "[orchestrator] Proceeding anyway. Run 'unidork backup --init' with the volume mounted." >&2
        fi
      fi
    }

    has_flag() {
      flag="$1"; shift
      for a in "$@"; do [ "$a" = "$flag" ] && return 0; done
      return 1
    }
    cmd_push() { unidork-push; }
    cmd_log_change() { unidork-log-change "$@"; }
    cmd_snapshot()   { unidork-snapshot; }
    cmd_start()  { pg-ensure; }
    cmd_stop()   { pg-stop; }

    cmd_backup()  { ensure_pg; pg-backup "$@"; }
    cmd_backups() { pg-backup --list; }
    cmd_restore() { ensure_pg; pg-restore "$@"; }

    cmd_probe()    { ensure_pg; run_import probe-stage; }
    cmd_resolve()  { ensure_pg; run_import resolve; }
    cmd_identify() { ensure_pg; run_import identify; }
    cmd_process()  { ensure_pg; auto_backup; run_import process "$@"; }
    cmd_move()     { ensure_pg; auto_backup; run_import move "$@"; }
    cmd_subs()     { ensure_pg; run_import subs "$@"; }

    cmd_reconcile()      { ensure_pg; run_import reconcile; }
    cmd_import_library() { ensure_pg; auto_backup; run_import import-library "$UNIDORK_PATH_CONFIG"; }
    cmd_import_all()     { ensure_pg; auto_backup; run_import import-all "$UNIDORK_PATH_CONFIG"; }

    cmd_rename() {
      ensure_pg
      if has_flag "--dry-run" "$@"; then
        run_import rename "$UNIDORK_FORMAT_MOVIE" --dry-run
      elif has_flag "--apply" "$@"; then
        auto_backup
        run_import rename "$UNIDORK_FORMAT_MOVIE"
      else
        echo "rename is destructive. pass --apply to move files, or --dry-run to preview."
        exit 1
      fi
    }

    cmd_tv_init()     { ensure_pg; run_import tv-init; }
    cmd_tv_probe()    { ensure_pg; run_import tv-probe; }
    cmd_tv_resolve()  { ensure_pg; run_import tv-resolve; }
    cmd_tv_identify() { ensure_pg; run_import tv-identify; }
    cmd_tv_process()  { ensure_pg; auto_backup; run_import tv-process "$@"; }
    cmd_tv_move()     { ensure_pg; auto_backup; run_import tv-move "$@"; }

    cmd_tv_rename() {
      ensure_pg
      if has_flag "--dry-run" "$@"; then
        run_import tv-rename --dry-run
      elif has_flag "--apply" "$@"; then
        auto_backup
        run_import tv-rename
      else
        echo "tv-rename is destructive. pass --apply to move files, or --dry-run to preview."
        exit 1
      fi
    }

    cmd_process_all() {
      ensure_pg
      auto_backup
      echo "[orchestrator] === movie process ==="
      run_import process
      echo ""
      echo "[orchestrator] === tv process ==="
      run_import tv-process
      echo ""
      echo "[orchestrator] both pipelines done."
      echo "  review movie buffer: $UNIDORK_PATH_BUFFER"
      echo "  review tv buffer:    $UNIDORK_PATH_TV_BUFFER"
    }

    cmd_run_all() {
      echo "[orchestrator] ensure -> backup -> import-library -> movie process -> tv process"
      ensure_pg
      auto_backup
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
      echo "=== backups ==="
      pg-backup --list 2>/dev/null | sed 's/^/  /' || echo "  (backup root not initialized: unidork backup --init)"
    }

    case "$cmd" in
      push)           cmd_push ;;
      log-change)          cmd_log_change "$@" ;;
      snapshot)            cmd_snapshot ;;
      start)          cmd_start ;;
      stop)           cmd_stop ;;

      backup)              cmd_backup "$@" ;;
      backups)             cmd_backups ;;
      restore)             cmd_restore "$@" ;;

      probe|probe-stage)   cmd_probe ;;
      resolve)             cmd_resolve ;;
      identify)            cmd_identify ;;
      process)             cmd_process "$@" ;;
      move)                cmd_move "$@" ;;
      subs)                cmd_subs "$@" ;;
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

DATABASE SAFETY
  Every db-touching command routes through pg-ensure (idempotent: handles
  already-running, stale pid after a crash, missing cluster, missing db).
  Destructive verbs take a throttled auto-backup first (skipped if a backup
  newer than $UNIDORK_BACKUP_AUTO_HOURS h exists; disable with UNIDORK_AUTO_BACKUP=0).

  backup [--init|--list]   dump db -> $UNIDORK_BACKUP_DIR (verified, checksummed,
                           keeps newest $UNIDORK_BACKUP_KEEP). --init once, with volume mounted.
  backups                  list available dumps
  restore <file|latest>    restore into a FRESH database (live db untouched)
  restore <f> --swap       ...then swap names; old db kept as <name>_pre_restore_<ts>

DRY RUN
  Every destructive verb accepts --dry-run: no file is created, moved, or
  deleted. DB metadata (probe rows, associations, TMDB caches) may still be
  written.

MEMORY
  unidork-import runs inside a systemd user scope with
  MemoryHigh=$UNIDORK_MEM_HIGH / MemoryMax=$UNIDORK_MEM_MAX when a user
  session bus is available. Override per-run with UNIDORK_MEM_HIGH,
  UNIDORK_MEM_MAX, UNIDORK_GHCRTS.

MOVIE PIPELINE
  process [--dry-run]        probe + resolve + rename -> movie buffer   (DESTRUCTIVE without --dry-run)
  probe                      probe movie intake -> files (stage=staging)
  resolve                    associate staging movie files -> tmdb movies
  identify                   read-only resolver report for movie intake
  rename --apply|--dry-run   rename staging movies into buffer          (DESTRUCTIVE with --apply)
  move [folder] [--dry-run]  promote buffer folder(s) into movie library
  subs [--dry-run]           fetch missing subtitle sidecars for buffer movies (paced: UNIDORK_TUNE_SUB_DELAY_MS)
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
  run               backup + import-library + movie process + tv process

UTILITY
  push              push to Unison Share + snapshot diff to git mirror
  start | stop      postgres lifecycle (start == ensure, always safe)
  status            row counts across all tables + backup inventory
  psql              interactive psql session
  clean-stage       truncate probe_cache
  logs              list log files
EOF
        ;;
      *) echo "unknown command: $cmd" >&2; exit 1 ;;
    esac
  '';
}