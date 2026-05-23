{ pkgs, lib ? pkgs.lib, cache, library, ffprobe-cache, pg-start }:

let
  defaultCompiled = "$HOME/git/uniDork/bin/uni-import.uc";

  unidork-import = pkgs.writeShellApplication {
    name = "unidork-import";

    runtimeInputs = with pkgs; [ unison-ucm ];

    text = ''
      compiled="''${UNIDORK_COMPILED:-${defaultCompiled}}"

      if [ ! -f "$compiled" ]; then
        echo "compiled bytecode not found at: $compiled" >&2
        echo "" >&2
        echo "build it from ucm:" >&2
        echo "  uniDork/main> compile uniDork.batchedRun bin/uni-import" >&2
        echo "" >&2
        echo "or set UNIDORK_COMPILED to the .uc location" >&2
        exit 1
      fi

      exec ucm run.compiled "$compiled"
    '';
  };

  unidork-cron = pkgs.writeShellApplication {
    name = "unidork-cron";

    runtimeInputs = [ pg-start ffprobe-cache unidork-import ];

    text = ''
      echo "[$(date -Iseconds)] starting uniDork pipeline"

      # Idempotent: starts postgres if not already running.
      pg-start

      # Idempotent: probes only new/changed videos.
      ffprobe-cache

      # Runs the Unison import.
      unidork-import

      echo "[$(date -Iseconds)] done"
    '';
  };

in {
  inherit unidork-import unidork-cron;
}