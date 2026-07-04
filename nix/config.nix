{ ... }:
{
  name = "uniDork";

  # Where this codebase's git working copy and Unison project live.
  # config.nix is the machine-facts file; absolute paths belong here.
  repo = {
    dir = "/home/bismuth/git/uniDork";
    unison = {
      project = "uniDork";
      branch  = "main";
    };
  };

  database = {
    host    = "localhost";
    name    = "dork";
    user    = "postgres";
    port    = 5434;
    dataDir = "$HOME/.local/share/uniDork/postgres";
  };

  cache = {
    ffprobeDir = "$HOME/.cache/uniDork/ffprobe";
    stageDir   = "$HOME/.cache/uniDork/stage";
  };

  paths = {
    intake  = "/home/bismuth/NAS/video/_Unsorted/torrents/Complete/renameQue/Movies";
    buffer  = "/home/bismuth/NAS/video/_Unsorted/torrents/Complete/AMC/TEST";
    library = "/home/bismuth/NAS/video/_Unsorted/torrents/Complete/AMC/Movies";

    tvIntake  = "/home/bismuth/NAS/video/_Unsorted/torrents/Complete/renameQue/Episodic";
    tvBuffer  = "/home/bismuth/NAS/video/_Unsorted/torrents/Complete/AMC/TEST_TV";
    tvLibrary = "/home/bismuth/NAS/video/_Unsorted/torrents/Complete/AMC/Episodic";
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