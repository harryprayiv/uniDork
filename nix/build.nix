{ pkgs, lib ? pkgs.lib }:

pkgs.unison.lib.buildFromTranscript {
  pname = "uniDork";
  version = "0.1.0";

  src = lib.fileset.toSource {
    root = ../.;
    fileset = ../scratch.u;
  };

  transcript = ../compile.md;

  compiledHash = "sha256-fRDQxQDx7SnWh0hlrZCTfQ10xMyOKd3WYPo+2oQpICs=";

  meta = {
    description = "uniDork movie library importer";
    mainProgram = "unidork-import";
  };
}