{ pkgs, lib ? pkgs.lib, database }:

let
  postgresql = pkgs.postgresql;
  bin = {
    pgctl     = "${postgresql}/bin/pg_ctl";
    psql      = "${postgresql}/bin/psql";
    initdb    = "${postgresql}/bin/initdb";
    pgIsReady = "${postgresql}/bin/pg_isready";
  };

  envSetup = ''
    export PGDATA="''${PGDATA:-${database.dataDir}}"
    export PGPORT="''${PGPORT:-${toString database.port}}"
    export PGUSER="''${PGUSER:-${database.user}}"
    export PGDATABASE="''${PGDATABASE:-${database.name}}"
    export PGHOST="$PGDATA"
  '';

  validateEnv = ''
    if [ -z "$PGDATA" ]; then
      echo "Error: PGDATA must be set"; exit 1
    fi
  '';

in {
  pg-start = pkgs.writeShellScriptBin "pg-start" ''
    set -euo pipefail
    ${envSetup}
    ${validateEnv}

    mkdir -p "$PGDATA"

    if [ ! -f "$PGDATA/PG_VERSION" ]; then
      echo "Initializing cluster at $PGDATA..."
      ${bin.initdb} -D "$PGDATA" \
        --auth=trust \
        --no-locale \
        --encoding=UTF8 \
        --username="$PGUSER"
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

    echo "Starting PostgreSQL on port $PGPORT..."
    ${bin.pgctl} -D "$PGDATA" -l "$PGDATA/postgresql.log" start

    RETRIES=0
    while ! ${bin.pgIsReady} -h "$PGHOST" -p "$PGPORT" -q; do
      RETRIES=$((RETRIES + 1))
      if [ $RETRIES -eq 15 ]; then
        echo "Timed out. Log:"; cat "$PGDATA/postgresql.log"; exit 1
      fi
      sleep 1
    done

    ${bin.psql} -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" postgres <<SQL
SELECT 'CREATE DATABASE "$PGDATABASE"'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '$PGDATABASE')\gexec
SQL

    echo "Ready: postgresql://$PGUSER@localhost:$PGPORT/$PGDATABASE"
  '';

  pg-stop = pkgs.writeShellScriptBin "pg-stop" ''
    set -euo pipefail
    ${envSetup}
    ${validateEnv}
    ${bin.pgctl} -D "$PGDATA" stop -m fast
  '';

  pg-connect = pkgs.writeShellScriptBin "pg-connect" ''
    set -euo pipefail
    ${envSetup}
    ${validateEnv}
    ${bin.psql} -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" "$PGDATABASE"
  '';

  pg-cleanup = pkgs.writeShellScriptBin "pg-cleanup" ''
    set -euo pipefail
    ${envSetup}
    ${validateEnv}

    if [ -d "$PGDATA" ]; then
      ${bin.pgctl} -D "$PGDATA" stop -m fast 2>/dev/null || true
      rm -rf "$PGDATA"
      echo "Removed $PGDATA"
    fi
  '';
}