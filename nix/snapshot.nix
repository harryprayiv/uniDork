{ pkgs, config }:
pkgs.writeShellApplication {
  name = "unidork-push";
  runtimeInputs = [ pkgs.unison-ucm pkgs.git pkgs.gnugrep pkgs.coreutils ];
  text = ''
    set -euo pipefail
    repo="$(git rev-parse --show-toplevel)"
    cd "$repo"
    anchor=".unidork-snapshot-hash"
    old="$(cat "$anchor" 2>/dev/null || echo "")"

    # 1. push to Share + capture reflog, against the real codebase
    ucm transcript.in-place ./nix/unison/snapshot.md

    # 2. new causal hash = hash in numbered reflog row "1." (skips #abcdef tip)
    new="$(grep -oE '^[[:space:]]*1\.[[:space:]].*#[0-9a-z]+' ./nix/unison/snapshot.output.md \
            | grep -oE '#[0-9a-z]+' | head -n1 || true)"
    if [ -z "$new" ]; then echo "could not parse causal hash" >&2; exit 1; fi
    if [ "$new" = "$old" ]; then
      echo "no change since last snapshot ($new)"
      rm -f ./nix/unison/snapshot.output.md
      exit 0
    fi

    # 3. diff the whole session: old anchor -> new, by hash
    diffout=""
    if [ -n "$old" ]; then
      difftmp="$(mktemp -d)/diff.md"
      {
        echo '```ucm'
        echo "uniDork/main> diff.namespace $old $new"
        echo '```'
      } > "$difftmp"
      ucm transcript.in-place "$difftmp" || echo "  (diff failed; hash-only snapshot)"
      diffout="''${difftmp%.md}.output.md"
    fi

    # 4. write hash-anchored backup
    mkdir -p backup
    out="backup/''${new#\#}.md"
    {
      echo "<!-- unison-causal: $new -->"
      echo "<!-- unison-prev:   $old -->"
      echo "<!-- restore: pull @harryprayiv/uniDork/main ; reset $new -->"
      echo "<!-- generated: $(date -u +%Y-%m-%dT%H:%M:%SZ) -->"
      echo ""
      echo "# uniDork snapshot \`$new\`"
      echo ""
      echo "Restore by causal hash, not the text below (diff is a lossy summary)."
      echo ""
      echo '```'
      if [ -n "$diffout" ] && [ -f "$diffout" ]; then
        cat "$diffout"
      else
        echo "(first snapshot — no prior anchor to diff against)"
      fi
      echo '```'
    } > "$out"

    # 5. record anchor + commit
    echo "$new" > "$anchor"
    git add backup/ "$anchor"
    git commit -m "snapshot $new" --quiet
    echo "snapshotted $new -> $out (committed)"

    rm -f ./nix/unison/snapshot.output.md
  '';
}