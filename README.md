# Ferris Sweep ZMK Config

ZMK firmware configuration for a [Ferris Sweep](https://github.com/davidphilipbarr/Sweep) (cradio shield) split keyboard with nice!nano v2 controllers. Firmware builds run via GitHub Actions on every push; download the artifacts from the workflow run.

## Hardware

- Board: `nice_nano@2//zmk` (nice!nano v2)
- Shield: `cradio` (left/right)
- Layout: Colemak-DH, 34 keys (3x5 + 3 thumbs per half)

## Layers

| Index | Name        | Studio name   | Purpose                                        |
|-------|-------------|---------------|------------------------------------------------|
| 0     | BASE        | Colemak       | Colemak-DH base layer                          |
| 1     | SYM         | Symbols       | Symbols (`&lt SYM RET` on the inner right thumb) |
| 2     | SYM_2       | Numbers & Fn  | Numbers + function keys (`&lt SYM_2` on Z/DOT) |
| 3     | FNC         | Arrows / WM   | Arrows, window-manager shortcuts, F-keys, mouse emulation |
| 4     | FNC_2       | Settings      | Bluetooth, media keys, Studio unlock; top right types `a` to check the active BT profile |
| 5     | NUMPAD      | Numpad        | Numpad on the right half (via combo), left thumb exits; ä/ö/ü on the A/O/U keys |
| 6     | UMLAUT      | Umlauts       | Momentary while I is held; a/o/u/s become the direct ä/ö/ü/ß keys, rest transparent |
| 7     | GAME        | Game          | Base layer with home row mods and all holds stripped — for games (see [Game mode](#game-mode)) |

Umlauts (ä/ö/ü) are direct German-layout keys — the firmware emits German HID usages (`config/keys_de.h`), so **every host must run a stock German keyboard layout**; see [Layout: German](#layout-german). ß is not used in prose (Swiss keyboarding), but the I-hold + s chord types it anyway for completeness.

## Home row mods

The home row uses ZMK's "timeless" positional hold-taps (`hml`/`hmr`/`hmr_uml` in `cradio.keymap`) instead of plain `&mt`:

- `balanced` flavor, `require-prior-idle-ms = <125>`, `tapping-term-ms = <250>`, `quick-tap-ms = <175>`, `hold-trigger-on-release`
- Mods only trigger when the held key is combined with an opposite-hand key (`hold-trigger-key-positions`), so same-hand rolls don't fire mods accidentally. With `balanced` + `hold-trigger-on-release`, the hold only resolves when the mod key is still held at the *release* of the chorded key — normal typing rolls stay taps.
- Do **not** switch these to `tap-unless-interrupted`: it sends the tap on press (holding a home-row key auto-repeats the letter) and turns any overlapping roll into a chord (e.g. typing "is" fires the I-hold umlaut layer → ß).
- Uniform timing scheme across hold-taps and combos: HRM 125 ms, `&lt` 100 ms, combos 30/80/150 ms (see below), sticky layers 3 s. `&mt` is only used for tap/tap pairs now (COLON+COMMA, UNDER+MINUS), so it has no idle guard.

Tradeoffs:

- Same-hand chords (e.g. Ctrl+Shift on S+T) don't work; use the right-hand Shift on N.
- For games where held keys must stay letters, switch to the GAME layer instead — it strips the home row mods entirely (see [Game mode](#game-mode)).
- Deliberate chords need a short pause (~125 ms idle) before the mod key, and the mod key must stay held until the chorded key is released (the mod applies at release, not press).
- Holding a mod key and tapping an opposite-hand key always produces a chord; the 100 ms prior-idle suppresses most accidental cases mid-word.
- `hmr_uml` (UMLAUT layer on I) additionally allows U/O (positions 7/19) on the same hand, so ü/ö chords work on the right hand. The hold side no longer sends real RAlt — stock German hosts map AltGr+letter to æ/↓/ø (Linux) or nothing (Windows), never to umlauts, and a leaked RAlt gave stray `@`/`µ`. A momentary layer cannot leak either.
- The SYM and SYM_2 layers reuse `hml`/`hmr` for their home-row mods, so they get the same positional misfire protection as the base layer (they previously used plain `&mt` with no guard).
- If right-half mods don't trigger after flashing, ZMK's positional mirroring on the peripheral side may need the trigger lists adjusted (see the keymap).

## Layout: German

The firmware emits **German-layout HID usages** — every character binding uses the `DE_*` codes from `config/keys_de.h`, so a host set to a stock German layout produces the same characters in the same physical positions (Colemak letter positions unchanged; note the QWERTZ Y/Z usage swap handled by `DE_Y`/`DE_Z`).

- The header was generated with [zmk-locale-generator](https://github.com/joelspadin/zmk-locale-generator) (v1.5.0, CLDR `de-t-k0-windows`) and is committed to the repo; regenerate it (e.g. for Swiss `de-CH`) when the layout target changes. `flake.nix` includes `.h` files in its source filter, so both local nix builds and CI pick it up.
- **All paired hosts must use the German layout** (Linux XKB `de`, Windows "Deutsch", phones/tablets likewise). ZMK cannot switch output layout per host — pointing the keyboard at a US-layout host scrambles y/z and all symbols.
- Umlauts are ordinary keys: hold I and a/o/u/s become direct ä/ö/ü/ß (UMLAUT layer), and NUMPAD has direct ä/ö/ü on the physical A/O/U keys (Shift/CapsLock gives uppercase). The old host-side `ahk/umlaute.ahk` workaround (AltGr+a/o/u via AutoHotkey, with its anti-stuck-RAlt guard) is retired — no host-side tooling is needed anymore.
- Real AltGr remains only on the SYM layer (`&hmr RALT DE_LBKT`) for AltGr symbols like € µ § ² ³. The base layer never sends RAlt, so the æ/↓/ø (Linux XKB level-3) or `@`/`µ` garbage a leaked RAlt produced is impossible.
- `^` and `` ` `` are **dead keys** on a stock German layout, and firmware alone cannot fake a live char that works everywhere: dead+Space fails in apps without compose support (notably Alacritty, which drops dead-key events), and Unicode-input macros (`Ctrl+Shift+u`) leak as stray keystrokes into nvim/panes. They are therefore plain `DE_CARET`/`DE_GRAVE` keys, and the primary Hyprland host resolves the deadness away per-device: `kb_variant = "nodeadkeys"` (in `~/.config/home-manager/wm/hyprland.nix`, scoped to the ZMK keyboard) makes `^` and `` ` `` (and `~`) LIVE for this keyboard only — instant characters in every app including Alacritty. On other hosts they are dead keys as usual: press the key, then Space.

Suspend/resume the hotkeys with Win+Alt+G.

## Game mode

The GAME layer (index 7) is the base layer with every hold behavior stripped, for games where held keys must be plain letters and accidental chords/mods ruin input:

- **Home row mods off** — the home rows are plain `&kp` letters (no `hml`/`hmr`/`hmr_uml`), so any key can be held as long as the game wants without firing a modifier.
- **No layer-tap holds** — Z/DOT/RET lose their `&lt` symbol holds; long presses stay letters/Enter. The thumb `&mo` keys (SYM/FNC) remain, so arrows, F-keys and mouse emulation are still reachable.
- **Combos off** — no combo lists GAME, so chords can't misfire. Two exceptions: `to_default` (Q + top pinky) exits game mode, and `esc_game` (Q+W, same chord as `esc` but with a 150 ms idle guard) still sends Escape for menus without popping them mid-fight.

Enter it from the settings layer (`&to GAME`, the key right next to `&to BASE`), exit with the `to_default` combo or the settings layer's `&to BASE`. `&to` replaces the whole layer stack, so there is no "stuck" layer state; a reboot/power-cycle also returns to the base layer.

## Combos

Combos are positional and mostly active on layers 0-3 unless noted. Devicetree does **not** inherit properties from the `combos` node to its children, so every combo sets `timeout-ms` and `require-prior-idle-ms` explicitly via the `ZMK_COMBO_C`/`ZMK_COMBO_A` macros (an earlier version set them on the parent node and they were silently dropped, leaving all combos unguarded). Destructive combos (backspace, delete, word-delete) use a 150 ms idle guard, the rest 80 ms. Exceptions: `esc` is exempt (`0`) so it fires instantly after typing, `alt_ret` uses `30` so typing straight into the Enter combo still fires it, and `improve_prompt` uses `150` to guard against accidental macro injection.

| Combo            | Keys (layer 0)          | Output                    |
|------------------|-------------------------|---------------------------|
| esc              | Q + W                   | Escape (all layers; on GAME only after 150 ms idle) |
| cut              | X + C                   | Ctrl+X                    |
| copy             | C + D                   | Ctrl+C                    |
| paste            | D + V                   | Ctrl+V                    |
| to_default       | Q + UNDER (pinky columns) | Go to layer 0 (layers 1-5, 7) |
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
| word_backspace   | W + F                   | Ctrl+Backspace            |
| word_delete      | T + D                   | Ctrl+Delete               |

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

- **The name lives in ONE place**: `config/cradio.conf` (`CONFIG_ZMK_KEYBOARD_NAME="blackcradio"`). Both CI (`build.yaml`) and local builds (`just build`) read it — don't pass `-DCONFIG_ZMK_KEYBOARD_NAME` anywhere else.
- **Only a second physical keyboard needs an override**: add a pair of entries in `build.yaml` with `-DCONFIG_ZMK_KEYBOARD_NAME="blackcradio-<place>"` + matching `artifact-name` (and build it locally with `just build blackcradio-work`). This prevents ambiguous pairing (e.g. Windows refusing a second device with an identical name).
- Renaming does **not** reset host pairings — the BLE address stays the same, only the advertised name changes. Hosts cache the old name: remove and re-pair the keyboard (or restart Bluetooth) to see the new one.
- **Pair each keyboard's halves one at a time** (power only one pair during first bonding) so a central never bonds with the other keyboard's peripheral; afterwards the bond is sticky.

## Build

### Fast local iteration (recommended)

```bash
just build   # incremental build (both halves)
just fast    # same, but RAM-backed workspace (fast on slow disks)
just copy    # copy built firmware to both halves (left, then right)
just update  # bump ZMK to latest main + refresh deps hash
```

After building, run `just copy` (an alias for `just flash`). Connect only the
requested half over USB and double-tap its reset button when prompted. The
helper detects the `nicenano` bootloader drive, mounts it with `udisksctl` if
needed, copies that half's firmware, and waits for it to reboot before moving
to the right half. If automatic mounting is unavailable, mount the drive
manually and retry. To copy only one half, use `just copy left` or
`just copy right`. Firmware is taken from the local workspace (including the
RAM-backed workspace used by `just fast`); copying does not rebuild it.

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
