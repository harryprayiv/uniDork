{ pkgs, lib ? pkgs.lib, config, secrets, uniDork, postgres, snapshot, mirror }:

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
    secrets.doctor
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

${secrets.envSetup}

    export UNIDORK_ART_MOVIES="${lib.concatStringsSep "," config.artwork.movies}"
    export UNIDORK_ART_TV="${lib.concatStringsSep "," config.artwork.tv}"
    export UNIDORK_ART_THROTTLE_TMDB_MS="${toString config.artwork.tmdbThrottleMs}"
    export UNIDORK_ART_THROTTLE_FANART_MS="${toString config.artwork.fanartThrottleMs}"

    : "''${UNIDORK_TUNE_PARTITION_SESSION:=${toString (config.tuning.partitionSession or 50)}}"
    : "''${UNIDORK_TUNE_SWEEP_CHUNK:=${toString (config.tuning.sweepChunk or 100)}}"
    : "''${UNIDORK_TUNE_SUBS_CHUNK:=${toString (config.tuning.subsChunk or 100)}}"
    : "''${UNIDORK_TUNE_PROBE_CONN_CHUNKS:=${toString (config.tuning.probeConnChunks or 4)}}"
    : "''${UNIDORK_TUNE_STAGE_TIMEOUT:=${config.tuning.stageTimeout or "4h"}}"
    export UNIDORK_TUNE_PARTITION_SESSION UNIDORK_TUNE_SWEEP_CHUNK
    export UNIDORK_TUNE_SUBS_CHUNK UNIDORK_TUNE_PROBE_CONN_CHUNKS
    export UNIDORK_TUNE_STAGE_TIMEOUT

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
      echo "[unidork] warn: no user systemd scope; running without a memory cgroup" >&2
    fi

    run_import() {
      if [ "$use_scope" = 1 ]; then
        systemd-run --user --scope --quiet --collect \
          -p "MemoryHigh=$UNIDORK_MEM_HIGH" \
          -p "MemoryMax=$UNIDORK_MEM_MAX" \
          env "GHCRTS=$UNIDORK_GHCRTS" \
          timeout --kill-after=30s "$UNIDORK_TUNE_STAGE_TIMEOUT" unidork-import "$@"
      else
        GHCRTS="$UNIDORK_GHCRTS" \
          timeout --kill-after=30s "$UNIDORK_TUNE_STAGE_TIMEOUT" unidork-import "$@"
      fi
    }

    ensure_pg() { pg-ensure; }

    auto_backup() {
      if [ "$UNIDORK_AUTO_BACKUP" = 1 ]; then
        if ! pg-backup --auto; then
          echo "[unidork] WARNING: auto-backup failed (backup root unmounted?)." >&2
          echo "[unidork] Proceeding. Run 'unidork backup --init' with the volume mounted." >&2
        fi
      fi
    }


    movie_stages() {
      printf '%s\n' \
        'probe|no|intake -> files(stage=staging)|movie-probe' \
        'resolve|no|staging files -> tmdb associations|movie-resolve' \
        'rename|yes|staging -> buffer (UNIDORK_FORMAT_MOVIE)|movie-rename' \
        'sweep|yes|drop emptied staging dirs and stale rows|sweep-stage' \
        'subs|yes|fetch missing subtitle sidecars in buffer|movie-subs' \
        'move|yes|buffer -> library|movie-move' \
        'index|no|library dirs -> files + library_movies|movie-index' \
        'versions|no|detect multi-copy editions (db only)|movie-versions' \
        'nfo|yes|stamp version tags into movie.nfo|movie-nfo' \
        'artwork|yes|fetch artwork into library folders|movie-artwork' \
        'artscan|no|inventory artwork on disk -> artwork_log|artwork-scan'
    }

    tv_stages() {
      printf '%s\n' \
        'probe|no|tv intake -> files(stage=staging)|tv-probe' \
        'resolve|no|staging files -> shows/episodes|tv-resolve' \
        'rename|yes|staging -> tv buffer (UNIDORK_FORMAT_TV)|tv-rename' \
        'sweep|yes|drop emptied staging dirs and stale rows|sweep-stage' \
        'move|yes|tv buffer -> tv library|tv-move' \
        'artwork|yes|fetch show artwork into library folders|tv-artwork' \
        'artscan|no|inventory artwork on disk -> artwork_log|artwork-scan'
    }


    OPT_MODE=preview
    OPT_FROM=""
    OPT_TO=""
    OPT_ONLY=""
    OPT_SKIP=""

    parse_pipeline_opts() {
      OPT_MODE=preview
      OPT_FROM=""
      OPT_TO=""
      OPT_ONLY=""
      OPT_SKIP=""
      while [ "$#" -gt 0 ]; do
        case "$1" in
          --apply)    OPT_MODE=apply ;;
          --dry-run)  OPT_MODE=dryrun ;;
          --list)     OPT_MODE=list ;;
          --from)     shift; OPT_FROM="''${1:-}" ;;
          --from=*)   OPT_FROM="''${1#--from=}" ;;
          --to)       shift; OPT_TO="''${1:-}" ;;
          --to=*)     OPT_TO="''${1#--to=}" ;;
          --only)     shift; OPT_ONLY="''${1:-}" ;;
          --only=*)   OPT_ONLY="''${1#--only=}" ;;
          --skip)     shift; OPT_SKIP="''${1:-}" ;;
          --skip=*)   OPT_SKIP="''${1#--skip=}" ;;
          *)
            echo "unidork: unknown option '$1'" >&2
            return 1
            ;;
        esac
        shift
      done
    }

    in_csv() {
      needle="$1"
      csv="$2"
      if [ -z "$csv" ]; then
        return 1
      fi
      case ",$csv," in
        *",$needle,"*) return 0 ;;
      esac
      return 1
    }

    select_stages() {
      started=0
      stopped=0
      if [ -z "$OPT_FROM" ]; then
        started=1
      fi
      while IFS='|' read -r id destructive desc verb; do
        if [ -z "$id" ]; then
          continue
        fi
        if [ "$stopped" = 1 ]; then
          continue
        fi
        if [ -n "$OPT_ONLY" ]; then
          if in_csv "$id" "$OPT_ONLY"; then
            printf '%s|%s|%s|%s\n' "$id" "$destructive" "$desc" "$verb"
          fi
          continue
        fi
        if [ "$started" = 0 ]; then
          if [ "$id" = "$OPT_FROM" ]; then
            started=1
          else
            continue
          fi
        fi
        if in_csv "$id" "$OPT_SKIP"; then
          if [ -n "$OPT_TO" ] && [ "$id" = "$OPT_TO" ]; then
            stopped=1
          fi
          continue
        fi
        printf '%s|%s|%s|%s\n' "$id" "$destructive" "$desc" "$verb"
        if [ -n "$OPT_TO" ] && [ "$id" = "$OPT_TO" ]; then
          stopped=1
        fi
      done
    }

    print_plan() {
      domain="$1"
      table="$2"
      total="$3"
      echo "[$domain] plan, $total stage(s):"
      n=0
      while IFS='|' read -r id destructive desc verb; do
        n=$((n + 1))
        mark=" "
        if [ "$destructive" = yes ]; then
          mark="!"
        fi
        printf '  %s %2d. %-9s %-44s (%s)\n' "$mark" "$n" "$id" "$desc" "$verb"
      done < <(printf '%s\n' "$table")
    }

    run_pipeline() {
      domain="$1"
      shift
      parse_pipeline_opts "$@" || return 1

      case "$domain" in
        movie) table="$(movie_stages | select_stages)" ;;
        tv)    table="$(tv_stages | select_stages)" ;;
        *)     echo "unidork: unknown pipeline '$domain'" >&2; return 1 ;;
      esac

      if [ -z "$table" ]; then
        echo "unidork: stage selection matched nothing" >&2
        echo "unidork: valid ids: $(printf '%s\n' "$table")" >&2
        return 1
      fi

      total="$(printf '%s\n' "$table" | wc -l | tr -d ' ')"

      if [ "$OPT_MODE" = list ]; then
        print_plan "$domain" "$table" "$total"
        return 0
      fi

      if [ "$OPT_MODE" = preview ]; then
        print_plan "$domain" "$table" "$total"
        echo ""
        echo "  ! = writes to the filesystem"
        echo ""
        echo "  unidork $domain --dry-run    walk every stage, touch no file"
        echo "  unidork $domain --apply      run it for real"
        return 1
      fi

      resume_flag="--apply"
      if [ "$OPT_MODE" = dryrun ]; then
        resume_flag="--dry-run"
      fi

      ensure_pg
      if [ "$OPT_MODE" = apply ]; then
        auto_backup
      fi

      echo "[$domain] $total stage(s), mode=$OPT_MODE"
      pipeline_start="$(date +%s)"
      n=0
      while IFS='|' read -r id destructive desc verb; do
        n=$((n + 1))
        flags=()
        if [ "$destructive" = yes ] && [ "$OPT_MODE" != apply ]; then
          flags+=(--dry-run)
        fi
        echo ""
        echo "[$domain $n/$total] $id: $desc"
        stage_start="$(date +%s)"
        if ! run_import "$verb" "''${flags[@]}"; then
          echo "" >&2
          echo "[$domain] FAILED at '$id' (unidork-import $verb)" >&2
          echo "[$domain] fix it, then resume from that stage with:" >&2
          echo "    unidork $domain --from=$id $resume_flag" >&2
          return 1
        fi
        echo "[$domain $n/$total] $id ok ($(( $(date +%s) - stage_start ))s)"
      done < <(printf '%s\n' "$table")

      echo ""
      echo "[$domain] complete in $(( $(date +%s) - pipeline_start ))s"
      if [ "$OPT_MODE" = dryrun ]; then
        echo "[$domain] dry run: no file was created, moved, or deleted."
      fi
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

    cmd_clean_stage() {
      ensure_pg
      echo "[clean-stage] truncating probe_cache"
      psql -At -v ON_ERROR_STOP=1 -c "TRUNCATE probe_cache"
      echo "[clean-stage] done (files and associations left intact)"
    }

    cmd_schema() {
      ensure_pg
      run_import db-init
      run_import db-migrate
      run_import db-tv-init
      echo "[schema] movie and tv schemas present"
    }

    cmd_stage() {
      if [ "$#" -eq 0 ]; then
        echo "usage: unidork stage <import-verb> [args] [--dry-run]" >&2
        echo "       unidork stage help    lists every verb" >&2
        return 1
      fi
      ensure_pg
      run_import "$@"
    }

    usage() {
      cat <<'HELP'
unidork - media pipeline

TWO COMMANDS DO EVERYTHING

  unidork movies --apply        run the whole movie pipeline, in order
  unidork tv     --apply        run the whole tv pipeline, in order
  unidork all    --apply        movies then tv

  Each stage is a separate unidork-import process, so every stage gets a
  fresh heap. Order lives in the stage table, nowhere else.

PIPELINE FLAGS (movies | tv | all)

  (none)          print the ordered plan and exit non-zero. safe default.
  --list          print the ordered plan and exit 0
  --dry-run       run every stage; destructive stages touch no file
  --apply         run for real; takes a throttled auto-backup first
  --from=ID       start at stage ID (this is how you resume after a crash)
  --to=ID         stop after stage ID
  --only=ID,ID    run exactly these stages, in table order
  --skip=ID,ID    run everything except these

MOVIE STAGE IDS, in order
  probe resolve rename sweep subs move index versions nfo artwork artscan

TV STAGE IDS, in order
  probe resolve rename sweep move artwork artscan

ESCAPE HATCH

  unidork stage <verb> [args]   run one unidork-import verb directly
  unidork stage help            list every verb the binary understands

  Examples:
    unidork stage movie-move "Blade Runner (1982)" --dry-run
    unidork stage movie-identify
    unidork stage tv-reconcile
    unidork stage sweep-missing

DATABASE

  schema                   create/migrate movie and tv schemas
  backup [--init|--list]   dump db, verified and checksummed
  backups                  list dumps
  restore <file|latest>    restore into a fresh database
  restore <f> --swap       ...then swap names
  start | stop             postgres lifecycle (start == ensure, safe)
  status                   row counts and backup inventory
  psql                     interactive session
  clean-stage              truncate probe_cache

SECRETS

  secrets                  show where each API key resolves from

CODEBASE

  push | log-change | snapshot | logs

MEMORY

  Stages run inside a systemd user scope with MemoryHigh/MemoryMax when a
  session bus exists. Override with UNIDORK_MEM_HIGH, UNIDORK_MEM_MAX,
  UNIDORK_GHCRTS, UNIDORK_TUNE_STAGE_TIMEOUT.
HELP
    }


    cmd="''${1:-help}"
    shift || true

    case "$cmd" in
      movies|movie)  run_pipeline movie "$@" ;;
      tv)            run_pipeline tv "$@" ;;
      all)
        run_pipeline movie "$@"
        echo ""
        run_pipeline tv "$@"
        ;;

      stage)         cmd_stage "$@" ;;

      schema)        cmd_schema ;;
      backup)        ensure_pg; pg-backup "$@" ;;
      backups)       pg-backup --list ;;
      restore)       ensure_pg; pg-restore "$@" ;;
      start)         pg-ensure ;;
      stop)          pg-stop ;;
      status)        cmd_status ;;
      psql|connect)  pg-connect ;;
      secrets)       unidork-secrets ;;
      clean-stage)   cmd_clean_stage ;;

      push)          unidork-push ;;
      log-change)    unidork-log-change "$@" ;;
      snapshot)      unidork-snapshot ;;
      logs)          ls -la "$log_dir" 2>/dev/null || echo "no logs yet at $log_dir" ;;

      help|--help|-h|"") usage ;;
      *)
        echo "unidork: unknown command '$cmd'" >&2
        echo "try: unidork help" >&2
        exit 1
        ;;
    esac
  '';
}
