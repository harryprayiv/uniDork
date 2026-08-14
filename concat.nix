# Start of ./flake.nix
{
  description = "uniDork, movie metadata pipeline in Unison";

  inputs = {
    nixpkgs.url     = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    unison-nix = {
      url = "github:ceedubs/unison-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, flake-utils, unison-nix }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ unison-nix.overlay ];
        };

        baseConfig = import ./nix/config.nix { };

        libraryConfigFile =
          pkgs.writeText "uniDork.conf" (baseConfig.paths.library + "\n");

        config = baseConfig // {
          paths = baseConfig.paths // {
            configFile = libraryConfigFile;
          };
        };

        secrets      = import ./nix/secrets.nix   { inherit pkgs config; };
        uniDork      = import ./nix/build.nix     { inherit pkgs; };
        postgres     = import ./nix/postgres.nix  { inherit pkgs; inherit (config) database; };
        snapshot = import ./nix/snapshot.nix { inherit pkgs config; };
        mirror = import ./nix/mirror.nix { inherit pkgs config; };
        ide = import ./nix/ide.nix { inherit pkgs config; };
        orchestrator = import ./nix/orchestrator.nix {
          inherit pkgs config secrets uniDork postgres snapshot mirror;
        };

      in {
        packages = {
          default        = orchestrator;
          unidork        = orchestrator;
          unidork-import = uniDork;
          unidork-secrets = secrets.doctor;
        };

        devShells.default = import ./nix/devshell.nix {
          inherit pkgs config secrets uniDork postgres orchestrator snapshot mirror ide;
        };
      })
    // {
      nixosModules.unidork = import ./nix/nixos-module.nix { inherit self; };
      nixosModules.default = self.nixosModules.unidork;
    };

  nixConfig = {
    extra-experimental-features = ["nix-command flakes" "ca-derivations"];
    allow-import-from-derivation = "true";
    extra-substituters = [
      "https://cache.iog.io"
      "https://cache.nixos.org"
      "https://hercules-ci.cachix.org"
    ];
    extra-trusted-public-keys = [
      "hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ="
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "hercules-ci.cachix.org-1:ZZeDl9Va+xe9j+KqdzoBZMFJHVQ42Uu/c/1/KMC5Lw0="
    ];
  };
}

# End of ./flake.nix

# Start of ./nix/build.nix
{ pkgs, lib ? pkgs.lib }:

let
  ucm = pkgs.unison-ucm;
  prebuiltUc = ../bin/unidork-import.uc;
in
pkgs.stdenv.mkDerivation {
  pname = "uniDork";
  version = "0.1.0";

  nativeBuildInputs = [ pkgs.makeWrapper ];
  dontUnpack = true;
  dontBuild = true;
  dontConfigure = true;

  installPhase = ''
    mkdir -p $out/bin $out/share
    cp ${prebuiltUc} $out/share/unidork-import.uc
    makeWrapper "${ucm}/bin/ucm" "$out/bin/unidork-import" \
      --add-flags "run.compiled $out/share/unidork-import.uc --"
  '';
}
# End of ./nix/build.nix

# Start of ./nix/config.nix
{ ... }:
let
  name       = "uniDork";
  shareOwner = "harryprayiv";
in
{
  inherit name;

  ide = {
    languages = [ "unison" "nix" ];

    extraRecommendations = [ ];   # e.g. [ "tamasfe.even-better-toml" ]
    extraSettings = { };          # merged last, wins over registry settings
  };

  repo = {
    dir = "/home/bismuth/git/uniDork";
    unison = {
      project = name;
      branch  = "main";
      share   = "@${shareOwner}/${name}";
    };
  };

  database = {
    host    = "localhost";
    name    = "dork";
    user    = "postgres";
    port    = 5434;
    dataDir = "$HOME/.local/share/uniDork/postgres";

    backup = {
      dir = "/home/bismuth/NAS/video/HT_Profile/~Backup";

      keep = 10;

      autoIntervalHours = 2;
    };
  };

  cache = {
    ffprobeDir = "$HOME/.cache/uniDork/ffprobe";
    stageDir   = "$HOME/.cache/uniDork/stage";
  };

  paths = {
    intake  = "/home/bismuth/NAS/video/_Unsorted/torrents/Complete/renameQue/Movies";
    buffer  = "/home/bismuth/NAS/video/_Unsorted/torrents/Complete/AMC/Movies";
    library = "/home/bismuth/NAS/video/_Movies";

    tvIntake  = "/home/bismuth/NAS/video/_Unsorted/torrents/Complete/renameQue/Episodic";
    tvBuffer  = "/home/bismuth/NAS/video/_Unsorted/torrents/Complete/AMC/Episodic";
    tvLibrary = "/home/bismuth/NAS/video/_Episodic";
  };

  rename = {
    movieFormat = "{ny} [{gigabytes}.{vf}.{vc}.{bitdepth}b.{minutes}min] ~{crc32}/{ny} [{vc}_{bitdepth}b_{resolution}_{mbps}_{ac}-{channels}] ~{crc32}";

    tvFormat = "{ny}/Season {s00}/{n} - S{s00}E{e00} - {t} [{vc}_{bitdepth}b_{resolution}_{mbps}_{ac}-{channels}] ~{crc32}";
  };

  secrets = {
    runDir    = "/run/secrets/unidork";
    legacyDir = "$HOME/.config/uniDork";

    entries = {
      tmdb = {
        env    = "UNIDORK_TOKEN_TMDB";
        key    = "tmdb_token";
        legacy = "tmdb-token";
        note   = "TMDB v4 read access token, sent as Authorization: Bearer";
      };

      opensubtitles = {
        env    = "UNIDORK_TOKEN_SUB";
        key    = "opensubtitles_key";
        legacy = "sub-token";
        note   = "OpenSubtitles api_key query parameter";
      };

      fanart = {
        env    = "UNIDORK_TOKEN_FANART";
        key    = "fanart_key";
        legacy = "fanart-token";
        note   = "fanart.tv api_key query parameter, used by tv-artwork banners";
      };
    };
  };

  artwork = {
    movies = [ "poster" "fanart" "logo" ];
    tv = [ "banner" "poster" ];
    tmdbThrottleMs = 250;
    fanartThrottleMs = 500;
  };

  subs = {
    languages = [ "en" "es" "th" ];
    delayMs = 2000;
  };

  tuning = {
    probeJobs = 8;            # blade: 2
    partitionSession = 50;
    sweepChunk = 100;
    subsChunk = 100;
    probeConnChunks = 4;
    stageTimeout = "4h";      # coreutils timeout syntax; "0" disables
    memoryHigh = "4G";        # blade: "1200M"
    memoryMax  = "5G";        # blade: "1600M"
    ghcRts     = "-M4500m -c"; # blade: "-M1400m -c"
  };
}

# End of ./nix/config.nix

# Start of ./nix/devshell.nix
{ pkgs, lib ? pkgs.lib, config, secrets, uniDork, postgres, orchestrator, snapshot, mirror, ide }:

pkgs.mkShell {
  name = "uniDork-devshell";

  buildInputs = with pkgs; [
    unison-ucm
    postgresql
    pgcli
    ffmpeg
    curl
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

    ide.sync
    secrets.doctor
  ] ++ ide.tools;

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

${secrets.envSetup}

    export UNIDORK_TUNE_PROBE_JOBS="${toString config.tuning.probeJobs}"
    export UNIDORK_TUNE_SUB_LANGS="${lib.concatStringsSep "," config.subs.languages}"
    export UNIDORK_TUNE_SUB_DELAY_MS="${toString config.subs.delayMs}"

    export PGPORT="$UNIDORK_DB_PORT"
    export PGUSER="$UNIDORK_DB_USER"
    export PGDATABASE="$UNIDORK_DB_NAME"
    export PGHOST="$PGDATA"

    unidork-ide-sync

    echo ""
    echo "  uniDork dev shell"
    echo "  Movies:  unidork process | move | subs | identify | status"
    echo "  TV:      unidork tv-process | tv-identify"
    echo "  Both:    unidork run-all"
    echo "  Safety:  unidork backup | backups | restore <file|latest> [--swap]"
    echo "  Utility: push | start | stop | clean-stage | secrets"
    echo ""
  '';
}

# End of ./nix/devshell.nix

# Start of ./nix/ide.nix
{ pkgs, lib ? pkgs.lib, config }:


let
  langs = {
    unison = {
      recommendations = [ "unison-lang.unison" ];
      settings = {
        "files.associations" = { "*.u" = "unison"; };
      };
    };

    nix = {
      recommendations = [
        "jnoortheen.nix-ide"
        "atomicspirit.nix-embedded-highlighter"
      ];
      settings = {
        "nix.enableLanguageServer" = true;
        "nix.serverPath" = "nixd";              # from devshell PATH, not a store path
        "nix.serverSettings" = {
          nixd.formatting.command = [ "nixfmt" ];
        };
        "[nix]" = {
          "editor.defaultFormatter" = "jnoortheen.nix-ide";
          "editor.formatOnSave" = false;
        };
      };
    };

    haskell = {
      recommendations = [ "haskell.haskell" "justusadam.language-haskell" ];
      settings = {
        "[haskell]" = {
          "editor.defaultFormatter" = "haskell.haskell";
          "editor.formatOnSave" = false;
        };
      };
    };

    purescript = {
      recommendations = [
        "nwolverson.language-purescript"
        "nwolverson.ide-purescript"
      ];
      settings = {
        "[purescript]" = {
          "editor.defaultFormatter" = "nwolverson.ide-purescript";
          "editor.formatOnSave" = false;
        };
      };
    };
  };

  base = {
    recommendations = [ "mkhl.direnv" ];
    settings = {
      "direnv.restart.automatic" = true;
    };
  };

  profile = {
    recommendations =
      base.recommendations
      ++ langs.unison.recommendations
      ++ langs.nix.recommendations;
    settings =
      base.settings
      // langs.unison.settings
      // langs.nix.settings;
  };

  extensionsJson = pkgs.writeText "extensions.json" (builtins.toJSON {
    inherit (profile) recommendations;
  });

  settingsJson = pkgs.writeText "settings.json"
    (builtins.toJSON profile.settings);

in
{
  tools = [ pkgs.nixd pkgs.nixfmt ];

  sync = pkgs.writeShellApplication {
    name = "unidork-ide-sync";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      repo="''${UNIDORK_REPO:-${config.repo.dir}}"
      vs="$repo/.vscode"
      mkdir -p "$vs"

      sync_one() {
        src="$1"; dst="$2"
        if ! cmp -s "$src" "$dst" 2>/dev/null; then
          if [ -f "$dst" ]; then
            echo "[ide-sync] overwriting $dst (nix is the source of truth; edit nix/ide.nix instead)"
          else
            echo "[ide-sync] writing $dst"
          fi
          install -m 0644 "$src" "$dst"
        fi
      }

      sync_one ${extensionsJson} "$vs/extensions.json"
      sync_one ${settingsJson}   "$vs/settings.json"
    '';
  };
}
# End of ./nix/ide.nix

# Start of ./nix/mirror.nix
{ pkgs, config }:

let
  ucmPrompt = "${config.repo.unison.project}/${config.repo.unison.branch}";

  common = ''
    : "''${UNIDORK_REPO:=${config.repo.dir}}"

    git_commit_push() {
      msg="$1"; shift
      git -C "$UNIDORK_REPO" add -- "$@"
      if git -C "$UNIDORK_REPO" diff --cached --quiet -- "$@"; then
        echo "[mirror] nothing changed, no commit"
      else
        git -C "$UNIDORK_REPO" commit -m "$msg" -- "$@"
        if [ "''${UNIDORK_GIT_PUSH:-1}" = 1 ]; then
          git -C "$UNIDORK_REPO" push
        else
          echo "[mirror] committed locally (UNIDORK_GIT_PUSH=0, not pushed)"
        fi
      fi
    }
  '';
in
{
  unidork-log-change = pkgs.writeShellApplication {
    name = "unidork-log-change";
    runtimeInputs = [ pkgs.git pkgs.coreutils ];
    text = ''
      ${common}
      scratch="$UNIDORK_REPO/scratch.u"

      slug="''${1:-update}"
      slug="$(echo "$slug" | tr -cs 'a-zA-Z0-9' '-' | sed 's/^-*//;s/-*$//')"

      if [ ! -s "$scratch" ]; then
        echo "[log-change] $scratch is empty or missing; nothing to archive" >&2
        exit 1
      fi

      mkdir -p "$UNIDORK_REPO/changes"
      dest="$UNIDORK_REPO/changes/$(date +%Y%m%d-%H%M%S)-$slug.u"
      cp "$scratch" "$dest"
      echo "[log-change] archived scratch -> $dest"
      git_commit_push "change: $slug" changes
    '';
  };

  unidork-snapshot = pkgs.writeShellApplication {
    name = "unidork-snapshot";
    runtimeInputs = [ pkgs.unison-ucm pkgs.git pkgs.gawk pkgs.coreutils ];
    text = ''
      ${common}

      tmp="$(mktemp -d)"
      cleanup() { rm -rf "$tmp"; }
      trap cleanup EXIT

      cat > "$tmp/dump.md" <<'TRANSCRIPT'
```ucm
${ucmPrompt}> edit.namespace .
```
TRANSCRIPT

      echo "[snapshot] rendering namespace via ucm transcript (the slow step)..."
      ( cd "$tmp" && ucm transcript.in-place dump.md )

      staged="$tmp/harvest.u"
      if [ -f "$tmp/dump.output.md" ]; then
        awk '/^```.*unison/{f=1; next} /^```/{f=0} f' \
          "$tmp/dump.output.md" > "$staged"
      fi

      if [ ! -s "$staged" ]; then
        mkdir -p "$UNIDORK_REPO/snapshots"
        debug="$UNIDORK_REPO/snapshots/last-transcript-debug.md"
        cp "$tmp/dump.output.md" "$debug" 2>/dev/null || true
        echo "[snapshot] dump produced no unison blocks." >&2
        if [ -f "$debug" ]; then
          echo "[snapshot] transcript output preserved at $debug -- first lines:" >&2
          echo "----------------------------------------------------------" >&2
          head -n 40 "$debug" >&2
          echo "----------------------------------------------------------" >&2
        fi
        exit 1
      fi

      lines=$(wc -l < "$staged")
      echo "[snapshot] captured $lines lines"
      if [ "$lines" -lt 100 ]; then
        echo "[snapshot] WARNING: suspiciously small for a namespace dump; verify the diff" >&2
      fi
      if [ "$lines" -gt 50000 ]; then
        echo "[snapshot] WARNING: suspiciously large; dump may include vendored lib" >&2
      fi

      mkdir -p "$UNIDORK_REPO/snapshots"
      rm -f "$UNIDORK_REPO/snapshots/last-transcript-debug.md"
      mv "$staged" "$UNIDORK_REPO/snapshots/namespace.u"
      git_commit_push "snapshot: namespace $(date +%Y-%m-%d)" snapshots
    '';
  };
}
# End of ./nix/mirror.nix

# Start of ./nix/nixos-module.nix
{ self }:

{ config, lib, pkgs, ... }:

let
  cfg = config.services.unidork;
  udConfig = import ./config.nix { };
  entries = udConfig.secrets.entries;
in
{
  options.services.unidork = {
    enable = lib.mkEnableOption "uniDork API key provisioning via sops-nix";

    user = lib.mkOption {
      type = lib.types.str;
      default = "bismuth";
      description = ''
        Existing user that runs the uniDork CLI. Added to the unidork group so
        it can read the decrypted keys. Must already be declared elsewhere in
        the host config.
      '';
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "unidork";
      description = ''
        Group that owns the decrypted keys. A dedicated group rather than
        "users" so that the forthcoming web service can get its own account and
        be added here without widening access to every human on the box.
      '';
    };

    secretsFile = lib.mkOption {
      type = lib.types.path;
      default = self + "/secrets/unidork.yaml";
      defaultText = lib.literalExpression "\${uniDork flake}/secrets/unidork.yaml";
      description = ''
        SOPS-encrypted YAML holding uniDork's API keys, nested under a
        top-level `unidork:` mapping. Must be git-tracked in the uniDork repo,
        otherwise the flake will not see it.

        Override this if you would rather keep the blob alongside the rest of
        your host secrets, which avoids a flake lock bump every time you rotate
        a key.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    users.groups.${cfg.group} = { };

    users.users.${cfg.user}.extraGroups = [ cfg.group ];

    sops.secrets = lib.mapAttrs'
      (_: e: lib.nameValuePair "unidork/${e.key}" {
        sopsFile = cfg.secretsFile;
        owner = cfg.user;
        group = cfg.group;
        mode = "0440";
      })
      entries;
  };
}

# End of ./nix/nixos-module.nix

# Start of ./nix/orchestrator.nix
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
  to run bootstrap. restore is non-destructive: without --swap it leaves your
  data in a side database and the live one untouched.

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

# End of ./nix/orchestrator.nix

# Start of ./nix/postgres.nix
{ pkgs, lib ? pkgs.lib, database }:

let
  postgresql = pkgs.postgresql;
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

  ensureBody = ''
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

    ${bin.psql} -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" postgres <<SQL
SELECT 'CREATE DATABASE "$PGDATABASE"'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '$PGDATABASE')\gexec
SQL
  '';

  requireBackupRoot = ''
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

    ${ensureBody}

    ts="$(date +%Y%m%d-%H%M%S)"
    stem="$UNIDORK_BACKUP_DIR/$PGDATABASE-$ts"
    dump="$stem.dump"
    globals="$stem.globals.sql"

    echo "[pg-backup] dumping $PGDATABASE -> $dump"
    ${bin.pgDump} -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" \
      -Fc --no-owner -f "$dump.partial" "$PGDATABASE"

    if ! ${bin.pgRestore} --list "$dump.partial" > /dev/null; then
      echo "[pg-backup] FAILED: dump did not verify, leaving $dump.partial for inspection" >&2
      exit 1
    fi
    mv "$dump.partial" "$dump"

    ${bin.pgDumpAll} -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" \
      --globals-only > "$globals"

    sha256sum "$dump" > "$dump.sha256"
    echo "[pg-backup] verified: $dump ($(du -h "$dump" | cut -f1))"

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
# End of ./nix/postgres.nix

# Start of ./nix/secrets.nix
{ pkgs, lib ? pkgs.lib, config }:

let
  s = config.secrets;

  ordered = map (n: s.entries.${n}) (builtins.attrNames s.entries);

  block = e: ''
    if [ -z "''${${e.env}:-}" ]; then
      if [ -r "${s.runDir}/${e.key}" ]; then
        ${e.env}="${s.runDir}/${e.key}"
      else
        ${e.env}="${s.legacyDir}/${e.legacy}"
      fi
    fi
    export ${e.env}
  '';

  envSetup = lib.concatStrings (map block ordered);

  reportCall = e: ''
    report "${e.env}" "''${${e.env}}" "${e.note}"
  '';

in
{
  inherit envSetup;

  entries = ordered;

  doctor = pkgs.writeShellApplication {
    name = "unidork-secrets";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      ${envSetup}

      rc=0

      report() {
        var="$1"
        path="$2"
        note="$3"

        src=legacy
        case "$path" in
          ${s.runDir}/*) src=sops ;;
        esac

        if [ ! -e "$path" ]; then
          printf '  %-22s %-6s %-11s %s\n' "$var" "$src" MISSING "$path"
          rc=1
        elif [ ! -r "$path" ]; then
          printf '  %-22s %-6s %-11s %s\n' "$var" "$src" UNREADABLE "$path"
          rc=1
        else
          fp="$(tr -d '\r\n' < "$path" | sha256sum | cut -c1-8)"
          printf '  %-22s %-6s %-11s %s\n' "$var" "$src" "ok:$fp" "$path"
        fi
        printf '  %-22s %s\n' "" "$note"
      }

      echo "uniDork secrets"
      echo ""
      printf '  %-22s %-6s %-11s %s\n' VARIABLE SOURCE STATE PATH
      printf '  %-22s %-6s %-11s %s\n' "----------------------" "------" "-----------" "----"
      ${lib.concatStrings (map reportCall ordered)}
      echo ""
      if [ "$rc" -ne 0 ]; then
        echo "  At least one key is missing or unreadable." >&2
        echo "  sops path expects: sops.secrets.\"unidork/<key>\" owned by a group you are in." >&2
        echo "  legacy path expects: a plaintext file you created by hand." >&2
      fi
      exit "$rc"
    '';
  };
}
# End of ./nix/secrets.nix

# Start of ./nix/snapshot.nix
{ pkgs, config }:

let
  ucmPrompt   = "${config.repo.unison.project}/${config.repo.unison.branch}";
  shareTarget = "${config.repo.unison.share}/${config.repo.unison.branch}";
in
pkgs.writeShellApplication {
  name = "unidork-push";
  runtimeInputs = [ pkgs.unison-ucm pkgs.git pkgs.gnugrep pkgs.coreutils ];
  text = ''
    repo="''${UNIDORK_REPO:-${config.repo.dir}}"
    cd "$repo"
    anchor=".unidork-snapshot-hash"
    old="$(cat "$anchor" 2>/dev/null || echo "")"

    tmp="$(mktemp -d)"
    cleanup() { rm -rf "$tmp"; }
    trap cleanup EXIT

    cat > "$tmp/push.md" <<'TRANSCRIPT'
```ucm
${ucmPrompt}> push ${shareTarget}
${ucmPrompt}> reflog
```
TRANSCRIPT

    ( cd "$tmp" && ucm transcript.in-place push.md )

    new="$(grep -E '^[[:space:]]*1\.[[:space:]]' "$tmp/push.output.md" \
            | grep -oE '#[0-9a-z]+' | head -n1 || true)"
    if [ -z "$new" ]; then
      echo "could not parse causal hash; transcript output follows:" >&2
      echo "------------------------------------------------------------" >&2
      cat "$tmp/push.output.md" >&2
      echo "------------------------------------------------------------" >&2
      exit 1
    fi
    if [ "$new" = "$old" ]; then
      echo "no change since last snapshot ($new)"
      exit 0
    fi

    diffout=""
    if [ -n "$old" ]; then
      {
        echo '```ucm'
        echo "${ucmPrompt}> diff.namespace $old $new"
        echo '```'
      } > "$tmp/diff.md"
      ( cd "$tmp" && ucm transcript.in-place diff.md ) \
        || echo "  (diff failed; hash-only snapshot)"
      diffout="$tmp/diff.output.md"
    fi

    mkdir -p backup
    out="backup/''${new#\#}.md"
    {
      echo "<!-- unison-causal: $new -->"
      echo "<!-- unison-prev:   $old -->"
      echo "<!-- restore: pull ${shareTarget} ; reset $new -->"
      echo "<!-- generated: $(date -u +%Y-%m-%dT%H:%M:%SZ) -->"
      echo ""
      echo "# ${config.name} snapshot \`$new\`"
      echo ""
      echo "Restore by causal hash, not the text below (diff is a lossy summary)."
      echo ""
      echo '```'
      if [ -n "$diffout" ] && [ -f "$diffout" ]; then
        cat "$diffout"
      else
        echo "(first snapshot — no prior anchor to diff against)"
      fi
      echo '```'
    } > "$out"

    echo "$new" > "$anchor"
    git add -- backup "$anchor"
    if git diff --cached --quiet -- backup "$anchor"; then
      echo "nothing to commit"
    else
      git commit -m "snapshot $new" --quiet -- backup "$anchor"
      echo "snapshotted $new -> $out (committed)"
    fi
  '';
}
# End of ./nix/snapshot.nix
