{ ... }:
{
  name = "uniDork";

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
  };

  tuning = {
    probeJobs = 8;
  };
}
