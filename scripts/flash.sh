#!/usr/bin/env bash
# Flash built firmware to the halves' nice!nano bootloaders (UF2 drive).
#
# Order: LEFT first, then RIGHT. For each half:
#   1. double-tap reset on that half -> the "nicenano" bootloader drive
#      appears and gets auto-mounted if possible
#   2. the script copies zmk.uf2 and waits for the half to reboot
#      (the drive disappears when flashing is done)
#
# Usage:  scripts/flash.sh [left|right|both]     (default: both)
#         just flash          -> both halves
#
# Flash the workspace-built firmware (.zmk-workspace/build/...), i.e. run
# `just build` first. On hosts where USB mass storage is blocked (e.g. the
# company laptop), use `just dfu` serial flashing instead.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DRIVE_LABEL="nicenano"
WAIT_TIMEOUT=180        # seconds to wait for each bootloader drive
REBOOT_TIMEOUT=30       # seconds to wait for the half to reboot after copy

# Locate the built uf2s (works with both the HDD and the tmpfs workspace).
find_uf2() {
    for ws in "${ZMK_WORKSPACE:-$REPO_ROOT/.zmk-workspace}" "$REPO_ROOT/.zmk-workspace" "/dev/shm/zmk-workspace"; do
        if [ -f "$ws/build/$1/zephyr/zmk.uf2" ]; then
            printf '%s\n' "$ws/build/$1/zephyr/zmk.uf2"
            return 0
        fi
    done
    echo "error: zmk.uf2 not found for '$1' - run 'just build' first" >&2
    return 1
}

# Print "<mountpoint>" if a bootloader drive is mounted, "<device>|" if the
# drive exists but is not mounted, nothing otherwise.
find_drive() {
    # shellcheck disable=SC2031  # lowercase labels: nice!nano uses "nicenano"
    lsblk -rno NAME,LABEL,MOUNTPOINT 2>/dev/null | grep -i "$DRIVE_LABEL" | while IFS= read -r line; do
        local mp
        mp="$(printf '%s\n' "$line" | awk '{print $NF}')"
        if printf '%s\n' "$line" | grep -q " /"; then
            printf '%s\n' "$mp"
        else
            printf '/dev/%s|\n' "$(printf '%s\n' "$line" | awk '{print $1}')"
        fi
    done | head -n 1
}

mount_drive() {
    local dev="$1" out
    if command -v udisksctl >/dev/null 2>&1; then
        echo "== mounting $dev via udisksctl"
        if out="$(udisksctl mount -b "$dev" 2>&1)"; then
            printf '%s\n' "$out" | sed -n 's/.* at \(.*\)\.?$/\1/p'
            return 0
        fi
        echo "   udisksctl failed: $out" >&2
    fi
    return 1
}

wait_for_drive() {
    local part="$1" waited=0 found
    while true; do
        found="$(find_drive)"
        if [ -n "$found" ]; then
            printf '%s\n' "$found"
            return 0
        fi
        if [ "$waited" -ge "$WAIT_TIMEOUT" ]; then
            echo "error: no $DRIVE_LABEL drive after ${WAIT_TIMEOUT}s" >&2
            echo "       double-tap reset on the $part half, or use 'just dfu'" >&2
            echo "       (serial flashing) if USB mass storage is blocked" >&2
            return 1
        fi
        sleep 2
        waited=$((waited + 2))
    done
}

flash_half() {
    local part="$1" uf2 drive
    uf2="$(find_uf2 "$part")"
    echo "== waiting for the $part half's bootloader (double-tap reset on $part)"
    drive="$(wait_for_drive "$part")"

    if [[ "$drive" == *"|" ]]; then
        # Drive present but not mounted (device path, empty mountpoint).
        if ! drive="$(mount_drive "${drive%|}")"; then
            echo "error: could not mount ${drive%|} - mount it manually and retry" >&2
            exit 1
        fi
    fi

    echo "== flashing $part: $(basename "$uf2") -> $drive"
    cp "$uf2" "$drive/"
    sync "$drive/$(basename "$uf2")" 2>/dev/null || sync || true

    # The bootloader reboots the half when done; the drive then disappears.
    local waited=0
    while [ -n "$(find_drive)" ] && [ "$waited" -lt "$REBOOT_TIMEOUT" ]; do
        sleep 2
        waited=$((waited + 2))
    done
    if [ -n "$(find_drive)" ]; then
        echo "   note: drive still present after ${REBOOT_TIMEOUT}s - check the half" >&2
    else
        echo "   $part done (drive gone, half rebooted)"
    fi
}

case "${1:-both}" in
    left | right | both | "") ;;
    *)
        echo "usage: $0 [left|right|both]" >&2
        exit 1
        ;;
esac

MODE="${1:-both}"
if [ "$MODE" != "right" ]; then
    flash_half left
fi
if [ "$MODE" != "left" ]; then
    flash_half right
fi
echo "all done"
