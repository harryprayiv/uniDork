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

    schema_present() {
      psql -At -c "SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'files'" 2>/dev/null | grep -q 1
    }

    orphan_dbs() {
      psql -At -d postgres -c \
        "SELECT datname || '  ' || pg_size_pretty(pg_database_size(datname))
           FROM pg_database
          WHERE datname LIKE '$PGDATABASE' || '_restored_%'
             OR datname LIKE '$PGDATABASE' || '_pre_restore_%'
          ORDER BY datname DESC"
    }

    require_schema() {
      if schema_present; then
        return 0
      fi
      echo "" >&2
      echo "[unidork] database \"$PGDATABASE\" has no uniDork schema." >&2
      echo "" >&2
      echo "  This looks like a fresh cluster. Pick one:" >&2
      echo "" >&2
      echo "    unidork bootstrap          restore the newest backup, or create an" >&2
      echo "                               empty schema if there is no backup" >&2
      echo "    unidork bootstrap --empty  force an empty schema, ignore backups" >&2
      echo "" >&2
      orphans="$(orphan_dbs 2>/dev/null || true)"
      if [ -n "$orphans" ]; then
        echo "  You have restored databases that were never swapped in:" >&2
        printf '%s\n' "$orphans" | sed 's/^/    /' >&2
        echo "" >&2
        echo "  If your data is in one of those, you wanted --swap:" >&2
        echo "    unidork restore latest --swap" >&2
        echo "" >&2
      fi
      return 1
    }

    ensure_schema_current() {
      echo "[schema] reconciling the database with the compiled code"
      run_import db-init
      run_import db-migrate
      run_import db-tv-init
    }

    auto_backup() {
      if [ "$UNIDORK_AUTO_BACKUP" = 1 ]; then
        if ! pg-backup --auto; then
          echo "[unidork] WARNING: auto-backup failed (backup root unmounted?)." >&2
          echo "[unidork] Proceeding. Run 'unidork backup --init' with the volume mounted." >&2
        fi
      fi
    }


    PENDING_GLOBAL=""
    GLOBAL_MODE=preview

    is_global_stage() {
      case "$1" in
        artscan) return 0 ;;
        *)       return 1 ;;
      esac
    }

    queue_global_stage() {
      g_id="$1"; g_dest="$2"; g_desc="$3"; g_verb="$4"
      GLOBAL_MODE="$OPT_MODE"
      if printf '%s\n' "$PENDING_GLOBAL" | grep -q "^$g_id|"; then
        return 0
      fi
      PENDING_GLOBAL="$(printf '%s\n%s' "$PENDING_GLOBAL" "$g_id|$g_dest|$g_desc|$g_verb")"
    }

    flush_global_stages() {
      if [ -z "$(printf '%s' "$PENDING_GLOBAL" | tr -d '\n')" ]; then
        return 0
      fi
      echo ""
      echo "[global] deferred stage(s), mode=$GLOBAL_MODE"
      while IFS='|' read -r q_id q_dest q_desc q_verb; do
        if [ -z "$q_id" ]; then
          continue
        fi
        q_flags=()
        if [ "$q_dest" = yes ] && [ "$GLOBAL_MODE" != apply ]; then
          q_flags+=(--dry-run)
        fi
        echo ""
        echo "[global] $q_id: $q_desc"
        q_start="$(date +%s)"
        if ! run_import "$q_verb" "''${q_flags[@]}"; then
          echo "" >&2
          echo "[global] FAILED at '$q_id' (unidork-import $q_verb)" >&2
          echo "[global] rerun it alone with:" >&2
          echo "    unidork stage $q_verb" >&2
          return 1
        fi
        echo "[global] $q_id ok ($(( $(date +%s) - q_start ))s)"
      done < <(printf '%s\n' "$PENDING_GLOBAL")
      PENDING_GLOBAL=""
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
        gmark=" "
        if is_global_stage "$id"; then
          gmark="*"
        fi
        printf '  %s%s %2d. %-9s %-44s (%s)\n' "$mark" "$gmark" "$n" "$id" "$desc" "$verb"
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
        echo "  * = domain-agnostic, deferred and run once after every domain"
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
      require_schema || return 1
      if [ "$OPT_MODE" = apply ]; then
        auto_backup
      fi
      ensure_schema_current

      echo "[$domain] $total stage(s), mode=$OPT_MODE"
      pipeline_start="$(date +%s)"
      n=0
      while IFS='|' read -r id destructive desc verb; do
        n=$((n + 1))
        if is_global_stage "$id"; then
          queue_global_stage "$id" "$destructive" "$desc" "$verb"
          echo ""
          echo "[$domain $n/$total] $id: deferred, runs once after every domain"
          continue
        fi
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
      if psql -At -c "SELECT 1 FROM information_schema.tables WHERE table_name = 'resolve_candidates'" 2>/dev/null | grep -q 1; then
        psql -At <<'SQL'
SELECT '  pending review:     ' || COUNT(DISTINCT file_id)::text FROM resolve_candidates;
SQL
      fi
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

    cmd_bootstrap() {
      force_empty=0
      case "''${1:-}" in
        --empty) force_empty=1 ;;
        "")      ;;
        *)       echo "usage: unidork bootstrap [--empty]" >&2; return 1 ;;
      esac

      ensure_pg

      if schema_present; then
        echo "[bootstrap] \"$PGDATABASE\" already has a uniDork schema, nothing to do"
        echo ""
        cmd_status
        return 0
      fi

      newest=""
      if [ "$force_empty" = 0 ]; then
        shopt -s nullglob
        dumps=("$UNIDORK_BACKUP_DIR"/*.dump)
        shopt -u nullglob
        if [ "''${#dumps[@]}" -gt 0 ]; then
          newest="$(printf '%s\n' "''${dumps[@]}" | sort -r | head -n 1)"
        fi
      fi

      if [ -n "$newest" ]; then
        echo "[bootstrap] restoring $newest and swapping it in"
        pg-restore "$newest" --swap
      else
        if [ "$force_empty" = 0 ]; then
          echo "[bootstrap] no backup found in $UNIDORK_BACKUP_DIR"
        fi
        echo "[bootstrap] creating an empty schema"
        cmd_schema
      fi

      if ! schema_present; then
        echo "[bootstrap] FAILED: still no schema after bootstrap" >&2
        return 1
      fi

      echo ""
      echo "[bootstrap] schema present in \"$PGDATABASE\""
      echo ""
      unidork-secrets || echo "[bootstrap] warn: keys are not fully resolvable, see above" >&2
      echo ""
      echo "[bootstrap] next: unidork all --dry-run"
    }

    cmd_gc() {
      ensure_pg

      echo "=== leftover databases (restore never reaps these) ==="
      if orphans="$(orphan_dbs 2>&1)"; then
        if [ -n "$orphans" ]; then
          printf '%s\n' "$orphans" | sed 's/^/  /'
        else
          echo "  (none)"
        fi
      else
        echo "  QUERY FAILED, so treat this section as unknown, not empty:" >&2
        printf '%s\n' "$orphans" | sed 's/^/    /' >&2
      fi

      echo ""
      echo "=== largest tables ==="
      psql -At -v ON_ERROR_STOP=1 <<'SQL'
SELECT '  ' || rpad(c.relname, 24) || lpad(pg_size_pretty(pg_total_relation_size(c.oid)), 10)
  FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
 WHERE n.nspname = 'public' AND c.relkind = 'r'
 ORDER BY pg_total_relation_size(c.oid) DESC
 LIMIT 12;
SQL

      echo ""
      echo "=== dead tuples and autovacuum ==="
      psql -At -v ON_ERROR_STOP=1 <<'SQL'
SELECT '  ' || rpad(relname, 24) || lpad(n_live_tup::text, 9) || lpad(n_dead_tup::text, 8)
         || '  ' || coalesce(last_autovacuum::text, 'never')
  FROM pg_stat_user_tables
 WHERE n_dead_tup > 0
 ORDER BY n_dead_tup DESC
 LIMIT 8;
SQL

      echo ""
      echo "=== rows that may be stranded ==="
      psql -At -v ON_ERROR_STOP=1 <<'SQL'
SELECT '  stage=buffer   ' || COUNT(*)::text || '   (nfo/subs skip these when the folder is gone)' FROM files WHERE stage = 'buffer';
SELECT '  stage=missing  ' || COUNT(*)::text || '   (retired by sweep, kept for history)' FROM files WHERE stage = 'missing';
SQL

      echo ""
      echo "Nothing was deleted. Reclaiming, in descending order of usefulness:"
      echo ""
      echo "  a leftover database:   psql -d postgres -c 'DROP DATABASE \"<name>\"'"
      echo "  probe_cache table:     unidork clean-stage   (probe re-derives it)"
      echo ""
      echo "Autovacuum fires at roughly 20% dead, so a table sitting below that"
      echo "with an old timestamp is fine, not neglected. Leave tmdb_search_cache"
      echo "alone. None of this reduces peak RSS, which is live working set."
    }

    cmd_pending() {
      ensure_pg
      if ! psql -At -c "SELECT 1 FROM information_schema.tables WHERE table_name = 'resolve_candidates'" 2>/dev/null | grep -q 1; then
        echo "[pending] no resolve_candidates table in \"$PGDATABASE\"." >&2
        echo "[pending] run: unidork schema" >&2
        return 1
      fi

      echo "=== no association, no candidates ==="
      echo "    (no year parsed from the name, or tmdb returned nothing)"
      psql -At <<'SQL'
SELECT '  ' || rpad(p.file_id::text, 7) ||
       CASE WHEN p.folder IS NULL OR p.folder = p.stem
            THEN p.name
            ELSE p.folder || '/' || p.name
       END
  FROM (
    SELECT f.file_id,
           f.original_name AS name,
           substring(f.original_path from '([^/]+)/[^/]+$') AS folder,
           COALESCE(substring(f.original_name from '^(.*)\.[^.]*$'),
                    f.original_name) AS stem
      FROM files f
      LEFT JOIN associations a ON a.file_id = f.file_id
      LEFT JOIN resolve_candidates c ON c.file_id = f.file_id
     WHERE a.file_id IS NULL
       AND c.file_id IS NULL
       AND f.stage <> 'buffer'
       AND f.media_kind = 'movie'
  ) p
 ORDER BY p.file_id;
SQL

      echo ""
      echo "=== ambiguous, candidates the resolver scored and rejected ==="
      psql -At <<'SQL'
SELECT '  ' || rpad(p.file_id::text, 7) ||
       CASE WHEN p.folder IS NULL OR p.folder = p.stem
            THEN p.name
            ELSE p.folder || '/' || p.name
       END || E'\n' ||
       string_agg(
         '      ' || lpad(p.score::text, 3) ||
         '  tmdb:' || rpad(p.tmdb_id::text, 8) ||
         '  ' || p.title || ' (' || substr(p.release_date, 1, 4) || ')',
         E'\n' ORDER BY p.score DESC, p.popularity DESC)
  FROM (
    SELECT f.file_id,
           f.original_name AS name,
           substring(f.original_path from '([^/]+)/[^/]+$') AS folder,
           COALESCE(substring(f.original_name from '^(.*)\.[^.]*$'),
                    f.original_name) AS stem,
           c.score, c.tmdb_id, c.title, c.release_date, c.popularity
      FROM resolve_candidates c
      JOIN files f USING (file_id)
  ) p
 GROUP BY p.file_id, p.name, p.folder, p.stem
 ORDER BY p.file_id;
SQL

      echo ""
      echo "Pick one with:  unidork assign <fileId> <tmdbId>"
    }

    cmd_assign() {
      if [ "$#" -lt 2 ]; then
        echo "usage: unidork assign <fileId> <tmdbId>" >&2
        echo "       unidork pending    lists file ids and candidate tmdb ids" >&2
        return 1
      fi
      case "$1" in
        ""|*[!0-9]*)
          echo "unidork assign: fileId must be a number, got '$1'" >&2
          return 1
          ;;
      esac
      case "$2" in
        ""|*[!0-9]*)
          echo "unidork assign: tmdbId must be a number, got '$2'" >&2
          return 1
          ;;
      esac
      ensure_pg
      require_schema || return 1

      a_stage="$(psql -At -c "SELECT stage FROM files WHERE file_id = $1" 2>/dev/null || true)"
      if [ -z "$a_stage" ]; then
        echo "unidork assign: no files row with file_id $1" >&2
        return 1
      fi

      run_import movie-assign "$@"

      echo ""
      case "$a_stage" in
        staging)
          echo "[assign] the renamer picks this up on the next rename stage:"
          echo "    unidork movies --from=rename --apply"
          ;;
        *)
          echo "[assign] WARNING: file_id $1 is at stage='$a_stage', not 'staging'."
          echo "[assign] rename only reads staging, so this association will not"
          echo "[assign] rename anything until the file is back in staging."
          ;;
      esac
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

REVIEW AND REPAIR

  pending                  files the resolver could not place, with the tmdb
                           candidates it scored and rejected
  assign <fileId> <tmdbId> force a manual association for one file

  Workflow for a backlog: run the resolve stage, then 'pending' to see what
  it declined and why, then 'assign' per file, then re-run rename:

    unidork movies --only=resolve --apply
    unidork pending
    unidork assign 4211 603
    unidork movies --from=rename --apply

  A manual association wins permanently. movie-resolve will not overwrite or
  delete a row whose match_source is 'manual', so re-running the pipeline
  cannot undo your decision.

DATABASE

  bootstrap                first run on a new machine. ensures the cluster,
                           restores the newest backup if there is one, else
                           creates an empty schema, then checks the API keys.
  bootstrap --empty        same, but ignore backups and start empty
  schema                   create/migrate movie and tv schemas
  gc                       report table sizes, dead tuples, stranded rows
  backup [--init|--list]   dump db, verified and checksummed
  backups                  list dumps
  restore <file|latest>    restore into a fresh database
  restore <f> --swap       ...then swap names
  start | stop             postgres lifecycle (start == ensure, safe)
  status                   row counts and backup inventory
  psql                     interactive session
  clean-stage              truncate probe_cache

  Pipelines refuse to start against a database with no schema, and tell you
  to run bootstrap. Once a schema exists, every --dry-run and --apply run
  reconciles it against the compiled code first (db-init, db-migrate,
  db-tv-init, all idempotent), so a binary carrying a new table cannot die
  mid-pipeline on a database that predates it. restore is non-destructive:
  without --swap it leaves your data in a side database and the live one
  untouched.

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
      movies|movie)
        run_pipeline movie "$@"
        flush_global_stages
        ;;
      tv)
        run_pipeline tv "$@"
        flush_global_stages
        ;;
      all)
        run_pipeline movie "$@"
        echo ""
        run_pipeline tv "$@"
        flush_global_stages
        ;;

      stage)         cmd_stage "$@" ;;
      pending)       cmd_pending ;;
      assign)        cmd_assign "$@" ;;

      bootstrap)     cmd_bootstrap "$@" ;;
      schema)        cmd_schema ;;
      gc)            cmd_gc ;;
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

