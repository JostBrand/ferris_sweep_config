#!/usr/bin/env bash
# Fast local ZMK build with a persistent west workspace.
#
# First run fetches the west workspace (zmk + zephyr + modules, ~30-60 min on
# a slow/busy machine). Afterwards, keymap/config changes only recompile
# (~1-3 min) - no nix-store hashing of the whole zephyr tree.
#
# Usage:  nix develop -c ./scripts/build.sh
#
# Environment overrides:
#   ZMK_WORKSPACE  workspace location (default: ./.zmk-workspace)
#   ZMK_BOARD      board to build for (default: nice_nano@2//zmk)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKSPACE="${ZMK_WORKSPACE:-$REPO_ROOT/.zmk-workspace}"
BOARD="${ZMK_BOARD:-nice_nano@2//zmk}"
CONFIG_DIR="$REPO_ROOT/config"

mkdir -p "$WORKSPACE/config"

# Keep the workspace manifest in sync with config/west.yml (pinned revisions).
NEED_UPDATE=0
if ! cmp -s "$CONFIG_DIR/west.yml" "$WORKSPACE/config/west.yml"; then
    cp "$CONFIG_DIR/west.yml" "$WORKSPACE/config/west.yml"
    NEED_UPDATE=1
fi

cd "$WORKSPACE"

if [ ! -f .west/config ]; then
    echo "== initializing west workspace at $WORKSPACE"
    west init -l config
    west update
    west zephyr-export
elif [ "$NEED_UPDATE" = "1" ]; then
    echo "== west.yml changed, updating workspace"
    west update
    west zephyr-export
fi

build_part() {
    local part="$1" build_dir="$2" west_args="$3" cmake_args="$4"
    echo "== building $part ($BOARD / cradio_$part)"
    # shellcheck disable=SC2086
    west build -s zmk/app -d "$build_dir" -b "$BOARD" $west_args -- \
        -DZMK_CONFIG="$CONFIG_DIR" -DZMK_EXTRA_MODULES="$REPO_ROOT" \
        -DSHIELD="cradio_$part" $cmake_args
}

build_part left  build/left  "-S studio-rpc-usb-uart" "-DCONFIG_ZMK_STUDIO=y"
build_part right build/right "" ""

echo
echo "Firmware ready:"
echo "  left:  $WORKSPACE/build/left/zephyr/zmk.uf2"
echo "  right: $WORKSPACE/build/right/zephyr/zmk.uf2"
