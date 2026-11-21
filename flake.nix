{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    zmk-nix = {
      url = "github:lilyinstarlight/zmk-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, zmk-nix }: let
    forAllSystems = nixpkgs.lib.genAttrs (nixpkgs.lib.attrNames zmk-nix.packages);
  in {
    packages = forAllSystems (system: let
      westDeps = zmk-nix.legacyPackages.${system}.fetchZephyrDeps {
        name = "firmware-west-deps";
        src = nixpkgs.lib.sourceFilesBySuffices self [ ".yml" ];
        westRoot = "config";
        hash = "sha256-1ZCYx36xVPjtE/fP3LVtfL0pA6nmDxHx+MJseDV6mLY=";
      };
    in rec {
      default = firmware;

      firmware = zmk-nix.legacyPackages.${system}.buildSplitKeyboard {
        name = "firmware";

        src = nixpkgs.lib.sourceFilesBySuffices self [ ".board" ".cmake" ".conf" ".defconfig" ".dts" ".dtsi" ".h" ".json" ".keymap" ".overlay" ".shield" ".yml" "_defconfig" ];

        board = "nice_nano@2//zmk";
        shield = "cradio_%PART%";

        inherit westDeps;
        zephyrDepsHash = "sha256-1ZCYx36xVPjtE/fP3LVtfL0pA6nmDxHx+MJseDV6mLY=";

        enableZmkStudio = true;

        meta = {
          description = "ZMK firmware";
          license = nixpkgs.lib.licenses.mit;
          platforms = nixpkgs.lib.platforms.all;
        };
      };

      flash = zmk-nix.packages.${system}.flash.override { inherit firmware; };
      update = zmk-nix.packages.${system}.update;
    });

    devShells = forAllSystems (system: {
      default = zmk-nix.devShells.${system}.default;
    });
  };
}
