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
  };

  library = {
    configFile = ../uniDork.conf;
  };

  staging = {
    movies = "/home/bismuth/NAS/video/_Unsorted/torrents/Complete/renameQue/Movies";
  };

  tmdb = {
    tokenFile = "$HOME/.config/uniDork/tmdb-token";
  };
}