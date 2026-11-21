# ZMK build shortcuts. See scripts/build.sh for details.

# build firmware (both halves), incremental. Optional: keyboard name,
# e.g. `just build blackcradio-work` for a second physical keyboard.
# Without an argument the name comes from config/cradio.conf (single source).
build name="":
    ZMK_KEYBOARD_NAME="{{name}}" nix develop -c ./scripts/build.sh

# build firmware with RAM-backed workspace (fast on slow disks)
fast name="":
    ZMK_TMPFS=1 ZMK_KEYBOARD_NAME="{{name}}" nix develop -c ./scripts/build.sh

# copy built firmware to both halves (left first, then right);
# optional: `just copy left` / `just copy right`
alias copy := flash

# flash both halves (left first, then right) via the UF2 bootloader drive;
# optional: `just flash left` / `just flash right`
flash part="both":
    ./scripts/flash.sh "{{part}}"

# build DFU packages for serial flashing (when the UF2 drive is blocked)
dfu:
    ./scripts/make-dfu.sh

# bump ZMK to latest main and refresh the west deps hash
update:
    nix run .#update
