{ pkgs, lib ? pkgs.lib, cache, library, staging, database }:

let
  psqlArgs = "-h \"$PGHOST\" -p \"$PGPORT\" -U \"$PGUSER\" -d \"$PGDATABASE\" -v ON_ERROR_STOP=1";
in
{
  ffprobe-cache = pkgs.writeShellApplication {
    name = "ffprobe-cache";
    runtimeInputs = with pkgs; [ ffmpeg parallel coreutils findutils gnugrep ];
    text = ''
      config="''${UNIDORK_CONFIG:-${library.configFile}}"
      cache_root="''${UNIDORK_FFPROBE_CACHE:-${cache.ffprobeDir}}"
      jobs="''${UNIDORK_FFPROBE_JOBS:-8}"

      [ -f "$config" ] || { echo "config not found: $config" >&2; exit 1; }
      mkdir -p "$cache_root"

      echo "[library-probe] config=$config cache=$cache_root jobs=$jobs"
      mapfile -t roots < <(grep -Ev '^[[:space:]]*(#|$)' "$config")

      videos=()
      for root in "''${roots[@]}"; do
        while IFS= read -r -d "" v; do videos+=("$v"); done < <(find "$root" -type f \
          '(' -iname "*.mkv" -o -iname "*.mp4" -o -iname "*.avi" \
          -o -iname "*.mov" -o -iname "*.wmv" -o -iname "*.flv" ')' -print0)
      done

      to_probe=()
      for v in "''${videos[@]}"; do
        j="$cache_root$v.json"
        if [ ! -f "$j" ] || [ "$v" -nt "$j" ]; then to_probe+=("$v"); fi
      done

      pending=''${#to_probe[@]}
      echo "[library-probe] videos=''${#videos[@]} pending=$pending"
      [ "$pending" -eq 0 ] && { echo "[library-probe] all cached"; exit 0; }

      export UNIDORK_FFPROBE_CACHE_DIR="$cache_root"
      # shellcheck disable=SC2016
      printf '%s\0' "''${to_probe[@]}" | parallel -0 -j "$jobs" --bar '
        v={}
        out="''${UNIDORK_FFPROBE_CACHE_DIR}$v.json"
        mkdir -p "$(dirname "$out")"
        if ffprobe -v quiet -print_format json -show_format -show_streams "$v" > "$out" 2>/dev/null && [ -s "$out" ]; then
          true
        else
          rm -f "$out"; echo "FAIL: $v" >&2
        fi'
      echo "[library-probe] done"
    '';
  };

  ffprobe-cache-clean = pkgs.writeShellApplication {
    name = "ffprobe-cache-clean";
    runtimeInputs = with pkgs; [ coreutils ];
    text = ''
      cache_root="''${UNIDORK_FFPROBE_CACHE:-${cache.ffprobeDir}}"
      if [ -d "$cache_root" ]; then rm -rf "$cache_root"; echo "removed $cache_root"
      else echo "nothing to remove at $cache_root"; fi
    '';
  };

  unidork-stage-probe = pkgs.writeShellApplication {
    name = "unidork-stage-probe";
    runtimeInputs = with pkgs; [ ffmpeg rhash jq coreutils findutils postgresql ];
    text = ''
      stage_root="''${UNIDORK_STAGING:-${staging.movies}}"
      delete_empty="''${UNIDORK_DELETE_EMPTY:-1}"

      [ -d "$stage_root" ] || { echo "staging not found: $stage_root" >&2; exit 1; }

      if ! pg_isready -h "$PGHOST" -p "$PGPORT" -q 2>/dev/null; then
        echo "[stage-probe] postgres not running" >&2
        echo "[stage-probe] run: unidork start" >&2
        exit 1
      fi

      echo "[stage-probe] staging=$stage_root delete_empty=$delete_empty"

      shopt -s nullglob
      folders=("$stage_root"/*/)

      loose_videos=()
      while IFS= read -r -d "" v; do loose_videos+=("$v"); done < <(find "$stage_root" -maxdepth 1 -type f \
        '(' -iname "*.mkv" -o -iname "*.mp4" -o -iname "*.avi" \
          -o -iname "*.mov" -o -iname "*.wmv" -o -iname "*.flv" ')' -print0)

      echo "[stage-probe] folders=''${#folders[@]} loose=''${#loose_videos[@]}"

      processed=0; skipped_done=0; skipped_subdir=0; deleted=0; failed=0

      upsert_probe() {
        local video="$1" folder_path="$2" video_basename="$3" crc="$4" probe_json="$5"

        psql ${psqlArgs} \
          -v src="$video" \
          -v folder="$folder_path" \
          -v vbn="$video_basename" \
          -v crc="$crc" \
          -v probe="$probe_json" >/dev/null <<'SQL'
INSERT INTO stage_probes (source_path, folder_path, video_basename, crc32, probe_json)
VALUES (
  :'src',
  CASE WHEN length(:'folder') > 0 THEN :'folder' ELSE NULL END,
  :'vbn',
  :'crc',
  :'probe'
)
ON CONFLICT (source_path) DO UPDATE SET
  folder_path    = EXCLUDED.folder_path,
  video_basename = EXCLUDED.video_basename,
  crc32          = EXCLUDED.crc32,
  probe_json     = EXCLUDED.probe_json,
  probed_at      = NOW();
SQL
      }

      probe_one() {
        local video="$1" folder_path="$2"
        local video_basename
        video_basename="$(basename "$video")"

        local file_mtime probe_mtime cached_crc
        file_mtime="$(stat -c '%Y' "$video")"
        cached_crc="$(psql ${psqlArgs} -At -v src="$video" -c "SELECT crc32 FROM stage_probes WHERE source_path = :'src'" 2>/dev/null || true)"

        if [ -n "$cached_crc" ]; then
          probe_mtime="$(psql ${psqlArgs} -At -v src="$video" -c "SELECT EXTRACT(EPOCH FROM probed_at)::int FROM stage_probes WHERE source_path = :'src'" 2>/dev/null || echo 0)"
          if [ "$probe_mtime" -ge "$file_mtime" ]; then
            echo "cached:    $cached_crc  $video_basename"
            skipped_done=$((skipped_done + 1)); return 0
          fi
        fi

        echo "probing:   $video_basename"

        local crc
        crc="$(rhash --crc32 -p '%C' "$video" 2>/dev/null | tr '[:lower:]' '[:upper:]')"
        [ -n "$crc" ] || { echo "  crc failed" >&2; return 1; }
        echo "  crc32:   $crc"

        local raw
        raw="$(ffprobe -v quiet -print_format json -show_format -show_streams "$video" 2>/dev/null || true)"
        [ -n "$raw" ] || { echo "  ffprobe failed" >&2; return 1; }

        local probe_json
        probe_json="$(jq --arg vp "$video" --arg crc "$crc" --argjson probe "$raw" -n '
          ($probe.streams // [] | map(select(.codec_type == "video")) | .[0] // {}) as $v
          | ($probe.streams // [] | map(select(.codec_type == "audio")) | .[0] // null) as $a
          | ($probe.format // {}) as $f
          | ($v.pix_fmt // "") as $pf
          | (if ($v.bits_per_raw_sample // null) != null
               then ($v.bits_per_raw_sample | tonumber? // 8)
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
                width: ($v.width // 0),
                height: ($v.height // 0),
                bit_depth: $bd,
                pix_fmt: $pf,
                bit_rate: (if ($v.bit_rate // "") == "" then null
                           else ($v.bit_rate | tonumber? // null) end)
              },
              audio: (if $a == null then null
                      else {
                        codec: ($a.codec_name // ""),
                        channels: ($a.channels // 0),
                        channel_layout: ($a.channel_layout // "")
                      } end)
            }')"

        if ! upsert_probe "$video" "$folder_path" "$video_basename" "$crc" "$probe_json"; then
          echo "  db upsert failed" >&2; return 1
        fi
        return 0
      }

      for folder in "''${folders[@]}"; do
        name="$(basename "$folder")"
        video=""; max_size=0
        while IFS= read -r -d "" v; do
          sz=$(stat -c '%s' "$v")
          if [ "$sz" -gt "$max_size" ]; then max_size="$sz"; video="$v"; fi
        done < <(find "$folder" -maxdepth 1 -type f \
          '(' -iname "*.mkv" -o -iname "*.mp4" -o -iname "*.avi" \
            -o -iname "*.mov" -o -iname "*.wmv" -o -iname "*.flv" ')' -print0)

        if [ -z "$video" ]; then
          subdir_video="$(find "$folder" -type f \
            '(' -iname "*.mkv" -o -iname "*.mp4" -o -iname "*.avi" \
              -o -iname "*.mov" -o -iname "*.wmv" -o -iname "*.flv" ')' -print -quit 2>/dev/null)"

          if [ -z "$subdir_video" ]; then
            if [ "$delete_empty" = "1" ]; then
              echo "DELETING:  $name"; rm -rf "$folder"
              psql ${psqlArgs} -v folder="''${folder%/}" >/dev/null \
                -c "DELETE FROM stage_probes WHERE folder_path = :'folder'" 2>/dev/null || true
              deleted=$((deleted + 1))
            else
              echo "no video:  $name (would delete; DELETE_EMPTY=0)"
            fi
          else
            echo "subdir vid: $name (left alone)"; skipped_subdir=$((skipped_subdir + 1))
          fi
          continue
        fi

        if probe_one "$video" "''${folder%/}"; then processed=$((processed + 1))
        else failed=$((failed + 1)); fi
      done

      for video in "''${loose_videos[@]}"; do
        if probe_one "$video" ""; then processed=$((processed + 1))
        else failed=$((failed + 1)); fi
      done

      echo ""
      echo "[stage-probe] processed=$processed skipped=$skipped_done subdir=$skipped_subdir deleted=$deleted failed=$failed"
    '';
  };

  unidork-stage-probe-clean = pkgs.writeShellApplication {
    name = "unidork-stage-probe-clean";
    runtimeInputs = with pkgs; [ postgresql ];
    text = ''
      psql ${psqlArgs} -c "TRUNCATE stage_probes"
      echo "truncated stage_probes"
    '';
  };
}
