#Requires AutoHotkey v2.0
; Umlaute und ß mit Right Alt (AltGr) + a/o/u/s.
; Großbuchstaben, wenn Shift oder CapsLock aktiv (XOR-Logik).
;
; Anti-Stuck-Schutz: ZMK Home-Row-Mods können gelegentlich einen
; AltGr-Key-Up an das OS verlieren (Modifier bleibt logisch gedrückt).
; Nach jedem Hotkey wird AltGr daher im OS gelöst, falls die Taste
; physikalisch nicht (mehr) gedrückt ist.

EnableLeftAlt := false ; true -> auch mit linker Alt-Taste aktivieren
UseCapitalSharpS := true ; false -> statt ẞ "SS" senden

sendCase(lower, upper) {
    shift := GetKeyState("Shift", "P")
    caps := GetKeyState("CapsLock", "T")
    SendText (shift ^ caps) ? upper : lower
}

releaseStuckAlt() {
    if !GetKeyState("RAlt", "P")
        Send "{Blind}{RAlt up}"
}

; Right Alt (AltGr) + Taste. Explizite >!- bzw. >!+-Varianten statt des
; *-Wildcards, damit versehentliche Ctrl/Win-Kombinationen der
; Home-Row-Mods nicht auslösen.
>!a:: { sendCase("ä", "Ä"), releaseStuckAlt() }
>!+a:: { sendCase("ä", "Ä"), releaseStuckAlt() }
>!o:: { sendCase("ö", "Ö"), releaseStuckAlt() }
>!+o:: { sendCase("ö", "Ö"), releaseStuckAlt() }
>!u:: { sendCase("ü", "Ü"), releaseStuckAlt() }
>!+u:: { sendCase("ü", "Ü"), releaseStuckAlt() }
>!s:: { sendCase("ß", UseCapitalSharpS ? "ẞ" : "SS"), releaseStuckAlt() }
>!+s:: { sendCase("ß", UseCapitalSharpS ? "ẞ" : "SS"), releaseStuckAlt() }

; Optional: Linke Alt-Kombinationen (kann mit Menü-Shortcuts kollidieren)
#HotIf EnableLeftAlt
<!a::sendCase("ä", "Ä")
<!+a::sendCase("ä", "Ä")
<!o::sendCase("ö", "Ö")
<!+o::sendCase("ö", "Ö")
<!u::sendCase("ü", "Ü")
<!+u::sendCase("ü", "Ü")
<!s::sendCase("ß", UseCapitalSharpS ? "ẞ" : "SS")
<!+s::sendCase("ß", UseCapitalSharpS ? "ẞ" : "SS")
#HotIf

; Hotkeys schnell an/aus: Win+Alt+G
#!g::Suspend(-1)
