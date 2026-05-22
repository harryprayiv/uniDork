{ ... }:
{
  name = "uniDork";

  database = {
    name    = "dork";
    user    = "postgres";
    port    = 5434;
    dataDir = "$HOME/.local/share/uniDork/postgres";
  };
}