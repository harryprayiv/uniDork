# uniDork NixOS module, secrets only.
#
# ------------------------------------------------------------------------
# THIS MODULE DELIBERATELY SETS NO GLOBAL sops-nix OPTION.
#
# It never touches sops.defaultSopsFile, sops.age.*, sops.gnupg.*,
# sops.validateSopsFiles, or sops.keepGenerations. Every one of those is a
# singleton: a second definition either fails evaluation with a conflict, or,
# worse, silently wins and makes every *other* secret on the host fail to
# decrypt at activation time. Services that depend on those secrets then fail
# to start on the next boot.
#
# All this module does is add three entries under sops.secrets, each with its
# own explicit sopsFile, each namespaced under "unidork/". That is additive
# and cannot disturb an existing setup.
#
# It assumes sops-nix's own NixOS module is already imported by the host
# config, which it is if any other secret on this machine works.
# ------------------------------------------------------------------------
{ self }:

{ config, lib, pkgs, ... }:

let
  cfg = config.services.unidork;
  udConfig = import ./config.nix { };
  entries = udConfig.secrets.entries;
in
{
  options.services.unidork = {
    enable = lib.mkEnableOption "uniDork API key provisioning via sops-nix";

    user = lib.mkOption {
      type = lib.types.str;
      default = "bismuth";
      description = ''
        Existing user that runs the uniDork CLI. Added to the unidork group so
        it can read the decrypted keys. Must already be declared elsewhere in
        the host config.
      '';
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "unidork";
      description = ''
        Group that owns the decrypted keys. A dedicated group rather than
        "users" so that the forthcoming web service can get its own account and
        be added here without widening access to every human on the box.
      '';
    };

    secretsFile = lib.mkOption {
      type = lib.types.path;
      default = self + "/secrets/unidork.yaml";
      defaultText = lib.literalExpression "\${uniDork flake}/secrets/unidork.yaml";
      description = ''
        SOPS-encrypted YAML holding uniDork's API keys, nested under a
        top-level `unidork:` mapping. Must be git-tracked in the uniDork repo,
        otherwise the flake will not see it.

        Override this if you would rather keep the blob alongside the rest of
        your host secrets, which avoids a flake lock bump every time you rotate
        a key.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    users.groups.${cfg.group} = { };

    users.users.${cfg.user}.extraGroups = [ cfg.group ];

    # sops-nix treats "/" in a secret name as a nesting separator when reading
    # the YAML, and as a directory separator when writing under /run/secrets.
    # So "unidork/tmdb_token" reads unidork.tmdb_token and lands at
    # /run/secrets/unidork/tmdb_token, which is exactly what config.nix says.
    sops.secrets = lib.mapAttrs'
      (_: e: lib.nameValuePair "unidork/${e.key}" {
        sopsFile = cfg.secretsFile;
        owner = cfg.user;
        group = cfg.group;
        mode = "0440";
      })
      entries;
  };
}
