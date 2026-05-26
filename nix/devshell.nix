{ pkgs, lib ? pkgs.lib, config, uniDork, postgres, probe, orchestrator }:

pkgs.mkShell {
  name = "uniDork-devshell";

  buildInputs = with pkgs; [
    unison-ucm
    postgresql
    pgcli
    ffmpeg
    rhash
    jq

    postgres.pg-start
    postgres.pg-stop
    postgres.pg-connect
    postgres.pg-cleanup

    probe.ffprobe-cache
    probe.ffprobe-cache-clean
    probe.unidork-stage-probe
    probe.unidork-stage-probe-clean

    uniDork
    orchestrator
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
    export UNIDORK_RENAME_TARGET="${config.rename.targetDir}"
    export UNIDORK_MOVIE_FORMAT="${config.rename.movieFormat}"

    echo ""
    echo "  uniDork — run 'unidork help' for the orchestrator."
    echo "  Common: unidork run | unidork status | unidork rename --apply"
    echo ""
  '';
}