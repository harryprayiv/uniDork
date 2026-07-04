{ pkgs }:

let
  common = ''
    : "''${UNIDORK_REPO:=$HOME/git/uniDork}"

    git_commit_push() {
      msg="$1"; shift
      git -C "$UNIDORK_REPO" add "$@"
      if git -C "$UNIDORK_REPO" diff --cached --quiet; then
        echo "[mirror] nothing changed, no commit"
      else
        git -C "$UNIDORK_REPO" commit -m "$msg"
        if [ "''${UNIDORK_GIT_PUSH:-1}" = 1 ]; then
          git -C "$UNIDORK_REPO" push
        else
          echo "[mirror] committed locally (UNIDORK_GIT_PUSH=0, not pushed)"
        fi
      fi
    }
  '';
in
{
  unidork-log-change = pkgs.writeShellApplication {
    name = "unidork-log-change";
    runtimeInputs = [ pkgs.git pkgs.coreutils ];
    text = ''
      ${common}
      scratch="$UNIDORK_REPO/scratch.u"

      slug="''${1:-update}"
      slug="$(echo "$slug" | tr -cs 'a-zA-Z0-9' '-' | sed 's/^-*//;s/-*$//')"

      if [ ! -s "$scratch" ]; then
        echo "[log-change] $scratch is empty or missing; nothing to archive" >&2
        exit 1
      fi

      mkdir -p "$UNIDORK_REPO/changes"
      dest="$UNIDORK_REPO/changes/$(date +%Y%m%d-%H%M%S)-$slug.u"
      cp "$scratch" "$dest"
      echo "[log-change] archived scratch -> $dest"
      git_commit_push "change: $slug" changes
    '';
  };

  unidork-snapshot = pkgs.writeShellApplication {
    name = "unidork-snapshot";
    runtimeInputs = [ pkgs.unison-ucm pkgs.git pkgs.gawk pkgs.coreutils ];
    text = ''
      ${common}

      tmp="$(mktemp -d)"
      cleanup() { rm -rf "$tmp"; }
      trap cleanup EXIT

      cat > "$tmp/dump.md" <<'TRANSCRIPT'
```ucm
uniDork/main> edit.namespace .
```
TRANSCRIPT

      echo "[snapshot] rendering namespace via ucm transcript (the slow step)..."
      ( cd "$tmp" && ucm transcript.in-place dump.md )

      staged="$tmp/harvest.u"
      : > "$staged"

      shopt -s nullglob
      for u in "$tmp"/*.u; do
        if [ "$u" = "$staged" ]; then continue; fi
        if [ -s "$u" ]; then
          cp "$u" "$staged"
          echo "[snapshot] harvested $(basename "$u") written by edit.namespace"
          break
        fi
      done

      if [ ! -s "$staged" ] && [ -f "$tmp/dump.output.md" ]; then
        awk '/^```[[:space:]]*unison/{f=1; next} /^```/{f=0} f' \
          "$tmp/dump.output.md" > "$staged"
        if [ -s "$staged" ]; then
          echo "[snapshot] harvested unison blocks from transcript output"
        fi
      fi

      if [ ! -s "$staged" ]; then
        echo "[snapshot] dump produced nothing: no .u in temp dir, no unison blocks in output." >&2
        echo "[snapshot] run 'edit.namespace .' manually in ucm once and note where it writes." >&2
        exit 1
      fi

      lines=$(wc -l < "$staged")
      echo "[snapshot] captured $lines lines"
      if [ "$lines" -lt 100 ]; then
        echo "[snapshot] WARNING: suspiciously small for a namespace dump; verify the diff" >&2
      fi
      if [ "$lines" -gt 50000 ]; then
        echo "[snapshot] WARNING: suspiciously large; dump may include vendored lib" >&2
      fi

      mkdir -p "$UNIDORK_REPO/snapshots"
      mv "$staged" "$UNIDORK_REPO/snapshots/namespace.u"
      git_commit_push "snapshot: namespace $(date +%Y-%m-%d)" snapshots
    '';
  };
}