{ pkgs, config }:

let
  ucmPrompt   = "${config.repo.unison.project}/${config.repo.unison.branch}";
  shareTarget = "${config.repo.unison.share}/${config.repo.unison.branch}";

  pushTranscript = pkgs.writeText "unidork-push-transcript.md" ''
```ucm
    ${ucmPrompt}> push ${shareTarget}
    ${ucmPrompt}> reflog
```
  '';
in
pkgs.writeShellApplication {
  name = "unidork-push";
  runtimeInputs = [ pkgs.unison-ucm pkgs.git pkgs.gnugrep pkgs.coreutils ];
  text = ''
    repo="''${UNIDORK_REPO:-${config.repo.dir}}"
    cd "$repo"
    anchor=".unidork-snapshot-hash"
    old="$(cat "$anchor" 2>/dev/null || echo "")"

    tmp="$(mktemp -d)"
    cleanup() { rm -rf "$tmp"; }
    trap cleanup EXIT

    # 1. push to Share + capture reflog. The transcript lives in the
    #    read-only store; transcript.in-place writes its output beside
    #    its input, so copy it somewhere writable first.
    cp ${pushTranscript} "$tmp/push.md"
    chmod u+w "$tmp/push.md"
    ( cd "$tmp" && ucm transcript.in-place push.md )

    # 2. new causal hash = hash in numbered reflog row "1." (skips tip)
    new="$(grep -oE '^[[:space:]]*1\.[[:space:]].*#[0-9a-z]+' "$tmp/push.output.md" \
            | grep -oE '#[0-9a-z]+' | head -n1 || true)"
    if [ -z "$new" ]; then echo "could not parse causal hash" >&2; exit 1; fi
    if [ "$new" = "$old" ]; then
      echo "no change since last snapshot ($new)"
      exit 0
    fi

    # 3. diff the whole session: old anchor -> new, by hash
    diffout=""
    if [ -n "$old" ]; then
      {
        echo '```ucm'
        echo "${ucmPrompt}> diff.namespace $old $new"
        echo '```'
      } > "$tmp/diff.md"
      ( cd "$tmp" && ucm transcript.in-place diff.md ) \
        || echo "  (diff failed; hash-only snapshot)"
      diffout="$tmp/diff.output.md"
    fi

    # 4. write hash-anchored backup
    mkdir -p backup
    out="backup/''${new#\#}.md"
    {
      echo "<!-- unison-causal: $new -->"
      echo "<!-- unison-prev:   $old -->"
      echo "<!-- restore: pull ${shareTarget} ; reset $new -->"
      echo "<!-- generated: $(date -u +%Y-%m-%dT%H:%M:%SZ) -->"
      echo ""
      echo "# ${config.name} snapshot \`$new\`"
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

    # 5. record anchor + commit ONLY our own paths, regardless of what
    #    else happens to be staged in the working tree
    echo "$new" > "$anchor"
    git add -- backup "$anchor"
    if git diff --cached --quiet -- backup "$anchor"; then
      echo "nothing to commit"
    else
      git commit -m "snapshot $new" --quiet -- backup "$anchor"
      echo "snapshotted $new -> $out (committed)"
    fi
  '';
}