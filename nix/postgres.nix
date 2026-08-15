{ pkgs, lib ? pkgs.lib, database }:

let
  postgresql = pkgs.postgresql_18;
  pgMajor = lib.versions.major postgresql.version;
  bin = {
    pgctl     = "${postgresql}/bin/pg_ctl";
    psql      = "${postgresql}/bin/psql";
    initdb    = "${postgresql}/bin/initdb";
    pgIsReady = "${postgresql}/bin/pg_isready";
    pgDump    = "${postgresql}/bin/pg_dump";
    pgDumpAll = "${postgresql}/bin/pg_dumpall";
    pgRestore = "${postgresql}/bin/pg_restore";
    createdb  = "${postgresql}/bin/createdb";
  };

  envSetup = ''
    export PGDATA="''${PGDATA:-${database.dataDir}}"
    export PGPORT="''${PGPORT:-${toString database.port}}"
    export PGUSER="''${PGUSER:-${database.user}}"
    export PGDATABASE="''${PGDATABASE:-${database.name}}"
    export PGHOST="$PGDATA"

    export UNIDORK_BACKUP_DIR="''${UNIDORK_BACKUP_DIR:-${database.backup.dir}}"
    export UNIDORK_BACKUP_KEEP="''${UNIDORK_BACKUP_KEEP:-${toString database.backup.keep}}"
    export UNIDORK_BACKUP_AUTO_HOURS="''${UNIDORK_BACKUP_AUTO_HOURS:-${toString database.backup.autoIntervalHours}}"

    BACKUP_MARKER="$UNIDORK_BACKUP_DIR/.unidork-backup-root"
  '';

  validateEnv = ''
    if [ -z "$PGDATA" ]; then
      echo "Error: PGDATA must be set"; exit 1
    fi
  '';

  # The single source of truth for "make sure the server is up and the db
  # exists". Safe to call from anything, any number of times, concurrently.
  ensureBody = ''
    # Fast path: already up.
    if ${bin.pgIsReady} -h "$PGHOST" -p "$PGPORT" -q 2>/dev/null; then
      :
    else
      mkdir -p "$PGDATA"

      if [ ! -f "$PGDATA/PG_VERSION" ]; then
        echo "[pg-ensure] initializing new cluster at $PGDATA..."
        ${bin.initdb} -D "$PGDATA" \
          --auth=trust \
          --no-locale \
          --encoding=UTF8 \
          --username="$PGUSER"
      fi

      # Stale postmaster.pid from an unclean shutdown (crash, power loss)
      # will make pg_ctl refuse to start. Detect and clear it ONLY if the
      # recorded pid is genuinely dead.
      if [ -f "$PGDATA/postmaster.pid" ]; then
        oldpid="$(head -n 1 "$PGDATA/postmaster.pid" 2>/dev/null || echo "")"
        case "$oldpid" in
          (*[!0-9]*|"") : ;;  # garbage; let pg_ctl complain
          (*)
            if ! kill -0 "$oldpid" 2>/dev/null; then
              echo "[pg-ensure] clearing stale postmaster.pid (pid $oldpid is dead)"
              rm -f "$PGDATA/postmaster.pid"
            fi
            ;;
        esac
      fi

      cat > "$PGDATA/postgresql.conf" <<EOF
listen_addresses = 'localhost'
port = $PGPORT
unix_socket_directories = '$PGDATA'
log_destination = 'stderr'
logging_collector = on
log_directory = 'log'
log_filename = 'postgresql-%Y-%m-%d_%H%M%S.log'
EOF

      cat > "$PGDATA/pg_hba.conf" <<EOF
local   all   all                trust
host    all   all   127.0.0.1/32  trust
host    all   all   ::1/128       trust
EOF

      # If another invocation raced us and started it, pg_ctl start fails but
      # pg_isready below decides the truth, so don't die on the start call.
      echo "[pg-ensure] starting PostgreSQL on port $PGPORT..."
      ${bin.pgctl} -D "$PGDATA" -l "$PGDATA/postgresql.log" start || true

      RETRIES=0
      while ! ${bin.pgIsReady} -h "$PGHOST" -p "$PGPORT" -q; do
        RETRIES=$((RETRIES + 1))
        if [ "$RETRIES" -eq 30 ]; then
          echo "[pg-ensure] timed out waiting for postgres. Log tail:" >&2
          tail -n 50 "$PGDATA/postgresql.log" >&2 || true
          exit 1
        fi
        sleep 1
      done
    fi

    # Ensure the application database exists (idempotent).
    ${bin.psql} -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" postgres <<SQL
SELECT 'CREATE DATABASE "$PGDATABASE"'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '$PGDATABASE')\gexec
SQL
  '';

  requireBackupRoot = ''
    # Refuse to touch the backup dir unless the marker proves the real
    # volume is mounted. Without this, an unmounted NAS means mkdir -p
    # silently creates a local dir and "backups" go into a hole.
    if [ ! -f "$BACKUP_MARKER" ]; then
      echo "[pg-backup] REFUSING: $BACKUP_MARKER not found." >&2
      echo "  If this is first-time setup (with the backup volume mounted!), run:" >&2
      echo "    pg-backup --init" >&2
      echo "  If the NAS is unmounted, mount it. Do NOT just mkdir the path." >&2
      exit 1
    fi
  '';

in rec {
  pg-ensure = pkgs.writeShellScriptBin "pg-ensure" ''
    set -euo pipefail
    ${envSetup}
    ${validateEnv}
    ${ensureBody}
    echo "[pg-ensure] ready: postgresql://$PGUSER@localhost:$PGPORT/$PGDATABASE"
  '';

  # Kept for muscle memory; now just an alias for the idempotent ensure.
  pg-start = pkgs.writeShellScriptBin "pg-start" ''
    set -euo pipefail
    exec ${pg-ensure}/bin/pg-ensure
  '';

  pg-stop = pkgs.writeShellScriptBin "pg-stop" ''
    set -euo pipefail
    ${envSetup}
    ${validateEnv}
    if ${bin.pgIsReady} -h "$PGHOST" -p "$PGPORT" -q 2>/dev/null; then
      ${bin.pgctl} -D "$PGDATA" stop -m fast
    else
      echo "[pg-stop] not running"
    fi
  '';

  pg-connect = pkgs.writeShellScriptBin "pg-connect" ''
    set -euo pipefail
    ${envSetup}
    ${validateEnv}
    ${bin.psql} -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" "$PGDATABASE"
  '';

  pg-backup = pkgs.writeShellScriptBin "pg-backup" ''
    set -euo pipefail
    ${envSetup}
    ${validateEnv}

    mode="''${1:-run}"

    case "$mode" in
      --init)
        # Deliberate one-time step, done while the backup volume is
        # definitely mounted. The marker is what future runs trust.
        mkdir -p "$UNIDORK_BACKUP_DIR"
        date -u +%Y-%m-%dT%H:%M:%SZ > "$BACKUP_MARKER"
        echo "[pg-backup] initialized backup root at $UNIDORK_BACKUP_DIR"
        exit 0
        ;;
      --list)
        ${requireBackupRoot}
        ls -1t "$UNIDORK_BACKUP_DIR"/*.dump 2>/dev/null || echo "(no backups yet)"
        exit 0
        ;;
      --auto)
        ${requireBackupRoot}
        newest="$(ls -1t "$UNIDORK_BACKUP_DIR"/*.dump 2>/dev/null | head -n 1 || true)"
        if [ -n "$newest" ]; then
          now="$(date +%s)"
          mt="$(stat -c %Y "$newest")"
          age_h=$(( (now - mt) / 3600 ))
          if [ "$age_h" -lt "$UNIDORK_BACKUP_AUTO_HOURS" ]; then
            echo "[pg-backup] auto: newest backup is ''${age_h}h old (< ''${UNIDORK_BACKUP_AUTO_HOURS}h), skipping"
            exit 0
          fi
        fi
        ;;
      run)
        ${requireBackupRoot}
        ;;
      *)
        echo "usage: pg-backup [--init | --list | --auto]" >&2
        exit 1
        ;;
    esac

    # Server must be up to dump.
    ${ensureBody}

    ts="$(date +%Y%m%d-%H%M%S)"
    stem="$UNIDORK_BACKUP_DIR/$PGDATABASE-$ts"
    dump="$stem.dump"
    globals="$stem.globals.sql"

    echo "[pg-backup] dumping $PGDATABASE -> $dump"
    ${bin.pgDump} -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" \
      -Fc --no-owner -f "$dump.partial" "$PGDATABASE"

    # Verify the dump is structurally readable BEFORE promoting it.
    if ! ${bin.pgRestore} --list "$dump.partial" > /dev/null; then
      echo "[pg-backup] FAILED: dump did not verify, leaving $dump.partial for inspection" >&2
      exit 1
    fi
    mv "$dump.partial" "$dump"

    ${bin.pgDumpAll} -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" \
      --globals-only > "$globals"

    sha256sum "$dump" > "$dump.sha256"
    echo "[pg-backup] verified: $dump ($(du -h "$dump" | cut -f1))"

    # Retention: keep the newest N dumps (plus their sidecars).
    count=0
    ls -1t "$UNIDORK_BACKUP_DIR"/*.dump | while read -r f; do
      count=$((count + 1))
      if [ "$count" -gt "$UNIDORK_BACKUP_KEEP" ]; then
        s="''${f%.dump}"
        echo "[pg-backup] pruning $f"
        rm -f "$f" "$f.sha256" "$s.globals.sql"
      fi
    done

    echo "[pg-backup] done"
  '';

  pg-restore = pkgs.writeShellScriptBin "pg-restore" ''
    set -euo pipefail
    ${envSetup}
    ${validateEnv}

    if [ "$#" -lt 1 ]; then
      echo "usage: pg-restore <dump-file|latest> [--swap]" >&2
      echo "" >&2
      echo "  Restores into a FRESH database named ''${PGDATABASE}_restored_<ts>." >&2
      echo "  Your live database is never dropped." >&2
      echo "  --swap   after a verified restore, rename:" >&2
      echo "             $PGDATABASE               -> ''${PGDATABASE}_pre_restore_<ts>" >&2
      echo "             ''${PGDATABASE}_restored_<ts> -> $PGDATABASE" >&2
      echo "" >&2
      echo "available backups:" >&2
      ls -1t "$UNIDORK_BACKUP_DIR"/*.dump 2>/dev/null >&2 || echo "  (none)" >&2
      exit 1
    fi

    dump="$1"; shift || true
    do_swap=0
    if [ "''${1:-}" = "--swap" ]; then do_swap=1; fi

    if [ "$dump" = "latest" ]; then
      dump="$(ls -1t "$UNIDORK_BACKUP_DIR"/*.dump 2>/dev/null | head -n 1 || true)"
      if [ -z "$dump" ]; then
        echo "[pg-restore] no backups found in $UNIDORK_BACKUP_DIR" >&2
        exit 1
      fi
    fi

    if [ ! -f "$dump" ]; then
      echo "[pg-restore] no such file: $dump" >&2
      exit 1
    fi

    # Checksum verification when the sidecar exists.
    if [ -f "$dump.sha256" ]; then
      echo "[pg-restore] verifying checksum..."
      ( cd "$(dirname "$dump")" && sha256sum -c "$(basename "$dump").sha256" )
    else
      echo "[pg-restore] warn: no checksum sidecar for $dump"
    fi

    ${ensureBody}

    ts="$(date +%Y%m%d-%H%M%S)"
    target="''${PGDATABASE}_restored_$ts"

    echo "[pg-restore] restoring $dump -> database \"$target\""
    ${bin.createdb} -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" "$target"
    if ! ${bin.pgRestore} -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" \
        --no-owner --exit-on-error -d "$target" "$dump"; then
      echo "[pg-restore] FAILED. Partial database \"$target\" left for inspection." >&2
      exit 1
    fi

    echo "[pg-restore] restore verified into \"$target\""
    ${bin.psql} -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -At "$target" \
      -c "SELECT 'library_movies: ' || COUNT(*) FROM library_movies" 2>/dev/null || true
    ${bin.psql} -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -At "$target" \
      -c "SELECT 'files:          ' || COUNT(*) FROM files" 2>/dev/null || true

    if [ "$do_swap" = 1 ]; then
      keep="''${PGDATABASE}_pre_restore_$ts"
      echo "[pg-restore] swapping: $PGDATABASE -> $keep, $target -> $PGDATABASE"
      ${bin.psql} -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" postgres <<SQL
SELECT pg_terminate_backend(pid) FROM pg_stat_activity
  WHERE datname IN ('$PGDATABASE', '$target') AND pid <> pg_backend_pid();
ALTER DATABASE "$PGDATABASE" RENAME TO "$keep";
ALTER DATABASE "$target" RENAME TO "$PGDATABASE";
SQL
      echo "[pg-restore] swap complete. Old database preserved as \"$keep\"."
      echo "  When satisfied:  psql -c 'DROP DATABASE \"$keep\"' postgres"
    else
      echo "[pg-restore] no swap requested. Inspect with:"
      echo "  psql -h \"\$PGHOST\" -p \"\$PGPORT\" -U \"\$PGUSER\" \"$target\""
      echo "  then rerun with --swap, or drop it when done."
    fi
  '';

  pg-cleanup = pkgs.writeShellScriptBin "pg-cleanup" ''
    set -euo pipefail
    ${envSetup}
    ${validateEnv}

    echo "!!! pg-cleanup PERMANENTLY DELETES the entire cluster at:"
    echo "      $PGDATA"
    echo ""

    # Take a final backup first if we possibly can.
    if [ -f "$BACKUP_MARKER" ]; then
      echo "[pg-cleanup] taking a final backup before destruction..."
      ${pg-backup}/bin/pg-backup || {
        echo "[pg-cleanup] REFUSING: final backup failed." >&2
        exit 1
      }
    else
      echo "[pg-cleanup] WARNING: backup root not initialized; NO final backup will be taken."
    fi

    printf 'Type the data directory path to confirm deletion: '
    read -r answer
    if [ "$answer" != "$PGDATA" ]; then
      echo "[pg-cleanup] mismatch, aborting. Nothing was deleted."
      exit 1
    fi

    if [ -d "$PGDATA" ]; then
      ${bin.pgctl} -D "$PGDATA" stop -m fast 2>/dev/null || true
      rm -rf "$PGDATA"
      echo "Removed $PGDATA"
    fi
  '';
}