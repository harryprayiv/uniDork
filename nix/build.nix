{ pkgs, lib ? pkgs.lib }:

let
  ucm = pkgs.unison-ucm;
  prebuiltUc = ../bin/unidork-import.uc;
in
pkgs.stdenv.mkDerivation {
  pname = "uniDork";
  version = "0.1.0";

  nativeBuildInputs = [ pkgs.makeWrapper ];
  dontUnpack = true;
  dontBuild = true;
  dontConfigure = true;

  installPhase = ''
    mkdir -p $out/bin $out/share
    cp ${prebuiltUc} $out/share/unidork-import.uc
    makeWrapper "${ucm}/bin/ucm" "$out/bin/unidork-import" \
      --add-flags "run.compiled $out/share/unidork-import.uc"
  '';
}