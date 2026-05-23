{ pkgs, lib ? pkgs.lib, uniDork }:

let
  config = import ./config.nix { };

  postgres = import ./postgres.nix {
    inherit pkgs;
    database = config.database;
  };

  video = import ./ffmpeg.nix {
    inherit pkgs;
    inherit (config) cache library;
  };

  runner = import ./unison.nix {
    inherit pkgs uniDork;
    inherit (video) ffprobe-cache;
    inherit (postgres) pg-start;
  };

in pkgs.mkShell {
  name = "uniDork-devshell";

  buildInputs = with pkgs; [
    unison-ucm
    postgresql
    pgcli
    ffmpeg
    parallel

    postgres.pg-start
    postgres.pg-stop
    postgres.pg-connect
    postgres.pg-cleanup

    video.ffprobe-cache
    video.ffprobe-cache-clean

    uniDork
    runner.unidork-cron
  ];

  shellHook = ''
    export PGDATA="${config.database.dataDir}"
    export PGPORT="${toString config.database.port}"
    export PGUSER="${config.database.user}"
    export PGDATABASE="${config.database.name}"
    export PGHOST="$PGDATA"

    export UNIDORK_FFPROBE_CACHE="${config.cache.ffprobeDir}"
    export UNIDORK_CONFIG="${config.library.configFile}"

    echo ""
    echo "  uniDork dev shell"
    echo "  ================="
    echo ""
    echo "  Database (port ${toString config.database.port}):"
    echo "    pg-start             Initialize + start PostgreSQL"
    echo "    pg-stop              Stop"
    echo "    pg-connect           psql into ${config.database.name}"
    echo "    pg-cleanup           Stop and delete data dir"
    echo ""
    echo "  Video probing:"
    echo "    ffprobe-cache        Probe new videos, cache JSON"
    echo "    ffprobe-cache-clean  Delete the ffprobe cache"
    echo ""
    echo "  Pipeline:"
    echo "    ucm                  Unison codebase manager"
    echo "    unidork-import       Run the compiled import pipeline"
    echo "    unidork-cron         pg-start + ffprobe-cache + unidork-import"
    echo ""
    echo "  TMDB identification: run uniDork.identify from ucm."
    echo "  (HTTP done in Unison; no separate command needed.)"
    echo ""
  '';
}