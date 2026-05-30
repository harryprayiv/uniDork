{ pkgs, lib ? pkgs.lib, config, uniDork, postgres, orchestrator }:

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

    uniDork
    orchestrator
  ];

  shellHook = ''
    export PGDATA="${config.database.dataDir}"

    export UNIDORK_DB_HOST="${config.database.host}"
    export UNIDORK_DB_PORT="${toString config.database.port}"
    export UNIDORK_DB_USER="${config.database.user}"
    export UNIDORK_DB_NAME="${config.database.name}"

    export UNIDORK_CACHE_FFPROBE="${config.cache.ffprobeDir}"
    export UNIDORK_CACHE_STAGE="${config.cache.stageDir}"

    export UNIDORK_PATH_CONFIG="${config.library.configFile}"
    export UNIDORK_PATH_STAGING="${config.staging.movies}"
    export UNIDORK_PATH_RENAME_TARGET="${config.rename.targetDir}"

    export UNIDORK_FORMAT_MOVIE="${config.rename.movieFormat}"

    export UNIDORK_TOKEN_TMDB="${config.tmdb.tokenFile}"
    export UNIDORK_TOKEN_SUB="${config.subs.tokenFile}"

    export UNIDORK_TUNE_PROBE_JOBS="${toString config.tuning.probeJobs}"
    export UNIDORK_TUNE_SUB_LANGS="${lib.concatStringsSep "," config.subs.languages}"

    export PGPORT="$UNIDORK_DB_PORT"
    export PGUSER="$UNIDORK_DB_USER"
    export PGDATABASE="$UNIDORK_DB_NAME"
    export PGHOST="$PGDATA"

    echo ""
    echo "  uniDork — run 'unidork help' for the orchestrator."
    echo "  Common: unidork run | unidork status | unidork rename --apply"
    echo ""
  '';
}