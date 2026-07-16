{ pkgs, lib ? pkgs.lib, config }:

# Project-scoped editor integration. This deliberately does NOT install any
# editor. It declares two things, as data:
#
#   1. Which extensions this repo benefits from  -> .vscode/extensions.json
#      (VSCode/VSCodium shows these as recommendations; nothing is installed
#      without the user clicking yes. No editor? The files are inert.)
#
#   2. Language wiring for this repo             -> .vscode/settings.json
#      (workspace settings, merged OVER the user's personal settings; their
#      theme/fonts/auth/keybindings are untouched.)
#
# Rule that keeps this sane: settings reference tools by BARE NAME (nixd,
# nixfmt), never by store path. The devshell provides those binaries on
# PATH; the mkhl.direnv extension injects the devshell env into the editor.
# Tools come from the shell, wiring from these files, the editor from the
# human.

let
  # ------------------------------------------------------------------
  # Language/extension sets. Add a language by adding a set here and
  # merging it into `profile` below — nothing else changes.
  # ------------------------------------------------------------------
  langs = {
    unison = {
      recommendations = [ "unison-lang.unison" ];
      settings = {
        "files.associations" = { "*.u" = "unison"; };
        # ucm serves LSP on 127.0.0.1:5757 while running; the extension
        # attaches on its own. Nothing to point at a binary.
      };
    };

    nix = {
      recommendations = [
        "jnoortheen.nix-ide"
        "atomicspirit.nix-embedded-highlighter"
      ];
      settings = {
        "nix.enableLanguageServer" = true;
        "nix.serverPath" = "nixd";              # from devshell PATH, not a store path
        "nix.serverSettings" = {
          nixd.formatting.command = [ "nixfmt" ];
        };
        "[nix]" = {
          "editor.defaultFormatter" = "jnoortheen.nix-ide";
          "editor.formatOnSave" = false;
        };
      };
    };

    # Kept as the template for your other repos (Cheeblr etc.) — not merged
    # into this project's profile because there is no Haskell or PureScript
    # here, and recommending dead-weight extensions is noise.
    haskell = {
      recommendations = [ "haskell.haskell" "justusadam.language-haskell" ];
      settings = {
        "[haskell]" = {
          "editor.defaultFormatter" = "haskell.haskell";
          "editor.formatOnSave" = false;
        };
      };
    };

    purescript = {
      recommendations = [
        "nwolverson.language-purescript"
        "nwolverson.ide-purescript"
      ];
      settings = {
        "[purescript]" = {
          "editor.defaultFormatter" = "nwolverson.ide-purescript";
          "editor.formatOnSave" = false;
        };
      };
    };
  };

  # direnv integration is what makes bare-name tool references work inside
  # the editor, so it's a project recommendation, not a personal one.
  base = {
    recommendations = [ "mkhl.direnv" ];
    settings = {
      "direnv.restart.automatic" = true;
    };
  };

  # ------------------------------------------------------------------
  # This repo's profile: base + unison + nix. That's it.
  # ------------------------------------------------------------------
  profile = {
    recommendations =
      base.recommendations
      ++ langs.unison.recommendations
      ++ langs.nix.recommendations;
    settings =
      base.settings
      // langs.unison.settings
      // langs.nix.settings;
  };

  extensionsJson = pkgs.writeText "extensions.json" (builtins.toJSON {
    inherit (profile) recommendations;
  });

  settingsJson = pkgs.writeText "settings.json"
    (builtins.toJSON profile.settings);

in
{
  # Tools the workspace settings refer to by bare name. The devshell pulls
  # this list in so the names always resolve when the editor inherits the
  # direnv environment.
  tools = [ pkgs.nixd pkgs.nixfmt ];

  # Idempotent sync of the generated files into .vscode/. Nix is the source
  # of truth: local edits to these two files are overwritten, loudly.
  sync = pkgs.writeShellApplication {
    name = "unidork-ide-sync";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      repo="''${UNIDORK_REPO:-${config.repo.dir}}"
      vs="$repo/.vscode"
      mkdir -p "$vs"

      sync_one() {
        src="$1"; dst="$2"
        if ! cmp -s "$src" "$dst" 2>/dev/null; then
          if [ -f "$dst" ]; then
            echo "[ide-sync] overwriting $dst (nix is the source of truth; edit nix/ide.nix instead)"
          else
            echo "[ide-sync] writing $dst"
          fi
          install -m 0644 "$src" "$dst"
        fi
      }

      sync_one ${extensionsJson} "$vs/extensions.json"
      sync_one ${settingsJson}   "$vs/settings.json"
    '';
  };
}