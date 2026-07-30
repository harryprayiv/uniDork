# Single source of truth for how uniDork finds its API keys at runtime.
#
# Nothing in here ever reads a secret. It only produces *paths*, which is the
# whole reason this is safe to evaluate: the encrypted blob stays encrypted,
# the plaintext only ever exists at /run/secrets, and the nix store learns
# nothing but a filename.
{ pkgs, lib ? pkgs.lib, config }:

let
  s = config.secrets;

  ordered = map (n: s.entries.${n}) (builtins.attrNames s.entries);

  # Emitted verbatim into both the devshell hook and the orchestrator.
  # Deliberately no `eval` and no indirect expansion, so shellcheck stays happy
  # inside writeShellApplication.
  block = e: ''
    if [ -z "''${${e.env}:-}" ]; then
      if [ -r "${s.runDir}/${e.key}" ]; then
        ${e.env}="${s.runDir}/${e.key}"
      else
        ${e.env}="${s.legacyDir}/${e.legacy}"
      fi
    fi
    export ${e.env}
  '';

  envSetup = lib.concatStrings (map block ordered);

  reportCall = e: ''
    report "${e.env}" "''${${e.env}}" "${e.note}"
  '';

in
{
  inherit envSetup;

  # Which secrets exist, for the NixOS module and anything else that needs
  # to iterate them without re-deriving the naming scheme.
  entries = ordered;

  doctor = pkgs.writeShellApplication {
    name = "unidork-secrets";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      ${envSetup}

      rc=0

      report() {
        var="$1"
        path="$2"
        note="$3"

        src=legacy
        case "$path" in
          ${s.runDir}/*) src=sops ;;
        esac

        if [ ! -e "$path" ]; then
          printf '  %-22s %-6s %-11s %s\n' "$var" "$src" MISSING "$path"
          rc=1
        elif [ ! -r "$path" ]; then
          printf '  %-22s %-6s %-11s %s\n' "$var" "$src" UNREADABLE "$path"
          rc=1
        else
          fp="$(tr -d '\r\n' < "$path" | sha256sum | cut -c1-8)"
          printf '  %-22s %-6s %-11s %s\n' "$var" "$src" "ok:$fp" "$path"
        fi
        printf '  %-22s %s\n' "" "$note"
      }

      echo "uniDork secrets"
      echo ""
      printf '  %-22s %-6s %-11s %s\n' VARIABLE SOURCE STATE PATH
      printf '  %-22s %-6s %-11s %s\n' "----------------------" "------" "-----------" "----"
      ${lib.concatStrings (map reportCall ordered)}
      echo ""
      if [ "$rc" -ne 0 ]; then
        echo "  At least one key is missing or unreadable." >&2
        echo "  sops path expects: sops.secrets.\"unidork/<key>\" owned by a group you are in." >&2
        echo "  legacy path expects: a plaintext file you created by hand." >&2
      fi
      exit "$rc"
    '';
  };
}