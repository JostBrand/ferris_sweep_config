# ZMK build shortcuts. See scripts/build.sh for details.

# build firmware (both halves), incremental. Optional: keyboard name,
# e.g. `just build bigfoot-work` to build for a specific physical keyboard.
build name="bigfoot":
    ZMK_KEYBOARD_NAME="{{name}}" nix develop -c ./scripts/build.sh

# build firmware with RAM-backed workspace (fast on slow disks)
fast name="bigfoot":
    ZMK_TMPFS=1 ZMK_KEYBOARD_NAME="{{name}}" nix develop -c ./scripts/build.sh

# copy firmware to the controller drives
flash:
    nix run .#flash

# build DFU packages for serial flashing (when the UF2 drive is blocked)
dfu:
    ./scripts/make-dfu.sh

# bump ZMK to latest main and refresh the west deps hash
update:
    nix run .#update
