{
  description = "uniDork, movie metadata pipeline in Unison";

  inputs = {
    nixpkgs.url     = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    unison-nix = {
      url = "github:ceedubs/unison-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, flake-utils, unison-nix }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ unison-nix.overlay ];
        };

        baseConfig = import ./nix/config.nix { };

        libraryConfigFile =
          pkgs.writeText "uniDork.conf" (baseConfig.paths.library + "\n");

        config = baseConfig // {
          paths = baseConfig.paths // {
            configFile = libraryConfigFile;
          };
        };

        secrets      = import ./nix/secrets.nix   { inherit pkgs config; };
        uniDork      = import ./nix/build.nix     { inherit pkgs; };
        postgres     = import ./nix/postgres.nix  { inherit pkgs; inherit (config) database; };
        snapshot = import ./nix/snapshot.nix { inherit pkgs config; };
        mirror = import ./nix/mirror.nix { inherit pkgs config; };
        ide = import ./nix/ide.nix { inherit pkgs config; };
        orchestrator = import ./nix/orchestrator.nix {
          inherit pkgs config secrets uniDork postgres snapshot mirror;
        };

      in {
        packages = {
          default        = orchestrator;
          unidork        = orchestrator;
          unidork-import = uniDork;
          unidork-secrets = secrets.doctor;
        };

        devShells.default = import ./nix/devshell.nix {
          inherit pkgs config secrets uniDork postgres orchestrator snapshot mirror ide;
        };
      })
    // {
      nixosModules.unidork = import ./nix/nixos-module.nix { inherit self; };
      nixosModules.default = self.nixosModules.unidork;
    };

  nixConfig = {
    extra-experimental-features = ["nix-command flakes" "ca-derivations"];
    allow-import-from-derivation = "true";
    extra-substituters = [
      "http://blade:8080/neoblade"
      "https://cache.nixos.org/"
      "https://cache.iog.io"
    ];
    extra-trusted-public-keys = [
      "neoblade:6dIWhT6gb8CEJo7QRYBtG36hmJ6s88Ni7pXmx4b6D74="
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ="
    ];
  };
}
