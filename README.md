# Ferris Sweep ZMK Config

ZMK firmware configuration for a [Ferris Sweep](https://github.com/davidphilipbarr/Sweep) (cradio shield) split keyboard with nice!nano v2 controllers. Firmware builds run via GitHub Actions on every push; download the artifacts from the workflow run.

## Hardware

- Board: `nice_nano@2//zmk` (nice!nano v2)
- Shield: `cradio` (left/right)
- Layout: Colemak-DH, 34 keys (3x5 + 3 thumbs per half)

## Layers

| Index | Name        | Studio name   | Purpose                                        |
|-------|-------------|---------------|------------------------------------------------|
| 0     | QWERTY      | Colemak       | Colemak-DH base layer                          |
| 1     | SYM         | Symbols       | Symbols (`&mo SYM` on left thumb)              |
| 2     | SYM_2       | Numbers & Fn  | Numbers + function keys (`&lt SYM_2` on Z/DOT) |
| 3     | FNC         | Arrows / WM   | Arrows, window-manager shortcuts, F-keys, mouse emulation |
| 4     | FNC_2       | Settings      | Bluetooth, media keys, Studio unlock           |
| 5     | NUMPAD      | Numpad        | Numpad on the right half (via combo), left thumb exits |

Umlauts (ä/ö/ü/ß) are handled host-side via the AutoHotkey script in [`ahk/umlaute.ahk`](ahk/umlaute.ahk) — see [Umlaute & AHK](#umlaute--ahk).

## Home row mods

The home row uses ZMK's "timeless" positional hold-taps (`hml`/`hmr` in `cradio.keymap`) instead of plain `&mt`:

- `balanced` flavor, `require-prior-idle-ms = <125>`, `tapping-term-ms = <250>`, `quick-tap-ms = <175>`, `hold-trigger-on-release`
- Mods only trigger when the held key is combined with an opposite-hand key (`hold-trigger-key-positions`), so same-hand rolls don't fire mods accidentally. With `balanced` + `hold-trigger-on-release`, the hold only resolves when the mod key is still held at the *release* of the chorded key — normal typing rolls stay taps.
- Do **not** switch these to `tap-unless-interrupted`: it sends the tap on press (holding a home-row key auto-repeats the letter) and turns any overlapping roll into a chord (e.g. typing "is" fires RAlt+s → the AHK script types ß).
- Uniform timing scheme across hold-taps and combos: HRM 125 ms, `&lt` 100 ms, `&mt` 80 ms, combos 80 ms (with exceptions below), sticky layers 3 s.

Tradeoffs:

- Same-hand chords (e.g. Ctrl+Shift on S+T) don't work; use the right-hand Shift on N.
- Deliberate chords need a short pause (~125 ms idle) before the mod key, and the mod key must stay held until the chorded key is released (the mod applies at release, not press).
- AltGr (for umlauts) lives on the right thumb, not on I, so the home-row mods can never leak an AltGr into the AHK script.
- If right-half mods don't trigger after flashing, ZMK's positional mirroring on the peripheral side may need the trigger lists adjusted (see the keymap).

## Umlaute & AHK

Umlauts are host-side: hold the **right thumb** (AltGr) and tap a/o/u/s for ä/ö/ü/ß; Shift or CapsLock gives uppercase. The right thumb is a `hold-preferred` AltGr key (`&hm_altgr RALT RET`, tap = Enter) — it activates immediately, and because AltGr no longer lives on the I key, normal typing can never fire a stray RAlt into the AHK script (typing "is" can't become ß anymore).

The script includes an anti-stuck guard: if ZMK loses an Alt release (BLE event loss or a home-row-mod roll), the OS keeps AltGr logically pressed and every a/o/u/s would type umlauts. After each hotkey the script therefore releases AltGr at the OS level whenever the key is no longer physically held. Hotkeys use explicit `>!` / `>!+` variants instead of the `*` wildcard so Ctrl/Win misfires from the home-row mods don't trigger umlauts.

Suspend/resume the hotkeys with Win+Alt+G.

## Combos

Combos are positional and mostly active on layers 0-3 unless noted. The combos node sets `combo-term = <50>` (forgiving deliberate rolls) and `require-prior-idle-ms = <80>` (prevents accidental cut/copy/paste while typing fast). Exceptions: `esc` is exempt (`0`) so it fires instantly after typing, and `improve_prompt` uses `150` to guard against accidental macro injection.

| Combo            | Keys (layer 0)          | Output                    |
|------------------|-------------------------|---------------------------|
| esc              | Q + W                   | Escape (all layers)       |
| cut              | X + C                   | Ctrl+X                    |
| copy             | C + D                   | Ctrl+C                    |
| paste            | D + V                   | Ctrl+V                    |
| to_default       | Q + UNDER (pinky columns) | Go to layer 0 (layers 1-5) |
| alt_quotes       | J + L                   | `"` (layer 0 only)        |
| numpad           | U + Y + UNDER           | Go to NUMPAD (layer 0)    |
| backspace        | P + F                   | Backspace                 |
| delete           | L + U                   | Delete                    |
| settings         | Q + W + F               | Go to settings (layer 0)  |
| improve_prompt   | Sym thumb + Space       | Types the LLM prompt (layer 0) |
| alt_ret          | G + T                   | Enter                     |
| capsword         | DOT + COMMA             | Caps Word (layer 0)       |
| alt_tab          | M + N                   | Tab                       |
| alt_semicolon    | P + B                   | `;`                       |
| studio_unlock    | Z + A + Q               | Unlock ZMK Studio         |
| sym_once         | Z + X                   | Sticky symbol layer (layer 0) |
| undo             | V + SLASH               | Ctrl+Z                    |
| redo             | SLASH + K               | Ctrl+Shift+Z              |
| save             | W + F                   | Ctrl+S                    |
| word_backspace   | B + J                   | Ctrl+Backspace            |
| word_delete      | G + M                   | Ctrl+Delete               |

## Mouse & media

- Mouse emulation lives on the Arrows / WM layer: Z/X/C/V-ish keys move the pointer (UP/LEFT/DOWN on the left bottom row, RIGHT on the left thumb), the right half scrolls (`SCRL_UP`/`SCRL_DOWN`) and clicks (left/right mouse button). Enabled by `CONFIG_ZMK_POINTING=y`.
- Media keys are on the settings layer: play/pause, previous/next song, volume up/down, mute.

## The LLM prompt macro

`improve_prompt` types `IMPROVE THIS TEXT AND MAKE IT CONCISE` with Shift+Enter before and Ctrl+Enter after, intended to act on selected text in a chat UI.

The macro is long enough to overflow ZMK's default 64-event behavior queue (each tapped key uses 2 events), which previously caused it to stop mid-word and leave a key stuck repeating. `CONFIG_ZMK_BEHAVIORS_QUEUE_SIZE=512` in `cradio.conf` fixes this, and `wait-ms`/`tap-ms` of 30 ms keep BLE from reordering grouped HID events.

## ZMK Studio

ZMK Studio support is enabled on the left (central) half only, per the ZMK docs:

- `snippet: studio-rpc-usb-uart` + `-DCONFIG_ZMK_STUDIO=y` in `build.yaml`
- Unlock via the `studio_unlock` combo (Z+A+Q) or the `&studio_unlock` key on the settings layer

Note: once ZMK Studio manages the keymap, subsequent changes in `cradio.keymap` are ignored until "Restore Stock Settings" is triggered from Studio.

## Flashing on the go (Windows / WSL)

On a Windows laptop where the OS only accepts BitLocker-encrypted external storage, WSL2 + [usbipd-win](https://github.com/dorssel/usbipd-win) usually still works: the bootloader drive is **detached from Windows** and handed to WSL, so the BitLocker removable-storage policy never sees it.

```powershell
# one-time (admin): install usbipd-win, then
winget install --interactive --exact dorssel.usbipd-win

# per device, admin:
usbipd list                        # note the busid of the keyboard half (in bootloader mode)
usbipd bind --busid <busid>

# non-admin:
usbipd attach --wsl --busid <busid>
```

In WSL (needs a WSL command prompt open so the VM stays alive):

```bash
lsusb                                        # device should be listed
ls /dev/sd*                                  # bootloader appears as a disk
sudo mkdir -p /mnt/flash && sudo mount /dev/sdX /mnt/flash
sudo cp build/left/zephyr/zmk.uf2 /mnt/flash/   # half resets and flashes
sudo umount /mnt/flash
```

Caveats:

- `usbipd bind` needs admin rights once per device; `usbipd attach` doesn't.
- If the company enforces device control at the USB *enumeration* level (Defender for Endpoint device control, DLP agent), `usbipd list` will already be empty — then storage passthrough is blocked regardless of WSL.
- **Fallback that usually works even then**: serial DFU. Double-tap reset puts the Adafruit bootloader into DFU mode exposing a USB **serial** port (plus the drive) — storage policies don't apply to serial. `just dfu` packages the built UF2s as DFU zips (`scripts/make-dfu.sh`), then flash with:

  ```
  adafruit-nrfutil dfu serial -pkg zmk_left.zip -p COM7 -b 115200   # Windows
  adafruit-nrfutil dfu serial -pkg zmk_left.zip -p /dev/ttyACM0 -b 115200  # Linux/WSL
  ```

  `adafruit-nrfutil` is a plain `pip install --user adafruit-nrfutil` (no admin). The DFU zips land next to the built UF2s (`.zmk-workspace/build/{left,right}/zmk_{left,right}.zip`).
- No-mount alternative for keymap tweaks only: ZMK Studio over BLE.

## Multiple keyboards

ZMK derives the BLE address from each chip's factory-programmed ID (nRF52 FICR `DEVICEADDR`, see Zephyr's nRF5 controller), so two identical keyboards **never conflict on address** — both can be paired to the same host without action on your part. What *does* need differentiating is the advertised name:

- **Set a unique name per keyboard** in `build.yaml` (`-DCONFIG_ZMK_KEYBOARD_NAME="bigfoot-<place>"` + matching `artifact-name`); one pair of entries per physical keyboard. This prevents ambiguous pairing (e.g. Windows refusing a second device with an identical name).
- Locally, build for a specific keyboard with `just build bigfoot-work` (default name is `bigfoot` from `cradio.conf`). Renaming does **not** reset host pairings — the BLE address stays the same, only the advertised name changes.
- **Pair each keyboard's halves one at a time** (power only one pair during first bonding) so a central never bonds with the other keyboard's peripheral; afterwards the bond is sticky.

## Build

### Fast local iteration (recommended)

```bash
just build   # incremental build (both halves)
just fast    # same, but RAM-backed workspace (fast on slow disks)
just flash   # copy firmware to the controller drives
just update  # bump ZMK to latest main + refresh deps hash
```

`just build` is a wrapper around `nix develop -c ./scripts/build.sh` (tmpfs mode via `ZMK_TMPFS=1`).

The script handles two host-specific quirks:

- **Parallelism** — the machine has 40 cores but limited free RAM (k8s uses ~33G of 62G), so ninja's default `nproc+2` parallelism OOM-kills compilers (silent build failures). `ZMK_PARALLEL` (default 8) caps it.
- **Python resolution** — the nixpkgs `west` wrapper prepends the bare python dir to PATH, which breaks the nanopb protobuf plugin (`No module named 'google'`). The script runs west via `python3 -m west` to avoid this.

Optional: `ZMK_TMPFS=1` moves the workspace to RAM (`/dev/shm`), with the fetched deps cached as `.zmk-workspace-cache.tar.*` on disk so a reboot doesn't lose the fetch — builds get notably faster on a slow disk. Needs ~10 GiB free in `/dev/shm`.

### Reproducible nix build

```bash
nix build .#firmware        # builds both halves -> result/zmk_left.uf2, result/zmk_right.uf2
nix run .#flash             # interactive copy to the controller drives
nix run .#update            # bump ZMK to latest main + refresh the deps hash
```

The flake is based on [zmk-nix](https://github.com/lilyinstarlight/zmk-nix) and builds exactly the same sources as CI. Note that the west-deps fetch is scoped to `west.yml`, so keymap edits don't re-trigger it — but the derivation still re-hashes the fetched tree on every change, which is slow on loaded machines. `config/west.yml` pins ZMK `main` and the Zephyr 4.1 zmk fork to specific commits (with branch comments) so nix builds are reproducible — run `nix run .#update` to ride bleeding edge deliberately and re-lock the `zephyrDepsHash`.

### With west (manual)

```bash
west build -d build/left  -b nice_nano@2//zmk -- -DZMK_CONFIG=$PWD/config -DSHIELD=cradio_left
west build -d build/right -b nice_nano@2//zmk -- -DZMK_CONFIG=$PWD/config -DSHIELD=cradio_right
```
