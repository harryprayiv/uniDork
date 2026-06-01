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
    # fresh downloads land here. probe-stage READS. read-only.
    intake  = "/home/bismuth/NAS/video/_Unsorted/torrents/Complete/renameQue/Movies";

    # the buffer. rename WRITES renamed folders here; move READS + DELETES on promote.
    buffer  = "/home/bismuth/NAS/video/_Unsorted/torrents/Complete/AMC/TEST";

    # the library. move WRITES promoted movies here; import-library READS here.
    # TESTING: AMC/Movies (fake library). PRODUCTION (later): /home/bismuth/NAS/video/_Movies
    library = "/home/bismuth/NAS/video/_Unsorted/torrents/Complete/AMC/Movies";
  };

  rename = {
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