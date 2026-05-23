{ pkgs, lib ? pkgs.lib, staging, stageCache }:

{
  unidork-stage-probe = pkgs.writeShellApplication {
    name = "unidork-stage-probe";

    runtimeInputs = with pkgs; [
      ffmpeg
      rhash
      jq
      coreutils
      findutils
    ];

    text = ''
      stage_root="''${UNIDORK_STAGING:-${staging.movies}}"
      cache_root="''${UNIDORK_STAGE_CACHE:-${stageCache}}"
      delete_empty="''${UNIDORK_DELETE_EMPTY:-1}"

      if [ ! -d "$stage_root" ]; then
        echo "staging not found: $stage_root" >&2
        exit 1
      fi

      mkdir -p "$cache_root"

      echo "staging:       $stage_root"
      echo "cache:         $cache_root"
      echo "delete empty:  $delete_empty (set UNIDORK_DELETE_EMPTY=0 to disable)"

      shopt -s nullglob
      folders=("$stage_root"/*/)

      loose_videos=()
      while IFS= read -r -d "" v; do
        loose_videos+=("$v")
      done < <(find "$stage_root" -maxdepth 1 -type f \
        '(' -iname "*.mkv" -o -iname "*.mp4" -o -iname "*.avi" \
          -o -iname "*.mov" -o -iname "*.wmv" -o -iname "*.flv" ')' -print0)

      echo "folders:       ''${#folders[@]}"
      echo "loose:         ''${#loose_videos[@]}"
      echo ""

      processed=0
      skipped_done=0
      skipped_subdir=0
      deleted=0
      failed=0

      probe_one() {
        local video="$1"
        local out="$2"

        local crc
        crc="$(rhash --crc32 -p '%C' "$video" 2>/dev/null | tr '[:lower:]' '[:upper:]')"
        if [ -z "$crc" ]; then
          echo "  crc failed" >&2
          return 1
        fi
        echo "  crc32:   $crc"

        local probe_json
        probe_json="$(ffprobe -v quiet -print_format json -show_format -show_streams "$video" 2>/dev/null || true)"
        if [ -z "$probe_json" ]; then
          echo "  ffprobe failed" >&2
          return 1
        fi

        if ! jq -n \
          --arg vp "$video" \
          --arg crc "$crc" \
          --argjson probe "$probe_json" \
          '
            ($probe.streams // [] | map(select(.codec_type == "video")) | .[0] // {}) as $v
            | ($probe.streams // [] | map(select(.codec_type == "audio")) | .[0] // null) as $a
            | ($probe.format // {}) as $f
            | ($v.pix_fmt // "") as $pf
            | (if ($v.bits_per_raw_sample // null) != null then ($v.bits_per_raw_sample | tonumber? // 8)
               elif ($pf | test("p10|10le|10be")) then 10
               elif ($pf | test("p12|12le|12be")) then 12
               else 8 end) as $bd
            | {
                video_path: $vp,
                crc32: $crc,
                size_bytes: (($f.size // "0") | tonumber? // 0),
                duration_sec: (($f.duration // "0") | tonumber? // 0),
                video: {
                  codec: ($v.codec_name // ""),
                  width: (($v.width // 0) | tonumber? // 0),
                  height: (($v.height // 0) | tonumber? // 0),
                  bit_depth: $bd,
                  pix_fmt: $pf,
                  bit_rate: (if ($v.bit_rate // "") == "" then null
                             else ($v.bit_rate | tonumber? // null) end)
                },
                audio: (if $a == null then null
                        else {
                          codec: ($a.codec_name // ""),
                          channels: (($a.channels // 0) | tonumber? // 0),
                          channel_layout: ($a.channel_layout // "")
                        } end)
              }
          ' > "$out"; then
          echo "  jq failed" >&2
          rm -f "$out"
          return 1
        fi

        return 0
      }

      for folder in "''${folders[@]}"; do
        name="$(basename "$folder")"
        out="$cache_root/$name.json"

        video=""
        max_size=0
        while IFS= read -r -d "" v; do
          sz=$(stat -c '%s' "$v")
          if [ "$sz" -gt "$max_size" ]; then
            max_size="$sz"
            video="$v"
          fi
        done < <(find "$folder" -maxdepth 1 -type f \
          '(' -iname "*.mkv" -o -iname "*.mp4" -o -iname "*.avi" \
            -o -iname "*.mov" -o -iname "*.wmv" -o -iname "*.flv" ')' -print0)

        if [ -z "$video" ]; then
          # check recursively: any video anywhere in the tree?
          subdir_video="$(find "$folder" -type f \
            '(' -iname "*.mkv" -o -iname "*.mp4" -o -iname "*.avi" \
              -o -iname "*.mov" -o -iname "*.wmv" -o -iname "*.flv" ')' \
            -print -quit 2>/dev/null)"

          if [ -z "$subdir_video" ]; then
            if [ "$delete_empty" = "1" ]; then
              echo "DELETING:  $name"
              rm -rf "$folder"
              # also drop a stale sidecar
              rm -f "$out"
              deleted=$((deleted + 1))
            else
              echo "no video:  $name (would delete; DELETE_EMPTY=0)"
            fi
          else
            echo "subdir vid: $name (video only in subdir; left alone)"
            skipped_subdir=$((skipped_subdir + 1))
          fi
          continue
        fi

        if [ -f "$out" ] && [ "$out" -nt "$video" ]; then
          cached_crc="$(jq -r '.crc32 // "????????"' "$out" 2>/dev/null || echo "????????")"
          echo "cached:    $cached_crc  $name"
          skipped_done=$((skipped_done + 1))
          continue
        fi

        echo "probing:   $name"
        if probe_one "$video" "$out"; then
          processed=$((processed + 1))
        else
          failed=$((failed + 1))
        fi
      done

      for video in "''${loose_videos[@]}"; do
        bn="$(basename "$video")"
        name="''${bn%.*}"
        out="$cache_root/$name.json"

        if [ -f "$out" ] && [ "$out" -nt "$video" ]; then
          cached_crc="$(jq -r '.crc32 // "????????"' "$out" 2>/dev/null || echo "????????")"
          echo "cached:    $cached_crc  $name (loose)"
          skipped_done=$((skipped_done + 1))
          continue
        fi

        echo "probing:   $name (loose)"
        if probe_one "$video" "$out"; then
          processed=$((processed + 1))
        else
          failed=$((failed + 1))
        fi
      done

      echo ""
      echo "processed:           $processed"
      echo "skipped (cached):    $skipped_done"
      echo "skipped (subdir vid): $skipped_subdir"
      echo "deleted (empty):     $deleted"
      echo "failed:              $failed"
    '';
  };

  unidork-stage-probe-clean = pkgs.writeShellApplication {
    name = "unidork-stage-probe-clean";
    runtimeInputs = with pkgs; [ coreutils ];
    text = ''
      cache_root="''${UNIDORK_STAGE_CACHE:-${stageCache}}"
      if [ -d "$cache_root" ]; then
        rm -rf "$cache_root"
        echo "removed $cache_root"
      else
        echo "nothing to remove at $cache_root"
      fi
    '';
  };
}