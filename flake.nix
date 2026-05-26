{
  description = "uniDork — movie metadata pipeline in Unison";

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

        config       = import ./nix/config.nix { };
        uniDork      = import ./nix/build.nix     { inherit pkgs; };
        postgres     = import ./nix/postgres.nix  { inherit pkgs; inherit (config) database; };
        probe        = import ./nix/probe.nix     { inherit pkgs; inherit (config) cache library staging database; };
        orchestrator = import ./nix/orchestrator.nix {
          inherit pkgs config uniDork postgres probe;
        };
      in {
        packages = {
          default        = orchestrator;
          unidork        = orchestrator;
          unidork-import = uniDork;
        };

        devShells.default = import ./nix/devshell.nix {
          inherit pkgs config uniDork postgres probe orchestrator;
        };
      });
}