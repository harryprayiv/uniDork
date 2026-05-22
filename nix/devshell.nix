{ pkgs, lib ? pkgs.lib }:

let
  config   = import ./config.nix { };
  postgres = import ./postgres.nix {
    inherit pkgs;
    database = config.database;
  };

in pkgs.mkShell {
  name = "uniDork-devshell";

  buildInputs = with pkgs; [
    unison-ucm
    postgresql
    pgcli

    postgres.pg-start
    postgres.pg-stop
    postgres.pg-connect
    postgres.pg-cleanup
  ];

  shellHook = ''
    export PGDATA="${config.database.dataDir}"
    export PGPORT="${toString config.database.port}"
    export PGUSER="${config.database.user}"
    export PGDATABASE="${config.database.name}"
    export PGHOST="$PGDATA"

    echo ""
    echo "  uniDork dev shell"
    echo "  ================="
    echo ""
    echo "  Database (port ${toString config.database.port}):"
    echo "    pg-start    Initialize + start PostgreSQL"
    echo "    pg-stop     Stop"
    echo "    pg-connect  psql into ${config.database.name}"
    echo "    pg-cleanup  Stop and delete data dir"
    echo ""
    echo "  Unison:"
    echo "    ucm         Codebase manager"
    echo ""
    echo "  Quick start:  pg-start && ucm"
    echo "  Watch the postgres: watch -n 1 'ps -o pid,rss,vsz,cmd -p $(pgrep -f ucm)'"
    echo ""
  '';
}