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
#   ZMK_WORKSPACE    workspace location (default: ./.zmk-workspace)
#   ZMK_BOARD        board to build for (default: nice_nano@2//zmk)
#   ZMK_PARALLEL     parallel compile jobs (default: 8)
#   ZMK_TMPFS        use a RAM-backed workspace in /dev/shm (default: off).
#                    Persists the fetched deps as a tarball cache at
#                    ./.zmk-workspace-cache.{tar.zst,tar.gz,tar} so a reboot
#                    doesn't lose the fetch; the cache is restored when the
#                    manifest pins haven't changed.
#   ZMK_TMPFS_CACHE  cache file path (default: $REPO_ROOT/.zmk-workspace-cache.*)
#
# Notes:
# - The box has 40 cores but limited free RAM (k8s uses ~33G of 62G): ninja's
#   default nproc+2 parallelism OOM-kills compilers (silent build failures).
#   Cap it to a RAM-safe value.
# - west is invoked via `python3 -m west` because the nixpkgs `west` wrapper
#   prepends the bare python dir to PATH for all children; the nanopb protobuf
#   plugin then resolves `env python3` to a python without google.protobuf and
#   fails with "No module named 'google'".

set -euo pipefail

export CMAKE_BUILD_PARALLEL_LEVEL="${ZMK_PARALLEL:-8}"

west() { python3 -m west "$@"; }

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BOARD="${ZMK_BOARD:-nice_nano@2//zmk}"
CONFIG_DIR="$REPO_ROOT/config"

if [ "${ZMK_TMPFS:-0}" = "1" ]; then
    WORKSPACE="${ZMK_WORKSPACE:-/dev/shm/zmk-workspace}"
    if command -v zstd >/dev/null 2>&1; then
        TAR_COMPRESS=(--zstd); CACHE_EXT="tar.zst"
    elif command -v gzip >/dev/null 2>&1; then
        TAR_COMPRESS=(-z); CACHE_EXT="tar.gz"
    else
        TAR_COMPRESS=(); CACHE_EXT="tar"
    fi
    CACHE_FILE="${ZMK_TMPFS_CACHE:-$REPO_ROOT/.zmk-workspace-cache.$CACHE_EXT}"

    free_kb="$(df -kP /dev/shm 2>/dev/null | awk 'NR==2 {print $4}')"
    if [ -z "$free_kb" ] || [ "$free_kb" -lt $((10 * 1024 * 1024)) ]; then
        echo "error: /dev/shm is missing or has < 10 GiB free; ZMK_TMPFS needs RAM-backed space" >&2
        exit 1
    fi
else
    WORKSPACE="${ZMK_WORKSPACE:-$REPO_ROOT/.zmk-workspace}"
    CACHE_FILE=""
fi

# tmpfs mode: restore the deps from the on-disk cache when the workspace is
# gone (e.g. after a reboot) and the cache is not stale relative to west.yml.
if [ -n "$CACHE_FILE" ] && [ ! -f "$WORKSPACE/.west/config" ] && [ -f "$CACHE_FILE" ] \
    && [ "$CACHE_FILE" -nt "$CONFIG_DIR/west.yml" ]; then
    echo "== restoring workspace from $CACHE_FILE"
    mkdir -p "$WORKSPACE"
    tar "${TAR_COMPRESS[@]}" -xf "$CACHE_FILE" -C "$WORKSPACE"
fi

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

# Optional per-keyboard name override (default comes from config/cradio.conf).
# Use e.g. ZMK_KEYBOARD_NAME=bigfoot-work or `just build bigfoot-work` when
# building for a specific physical keyboard.
NAME_ARGS=""
if [ -n "${ZMK_KEYBOARD_NAME:-}" ]; then
    NAME_ARGS="-DCONFIG_ZMK_KEYBOARD_NAME=\"$ZMK_KEYBOARD_NAME\""
fi

build_part left  build/left  "-S studio-rpc-usb-uart" "-DCONFIG_ZMK_STUDIO=y $NAME_ARGS"
build_part right build/right "" "$NAME_ARGS"

# tmpfs mode: persist the deps (not the build dirs) when the cache is missing
# or the manifest changed; quick iterations in between skip this.
if [ -n "$CACHE_FILE" ] && { [ ! -f "$CACHE_FILE" ] || [ "$NEED_UPDATE" = "1" ]; }; then
    echo "== saving workspace cache to $CACHE_FILE"
    mkdir -p "$(dirname "$CACHE_FILE")"
    rm -f "$CACHE_FILE.tmp"
    tar "${TAR_COMPRESS[@]}" -cf "$CACHE_FILE.tmp" \
        --exclude='./build' -C "$WORKSPACE" .
    mv "$CACHE_FILE.tmp" "$CACHE_FILE"
fi

echo
echo "Firmware ready:"
echo "  left:  $WORKSPACE/build/left/zephyr/zmk.uf2"
echo "  right: $WORKSPACE/build/right/zephyr/zmk.uf2"
if [ -n "$CACHE_FILE" ]; then
    echo "  (RAM-backed workspace; deps cached at $CACHE_FILE for reboot persistence)"
fi
