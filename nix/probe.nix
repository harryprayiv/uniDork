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

      schema_check="$(psql ${psqlArgs} -At -c "SELECT to_regclass('public.stage_probes')")"
      if [ "$schema_check" != "stage_probes" ]; then
        echo "[stage-probe] stage_probes table missing." >&2
        echo "[stage-probe] bootstrap with: unidork import   (creates the schema)" >&2
        exit 1
      fi

      echo "[stage-probe] staging=$stage_root delete_empty=$delete_empty"

      declare -A cache_map=()
      while IFS=$'\t' read -r cpath cprobed_at; do
        [ -n "$cpath" ] || continue
        cache_map["$cpath"]="$cprobed_at"
      done < <(psql ${psqlArgs} -At -F $'\t' \
                 -c "SELECT source_path, EXTRACT(EPOCH FROM probed_at)::bigint FROM stage_probes")

      cached_rows=''${#cache_map[@]}
      echo "[stage-probe] cache snapshot rows=$cached_rows"

      is_cached() {
        local p="$1" file_mtime="$2" probed_at
        if [[ ! -v cache_map[$p] ]]; then
          return 1
        fi
        probed_at="''${cache_map[$p]}"
        [ -n "$probed_at" ] || return 1
        [ "$probed_at" -ge "$file_mtime" ]
      }

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

      delete_folder_rows() {
        local folder_path="$1"
        psql ${psqlArgs} -v folder="$folder_path" >/dev/null <<'SQL'
DELETE FROM stage_probes WHERE folder_path = :'folder';
SQL
      }

      probe_one() {
        local video="$1" folder_path="$2"
        local video_basename file_mtime
        video_basename="$(basename "$video")"
        file_mtime="$(stat -c '%Y' "$video")"

        if is_cached "$video" "$file_mtime"; then
          echo "cached:    $video_basename"
          skipped_done=$((skipped_done + 1))
          return 0
        fi

        echo "probing:   $video_basename"

        local crc
        crc="$(rhash --crc32 -p '%C' "$video" 2>/dev/null | tr '[:lower:]' '[:upper:]')"
        if [ -z "$crc" ]; then
          echo "  crc failed" >&2
          failed=$((failed + 1))
          return 1
        fi
        echo "  crc32:   $crc"

        local raw
        raw="$(ffprobe -v quiet -print_format json -show_format -show_streams "$video" 2>/dev/null || true)"
        if [ -z "$raw" ]; then
          echo "  ffprobe failed" >&2
          failed=$((failed + 1))
          return 1
        fi

        local probe_json
        probe_json="$(jq --arg vp "$video" --arg crc "$crc" --argjson probe "$raw" -n '
          ($probe.streams // [] | map(select(.codec_type == "video")) | .[0] // {}) as $v
          | ($probe.streams // [] | map(select(.codec_type == "audio"))) as $as
          | ($probe.streams // [] | map(select(.codec_type == "subtitle"))) as $ss
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
              audios: ($as | map({
                codec: (.codec_name // ""),
                channels: (.channels // 0),
                channel_layout: (.channel_layout // ""),
                language: ((.tags // {}) | (.language // .LANGUAGE // "")),
                title: ((.tags // {}) | (.title // .TITLE // "")),
                default: (((.disposition // {}).default // 0) == 1)
              })),
              subtitles: ($ss | map({
                codec: (.codec_name // ""),
                language: ((.tags // {}) | (.language // .LANGUAGE // "")),
                title: ((.tags // {}) | (.title // .TITLE // "")),
                default: (((.disposition // {}).default // 0) == 1),
                forced: (((.disposition // {}).forced // 0) == 1)
              }))
            }')"

        if ! upsert_probe "$video" "$folder_path" "$video_basename" "$crc" "$probe_json"; then
          echo "  db upsert failed" >&2
          failed=$((failed + 1))
          return 1
        fi

        cache_map["$video"]="$(date +%s)"
        processed=$((processed + 1))
        return 0
      }

      for folder in "''${folders[@]}"; do
        name="$(basename "$folder")"

        folder_videos=()
        while IFS= read -r -d "" v; do
          folder_videos+=("$v")
        done < <(find "$folder" -maxdepth 1 -type f \
          '(' -iname "*.mkv" -o -iname "*.mp4" -o -iname "*.avi" \
            -o -iname "*.mov" -o -iname "*.wmv" -o -iname "*.flv" ')' -print0)

        if [ ''${#folder_videos[@]} -eq 0 ]; then
          subdir_video="$(find "$folder" -type f \
            '(' -iname "*.mkv" -o -iname "*.mp4" -o -iname "*.avi" \
              -o -iname "*.mov" -o -iname "*.wmv" -o -iname "*.flv" ')' -print -quit 2>/dev/null)"

          if [ -z "$subdir_video" ]; then
            if [ "$delete_empty" = "1" ]; then
              echo "DELETING:  $name"; rm -rf "$folder"
              delete_folder_rows "''${folder%/}"
              deleted=$((deleted + 1))
            else
              echo "no video:  $name (would delete; DELETE_EMPTY=0)"
            fi
          else
            echo "subdir vid: $name (left alone)"
            skipped_subdir=$((skipped_subdir + 1))
          fi
          continue
        fi

        for video in "''${folder_videos[@]}"; do
          probe_one "$video" "''${folder%/}" || true
        done
      done

      for video in "''${loose_videos[@]}"; do
        probe_one "$video" "" || true
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