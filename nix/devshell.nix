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

  stage = import ./stage-probe.nix {
    inherit pkgs;
    inherit (config) staging;
    stageCache = config.cache.stageDir;
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
    rhash
    jq

    postgres.pg-start
    postgres.pg-stop
    postgres.pg-connect
    postgres.pg-cleanup

    video.ffprobe-cache
    video.ffprobe-cache-clean

    stage.unidork-stage-probe
    stage.unidork-stage-probe-clean

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
    export UNIDORK_STAGING="${config.staging.movies}"
    export UNIDORK_STAGE_CACHE="${config.cache.stageDir}"
    export UNIDORK_RENAME_TARGET="${config.rename.targetDir}"
    export UNIDORK_RENAME_LOG="${config.cache.renameLog}"

    mkdir -p "${config.cache.renameLog}"
    mkdir -p "${config.rename.targetDir}"

    echo ""
    echo "  uniDork dev shell"
    echo "  ================="
    echo ""
    echo "  Database (port ${toString config.database.port}):"
    echo "    pg-start                   Initialize + start PostgreSQL"
    echo "    pg-stop                    Stop"
    echo "    pg-connect                 psql into ${config.database.name}"
    echo "    pg-cleanup                 Stop and delete data dir"
    echo ""
    echo "  Library probing:"
    echo "    ffprobe-cache              Probe library videos (per uniDork.conf)"
    echo "    ffprobe-cache-clean        Delete the library ffprobe cache"
    echo ""
    echo "  Staging probing (CRC32 + ffprobe for rename):"
    echo "    unidork-stage-probe        Probe staging videos, write sidecars"
    echo "    unidork-stage-probe-clean  Delete staging probe cache"
    echo ""
    echo "  Pipeline:"
    echo "    ucm                        Unison codebase manager"
    echo "    unidork-import             Run the compiled import pipeline"
    echo "    unidork-cron               pg-start + ffprobe-cache + unidork-import"
    echo ""
    echo "  From ucm:"
    echo "    run uniDork.identify       TMDB identification report"
    echo "    run uniDork.rename         Move HIGH-confidence matches"
    echo ""
  '';
}