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

  library = {
    roots = [
      "/home/bismuth/NAS/video/_Unsorted/torrents/Complete/AMC/Movies"
    ];
  };

  staging = {
    movies = "/home/bismuth/NAS/video/_Unsorted/torrents/Complete/renameQue/Movies";
  };

  rename = {
    targetDir = "/home/bismuth/NAS/video/_Unsorted/torrents/Complete/AMC/testMovies";
    movieFormat = "{ny} [{gigabytes}.{vf}.{vc}.{bitdepth}b.{minutes}min] ~{crc32}/{ny} [{vc}_{bitdepth}b_{resolution}_{mbps}_{ac}-{channels}] ~{crc32}";
    tvFormat = "{ny}/{'Season '+s}/{n} {s00e00} {t} ~{crc32}";
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