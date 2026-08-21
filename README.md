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

The home row uses ZMK's "timeless" positional hold-taps (`hml`/`hmr`/`hmr_ralt` in `cradio.keymap`) instead of plain `&mt`:

- `balanced` flavor, `require-prior-idle-ms = <150>`, `tapping-term-ms = <280>`, `quick-tap-ms = <175>`
- Mods only trigger when the held key is combined with an opposite-hand key (`hold-trigger-key-positions` + `hold-trigger-on-release`), so same-hand rolls no longer fire mods accidentally.
- Uniform timing scheme across hold-taps and combos: HRM 150 ms, `&lt` 100 ms, `&mt` 80 ms, combos 80 ms (with exceptions below), sticky layers 3 s.

Tradeoffs:

- Same-hand chords (e.g. Ctrl+Shift on S+T) don't work; use the right-hand Shift on N.
- Deliberate chords need a short pause (~150 ms idle) before the mod key.
- `hmr_ralt` (Right Alt on I) additionally allows U/O on the same hand so AltGr+o/u (ö/ü) keep working via the AHK script.
- If right-half mods don't trigger after flashing, ZMK's positional mirroring on the peripheral side may need the trigger lists adjusted (see the keymap).

## Umlaute & AHK

Umlauts are host-side: hold Right Alt (AltGr, the I key) and tap a/o/u/s for ä/ö/ü/ß; Shift or CapsLock gives uppercase.

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

## Build

### With Nix (recommended)

```bash
nix build .#firmware        # builds both halves -> result/zmk_left.uf2, result/zmk_right.uf2
nix run .#flash             # interactive copy to the controller drives
nix run .#update            # bump ZMK to latest main + refresh the deps hash
```

The flake is based on [zmk-nix](https://github.com/lilyinstarlight/zmk-nix) and builds exactly the same sources as CI. `config/west.yml` pins ZMK `main` and the Zephyr 4.1 zmk fork to specific commits (with branch comments) so nix builds are reproducible — run `nix run .#update` to ride bleeding edge deliberately and re-lock the `zephyrDepsHash`.

### With west (manual)

```bash
west build -d build/left  -b nice_nano@2//zmk -- -DZMK_CONFIG=$PWD/config -DSHIELD=cradio_left
west build -d build/right -b nice_nano@2//zmk -- -DZMK_CONFIG=$PWD/config -DSHIELD=cradio_right
```
