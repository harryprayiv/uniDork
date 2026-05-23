{ pkgs, lib ? pkgs.lib, uniDork, ffprobe-cache, pg-start }:

{
  unidork-cron = pkgs.writeShellApplication {
    name = "unidork-cron";

    runtimeInputs = [ pg-start ffprobe-cache uniDork ];

    text = ''
      echo "[$(date -Iseconds)] starting uniDork pipeline"
      pg-start
      ffprobe-cache
      unidork-import
      echo "[$(date -Iseconds)] done"
    '';
  };
}