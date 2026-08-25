# ZMK build shortcuts. See scripts/build.sh for details.

# build firmware (both halves), incremental
build:
    nix develop -c ./scripts/build.sh

# build firmware with RAM-backed workspace (fast on slow disks)
fast:
    ZMK_TMPFS=1 nix develop -c ./scripts/build.sh

# copy firmware to the controller drives
flash:
    nix run .#flash

# bump ZMK to latest main and refresh the west deps hash
update:
    nix run .#update
