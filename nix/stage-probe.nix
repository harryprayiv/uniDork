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

      if [ ! -d "$stage_root" ]; then
        echo "staging not found: $stage_root" >&2
        exit 1
      fi

      mkdir -p "$cache_root"

      echo "staging: $stage_root"
      echo "cache:   $cache_root"

      shopt -s nullglob
      folders=("$stage_root"/*/)

      loose_videos=()
      while IFS= read -r -d "" v; do
        loose_videos+=("$v")
      done < <(find "$stage_root" -maxdepth 1 -type f \
        '(' -iname "*.mkv" -o -iname "*.mp4" -o -iname "*.avi" \
          -o -iname "*.mov" -o -iname "*.wmv" -o -iname "*.flv" ')' -print0)

      echo "folders: ''${#folders[@]}"
      echo "loose:   ''${#loose_videos[@]}"
      echo ""

      processed=0
      skipped_done=0
      skipped_novideo=0
      failed=0

      # Probe one video. Args: video path, sidecar output path.
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

      # Folders: find largest video inside, key sidecar by folder name.
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
          echo "no video:  $name"
          skipped_novideo=$((skipped_novideo + 1))
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

      # Loose top-level videos: key sidecar by basename-without-extension.
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
      echo "processed:        $processed"
      echo "skipped (cached): $skipped_done"
      echo "skipped (no vid): $skipped_novideo"
      echo "failed:           $failed"
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