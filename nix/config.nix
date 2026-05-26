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
  };

  library = {
    configFile = ../uniDork.conf;
  };

  staging = {
    movies = "/home/bismuth/NAS/video/_Unsorted/torrents/Complete/renameQue/Movies";
  };

  rename = {
    targetDir = "/home/bismuth/NAS/video/_Unsorted/torrents/Complete/AMC/testMovies";
    movieFormat = "{ny} [{gigabytes}.{vf}.{vc}.{bitdepth}b.{minutes}min] ~{crc32}/{ny} {tags} [{vc}_{bitdepth}b_{resolution}_{mbps}_{ac}-{channels}_{group}] ~{crc32}";
    tvFormat = "{ny}/{'Season '+s}/{n} {s00e00} {t} ~{crc32}";
  };

  tmdb = {
    tokenFile = "$HOME/.config/uniDork/tmdb-token";
  };
}