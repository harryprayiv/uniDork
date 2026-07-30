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

  # Every API key uniDork touches, in one table.
  #
  # The Unison side already takes *paths*, never values, so no secret ever
  # lands in the nix store, in a process listing, or in a derivation.
  #
  #   env     variable the Unison Config reader looks at
  #   key     leaf name inside the sops YAML, under the top-level `unidork:`
  #           mapping. Also the basename under runDir.
  #   legacy  basename of the pre-sops plaintext file under legacyDir
  #
  # Runtime resolution order is: already-exported env, then runDir, then
  # legacyDir. An activated NixOS host uses sops. A bare `nix develop` on a
  # machine that has never seen sops still works.
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
