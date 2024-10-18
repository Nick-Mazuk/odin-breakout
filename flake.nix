{
  description = "Breakout";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, utils }:
    let
      name = "breakout";
    in
    utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        lib = pkgs.lib;
      in
      {
        devShell = pkgs.mkShell {
          name = name;
          buildInputs = with pkgs; [
            odin
            raylib
          ];
        };
      }
    );
}
