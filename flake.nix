{
  description = "uniDork — movie metadata pipeline in Unison";

  inputs = {
    nixpkgs.url      = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url  = "github:numtide/flake-utils";
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

        uniDork = import ./nix/build.nix { inherit pkgs; };
      in {
        packages = {
          default = uniDork;
          unidork-import = uniDork;
        };

        devShells.default = import ./nix/devshell.nix {
          inherit pkgs uniDork;
        };
      });
}