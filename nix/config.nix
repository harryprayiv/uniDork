{ ... }:
let
  name       = "uniDork";
  shareOwner = "harryprayiv";
in
{
  inherit name;

  # ------------------------------------------------------------------
  # TEMPLATE KNOB. This is the only thing a new project derived from
  # this template should need to touch for editor integration.
  # Available languages are defined in nix/ide.nix's registry; unknown
  # names fail evaluation loudly.
  # ------------------------------------------------------------------
  ide = {
    languages = [ "unison" "nix" ];

    # Escape hatches for one-off project needs, so ide.nix itself never
    # has to be edited per-project:
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
      # Must live on a different device than dataDir to survive disk death.
      # NAS is correct here since PGDATA is on local disk.
      dir = "/home/bismuth/NAS/video/HT_Profile/~Backup";

      # How many timestamped dumps to keep. Older ones are pruned after each
      # successful backup.
      keep = 10;

      # `pg-backup --auto` (used by the orchestrator before destructive verbs)
      # is a no-op if a backup newer than this many hours already exists.
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

  tmdb = {
    tokenFile = "$HOME/.config/uniDork/tmdb-token";
  };

  subs = {
    tokenFile = "$HOME/.config/uniDork/sub-token";
    languages = [ "en" "es" "th" ];
    # Minimum pacing between subdl API requests, in milliseconds. On a
    # rate-limit-shaped failure the fetch retries with 4x backoff, max 3
    # attempts (2s -> 8s -> 32s at the default).
    delayMs = 2000;
  };

  tuning = {
    probeJobs = 8;

    # cgroup ceiling for unidork-import: MemoryHigh throttles + reclaims
    # to swap/zram, MemoryMax is the hard kill line. Size these to the
    # box actually running the job, not to your workstation.
    memoryHigh = "6G";
    memoryMax  = "8G";

    # GHC RTS options for the ucm runtime. Silently ignored if the ucm
    # binary wasn't built with full -rtsopts; the cgroup above is the
    # enforcement layer either way.
    ghcRts = "-M5G -c";
  };
}