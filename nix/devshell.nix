{ pkgs, lib ? pkgs.lib }:

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
    inherit pkgs;
    inherit (config) cache library;
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

    runner.unidork-import
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
    export UNIDORK_COMPILED="$PWD/bin/uni-import.uc"

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
    echo "    ffprobe-cache        Probe new videos, cache to"
    echo "                         $UNIDORK_FFPROBE_CACHE"
    echo "    ffprobe-cache-clean  Delete the ffprobe cache"
    echo ""
    echo "  Pipeline:"
    echo "    ucm                  Unison codebase manager"
    echo "    unidork-import       Run the compiled pipeline"
    echo "    unidork-cron         pg-start + ffprobe-cache + unidork-import"
    echo ""
    echo "  First-run workflow:"
    echo "    1. pg-start"
    echo "    2. ucm"
    echo "       uniDork/main> update"
    echo "       uniDork/main> compile uniDork.batchedRun bin/uni-import"
    echo "       uniDork/main> exit"
    echo "    3. unidork-cron"
    echo ""
  '';
}