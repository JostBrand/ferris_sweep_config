#!/usr/bin/env bash
# Convert built zmk.uf2 files into DFU packages for serial flashing.
#
# Use this on hosts where the UF2 drive can't be mounted (e.g. a company
# laptop whose OS only accepts BitLocker-encrypted storage): the nice!nano
# bootloader supports flashing over USB serial via adafruit-nrfutil.
#
# Requires only python3 - no admin needed: tools go into a user-level venv
# under ./.zmk-dfu-tools/ (gitignored).
#
# Usage:  just dfu   (or: ./scripts/make-dfu.sh)
#
# Then, on the target machine:
#   1. double-tap reset on the half -> bootloader with UF2 + CDC serial
#   2. find the port: COMx on Windows, /dev/ttyACM0 on Linux
#   3. flash: adafruit-nrfutil dfu serial -pkg <zip> -p <port> -b 115200

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOLS_DIR="$REPO_ROOT/.zmk-dfu-tools"
VENV_DIR="$TOOLS_DIR/venv"
UF2CONV="$TOOLS_DIR/uf2conv.py"
FAMILIES="$TOOLS_DIR/uf2families.json"
FAMILY_ID="0xADA52840"          # nRF52840
DEV_TYPE="0x0052"               # nRF52840

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

setup_tools() {
    if [ ! -x "$VENV_DIR/bin/adafruit-nrfutil" ]; then
        echo "== setting up DFU tools in $TOOLS_DIR"
        mkdir -p "$TOOLS_DIR"
        if python3 -m venv "$VENV_DIR" 2>/dev/null; then
            "$VENV_DIR/bin/pip" install -q --upgrade pip
            "$VENV_DIR/bin/pip" install -q adafruit-nrfutil intelhex
        elif python3 -m pip --version >/dev/null 2>&1; then
            python3 -m pip install -q --user adafruit-nrfutil intelhex
            VENV_DIR=""   # use system python below
        else
            echo "error: no usable python3 (need venv or pip). On Ubuntu WSL:" >&2
            echo "  sudo apt install python3-venv python3-pip" >&2
            exit 1
        fi
    fi
    if [ ! -f "$UF2CONV" ]; then
        curl -sL -o "$UF2CONV" https://raw.githubusercontent.com/microsoft/uf2/master/utils/uf2conv.py
        curl -sL -o "$FAMILIES" https://raw.githubusercontent.com/microsoft/uf2/master/utils/uf2families.json
    fi
}

make_pkg() {
    local part="$1" uf2="$2" dir
    dir="$(dirname "$uf2")"
    echo "== packaging $part ($uf2)"
    # shellcheck disable=SC2086
    "$PY" "$UF2CONV" -c -f "$FAMILY_ID" -o "$dir/zmk_$part.bin" "$uf2" > /dev/null
    "$PY" - "$uf2" "$dir/zmk_$part.bin" "$dir/zmk_$part.hex" <<'EOF'
import struct, sys
from intelhex import IntelHex

uf2_path, bin_path, hex_path = sys.argv[1], sys.argv[2], sys.argv[3]
with open(uf2_path, "rb") as f:
    addr = struct.unpack("<I", f.read(32)[12:16])[0]
ih = IntelHex()
ih.loadbin(bin_path, offset=addr)
ih.write_hex_file(hex_path)
EOF
    "$NRFUTIL" dfu genpkg --dev-type "$DEV_TYPE" \
        --application "$dir/zmk_$part.hex" "$dir/zmk_$part.zip" > /dev/null
    echo "   -> $dir/zmk_$part.zip"
}

setup_tools
if [ -n "$VENV_DIR" ]; then
    PY="$VENV_DIR/bin/python"
    NRFUTIL="$VENV_DIR/bin/adafruit-nrfutil"
else
    PY="$(command -v python3)"
    NRFUTIL="$(command -v adafruit-nrfutil)"
fi

for part in left right; do
    uf2="$(find_uf2 "$part")"
    make_pkg "$part" "$uf2"
done

cat <<EOF

DFU packages ready. To flash on a machine that blocks the UF2 drive:

  1. Double-tap reset on the half (bootloader shows up as a drive AND a
     serial port - the serial port is what we use).
  2. Find the serial port:
       Windows:   check Device Manager -> COM port (e.g. COM7)
       Linux/WSL: ls /dev/ttyACM*
  3. Flash with adafruit-nrfutil:
       adafruit-nrfutil dfu serial -pkg <zip> -p <port> -b 115200
     e.g.  Windows: adafruit-nrfutil dfu serial -pkg zmk_left.zip -p COM7 -b 115200
           Linux:   adafruit-nrfutil dfu serial -pkg zmk_left.zip -p /dev/ttyACM0 -b 115200
  4. Repeat for the right half (zmk_right.zip).

  adafruit-nrfutil can be installed with:
       pip install --user adafruit-nrfutil
EOF
