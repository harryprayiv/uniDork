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
}