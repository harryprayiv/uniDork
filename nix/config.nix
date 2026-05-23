{ ... }:
{
  name = "uniDork";

  database = {
    name    = "dork";
    user    = "postgres";
    port    = 5434;
    dataDir = "$HOME/.local/share/uniDork/postgres";
  };

  cache = {
    ffprobeDir = "$HOME/.cache/uniDork/ffprobe";
    tmdbDir    = "$HOME/.cache/uniDork/tmdb/search";
    stageDir   = "$HOME/.cache/uniDork/stage";
    renameLog  = "$HOME/.cache/uniDork/rename-log";
  };

  library = {
    configFile = ../uniDork.conf;
  };

  staging = {
    movies = "/home/bismuth/NAS/video/_Unsorted/torrents/Complete/renameQue/Movies";
  };

  rename = {
    targetDir = "/home/bismuth/NAS/video/_Unsorted/torrents/Complete/AMC/testMovies";
  };

  tmdb = {
    tokenFile = "$HOME/.config/uniDork/tmdb-token";
  };
}