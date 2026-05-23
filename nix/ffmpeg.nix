{ pkgs, lib ? pkgs.lib, cache, library }:

{
  ffprobe-cache = pkgs.writeShellApplication {
    name = "ffprobe-cache";

    runtimeInputs = with pkgs; [
      ffmpeg
      parallel
      coreutils
      findutils
      gnugrep
    ];

    text = ''
      config="''${UNIDORK_CONFIG:-${library.configFile}}"
      cache_root="''${UNIDORK_FFPROBE_CACHE:-${cache.ffprobeDir}}"
      jobs="''${UNIDORK_FFPROBE_JOBS:-8}"

      if [ ! -f "$config" ]; then
        echo "config not found: $config" >&2
        echo "set UNIDORK_CONFIG or create ${library.configFile}" >&2
        exit 1
      fi

      mkdir -p "$cache_root"

      echo "config:  $config"
      echo "cache:   $cache_root"
      echo "jobs:    $jobs"

      mapfile -t roots < <(grep -Ev '^[[:space:]]*(#|$)' "$config")
      echo "roots:   ''${#roots[@]}"

      videos=()
      for root in "''${roots[@]}"; do
        while IFS= read -r -d "" v; do
          videos+=("$v")
        done < <(find "$root" -type f \
          '(' -iname "*.mkv" -o -iname "*.mp4" -o -iname "*.avi" \
          -o -iname "*.mov" -o -iname "*.wmv" -o -iname "*.flv" ')' -print0)
      done
      echo "videos:  ''${#videos[@]}"

      # Skip videos whose cache JSON exists and is newer than the source.
      to_probe=()
      for v in "''${videos[@]}"; do
        j="$cache_root$v.json"
        if [ ! -f "$j" ] || [ "$v" -nt "$j" ]; then
          to_probe+=("$v")
        fi
      done

      pending=''${#to_probe[@]}
      cached=$((''${#videos[@]} - pending))
      echo "cached:  $cached"
      echo "pending: $pending"

      if [ "$pending" -eq 0 ]; then
        echo "all videos already cached"
        exit 0
      fi

      # Cache mirrors source-path layout under $cache_root.
      export UNIDORK_FFPROBE_CACHE_DIR="$cache_root"

      # shellcheck disable=SC2016
      printf '%s\0' "''${to_probe[@]}" | parallel -0 -j "$jobs" --bar '
        v={}
        out="''${UNIDORK_FFPROBE_CACHE_DIR}$v.json"
        mkdir -p "$(dirname "$out")"
        if ffprobe -v quiet -print_format json -show_format -show_streams "$v" > "$out" 2>/dev/null && [ -s "$out" ]; then
          true
        else
          rm -f "$out"
          echo "FAIL: $v" >&2
        fi
      '

      echo "done"
    '';
  };

  ffprobe-cache-clean = pkgs.writeShellApplication {
    name = "ffprobe-cache-clean";

    runtimeInputs = with pkgs; [ coreutils ];

    text = ''
      cache_root="''${UNIDORK_FFPROBE_CACHE:-${cache.ffprobeDir}}"
      if [ -d "$cache_root" ]; then
        rm -rf "$cache_root"
        echo "removed $cache_root"
      else
        echo "nothing to remove at $cache_root"
      fi
    '';
  };
}