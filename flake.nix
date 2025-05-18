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
    # Define common build arguments to avoid repetition
    commonBuildArgs = {
      src = nixpkgs.lib.sourceFilesBySuffices self [ ".board" ".cmake" ".conf" ".defconfig" ".dts" ".dtsi" ".json" ".keymap" ".overlay" ".shield" ".yml" "_defconfig" ];
      board = "nice_nano_v2";
      zephyrDepsHash = "sha256-reAWLQgGuZQiCiN5yGoVlbN6CT5yxl7lEk2/HbvL2x4=";
      meta = {
        description = "ZMK firmware";
        license = nixpkgs.lib.licenses.mit;
        platforms = nixpkgs.lib.platforms.all;
      };
    };
  in {
    packages = forAllSystems (system: rec {
      default = firmware; # Your default build is the split keyboard firmware

      firmware = zmk-nix.legacyPackages.${system}.buildSplitKeyboard (commonBuildArgs // {
        name = "firmware-cradio"; # Gave it a more specific name
        shield = "cradio_%PART%";
        enableZmkStudio = true; # Keeping this enabled as you had it before
      });

      # Add a package output for the settings_reset firmware
      firmware-reset = zmk-nix.legacyPackages.${system}.buildKeyboard (commonBuildArgs // {
        name = "firmware-reset";
        shield = "settings_reset";
        # Typically ZMK Studio is not needed for reset firmware, so we don't enable it here
      });

      flash = zmk-nix.packages.${system}.flash.override { inherit firmware; };
      # You might want a flash-reset target too
      flash-reset = zmk-nix.packages.${system}.flash.override { firmware = firmware-reset; };

      update = zmk-nix.packages.${system}.update;
    });

    devShells = forAllSystems (system: {
      default = zmk-nix.devShells.${system}.default;
    });
  };
}
