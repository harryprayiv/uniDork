{ pkgs, lib ? pkgs.lib, config, uniDork, postgres, orchestrator, snapshot, mirror }:

pkgs.mkShell {
  name = "uniDork-devshell";

  buildInputs = with pkgs; [
    unison-ucm
    postgresql
    pgcli
    ffmpeg
    rhash
    rsync
    jq
    fzf
    bat

    postgres.pg-ensure
    postgres.pg-start
    postgres.pg-stop
    postgres.pg-connect
    postgres.pg-cleanup
    postgres.pg-backup
    postgres.pg-restore

    uniDork
    orchestrator
    snapshot
    mirror.unidork-log-change
    mirror.unidork-snapshot
  ];

  shellHook = ''
    export PGDATA="${config.database.dataDir}"

    export UNIDORK_DB_HOST="${config.database.host}"
    export UNIDORK_DB_PORT="${toString config.database.port}"
    export UNIDORK_DB_USER="${config.database.user}"
    export UNIDORK_DB_NAME="${config.database.name}"

    export UNIDORK_BACKUP_DIR="${config.database.backup.dir}"
    export UNIDORK_BACKUP_KEEP="${toString config.database.backup.keep}"
    export UNIDORK_BACKUP_AUTO_HOURS="${toString config.database.backup.autoIntervalHours}"

    export UNIDORK_CACHE_FFPROBE="${config.cache.ffprobeDir}"
    export UNIDORK_CACHE_STAGE="${config.cache.stageDir}"

    export UNIDORK_PATH_CONFIG="${config.paths.configFile}"
    export UNIDORK_PATH_INTAKE="${config.paths.intake}"
    export UNIDORK_PATH_BUFFER="${config.paths.buffer}"
    export UNIDORK_PATH_LIBRARY="${config.paths.library}"

    export UNIDORK_PATH_TV_INTAKE="${config.paths.tvIntake}"
    export UNIDORK_PATH_TV_BUFFER="${config.paths.tvBuffer}"
    export UNIDORK_PATH_TV_LIBRARY="${config.paths.tvLibrary}"

    export UNIDORK_FORMAT_MOVIE="${config.rename.movieFormat}"
    export UNIDORK_FORMAT_TV="${config.rename.tvFormat}"

    export UNIDORK_TOKEN_TMDB="${config.tmdb.tokenFile}"
    export UNIDORK_TOKEN_SUB="${config.subs.tokenFile}"

    export UNIDORK_TUNE_PROBE_JOBS="${toString config.tuning.probeJobs}"
    export UNIDORK_TUNE_SUB_LANGS="${lib.concatStringsSep "," config.subs.languages}"
    export UNIDORK_TUNE_SUB_DELAY_MS="${toString config.subs.delayMs}"

    export PGPORT="$UNIDORK_DB_PORT"
    export PGUSER="$UNIDORK_DB_USER"
    export PGDATABASE="$UNIDORK_DB_NAME"
    export PGHOST="$PGDATA"

    echo ""
    echo "  uniDork dev shell"
    echo "  Movies:  unidork process | move | subs | identify | status"
    echo "  TV:      unidork tv-process | tv-identify"
    echo "  Both:    unidork run-all"
    echo "  Safety:  unidork backup | backups | restore <file|latest> [--swap]"
    echo "  Utility: push | start | stop | clean-stage"
    echo ""
    echo "  First time: unidork backup --init   (with the backup volume mounted)"
    echo ""
  '';
}