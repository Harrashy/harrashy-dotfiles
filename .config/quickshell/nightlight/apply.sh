#!/usr/bin/env bash
# Re-apply the night light widget/panel to the Quickshell Rise bar (V1 and V2).
#
# Quickshell Rise's updater (qs-shell-apply-update.sh) replaces the whole
# ~/.config/quickshell/bar directory on every update, so edits made directly in
# the bar tree are wiped. This script keeps the widget/panel sources here and
# re-injects them (idempotently) into the bar tree. It is safe to run any number
# of times, and it is wired to a systemd path unit that fires after updates.
set -u

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="${QSRISE_BAR_DIR:-$HOME/.config/quickshell/bar}"
LOG="${QSRISE_NIGHTLIGHT_LOG:-$HOME/.local/state/quickshell-rise/nightlight-apply.log}"
mkdir -p "$(dirname "$LOG")"

log() { printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >>"$LOG"; }

if [ "${1:-}" = "--delay" ]; then sleep "${2:-2}"; fi

if [ ! -f "$DEST/shell.qml" ]; then
    log "bar tree not found at $DEST (skipping)"
    exit 0
fi

mkdir -p "$DEST/modules" "$DEST/panels"
sync_file() {
    local src="$1" dst="$2"
    if [ -f "$dst" ] && cmp -s "$src" "$dst"; then
        return 0
    fi
    cp -f "$src" "$dst"
}
sync_file "$SRC_DIR/NightLightWidget.qml" "$DEST/modules/NightLightWidget.qml"
sync_file "$SRC_DIR/NightLightPanel.qml"  "$DEST/panels/NightLightPanel.qml"

# ── V2 variant lives under its own tree with its own chrome ──
V2_DIR="$DEST/variants/V2"
V2_READY=0
if [ -d "$V2_DIR/modules" ] && [ -d "$V2_DIR/panels" ] && [ -f "$V2_DIR/BarSlot.qml" ]; then
    V2_READY=1
    sync_file "$SRC_DIR/v2/NightLightWidget.qml" "$V2_DIR/modules/NightLightWidget.qml"
    sync_file "$SRC_DIR/v2/NightLightPanel.qml"  "$V2_DIR/panels/NightLightPanel.qml"
fi

python3 - "$DEST" "$V2_READY" <<'PY'
import sys, io, os

dest = sys.argv[1]
v2_ready = sys.argv[2] == "1"

def patch(rel, guard, replacements, label):
    path = os.path.join(dest, rel)
    try:
        with io.open(path, "r", encoding="utf-8") as f:
            text = f.read()
    except FileNotFoundError:
        print(f"  ! {label}: missing {rel}")
        return False
    if guard in text:
        print(f"  = {label}: already applied")
        return True
    updated = text
    for old, new in replacements:
        if old not in updated:
            print(f"  ! {label}: anchor not found in {rel}: {old.strip()!r}")
            return False
        updated = updated.replace(old, new, 1)
    with io.open(path, "w", encoding="utf-8") as f:
        f.write(updated)
    print(f"  + {label}: patched {rel}")
    return True

ok = True

# ── V1 tree ──
ok &= patch("BarSlot.qml", "compNightLight", [
    (
        '    Component { id: compBluetooth;  BluetoothWidget    { root: barSlot.root } }\n',
        '    Component { id: compBluetooth;  BluetoothWidget    { root: barSlot.root } }\n'
        '    // QSR-NIGHTLIGHT-BEGIN\n'
        '    Component { id: compNightLight; NightLightWidget { root: barSlot.root } }\n'
        '    // QSR-NIGHTLIGHT-END\n',
    ),
    (
        '        "G12": compBattery, "G13": compBrightness, "G14": compPower, "G15": compBluetooth\n',
        '        "G12": compBattery, "G13": compBrightness, "G14": compPower, "G15": compBluetooth,\n'
        '        "G16": compNightLight\n',
    ),
    (
        '            ListElement { gid: "G15" }\n',
        '            ListElement { gid: "G15" } ListElement { gid: "G16" }\n',
    ),
    (
        '                brightness:   island.groupX("G13", 0.5),\n',
        '                brightness:   island.groupX("G13", 0.5),\n'
        '                nightlight:   island.groupX("G16", 0.5),\n',
    ),
    (
        '        var dR = ["G9","G10","G11","G14","G12","G13","G15"]\n',
        '        var dR = ["G9","G10","G11","G14","G12","G13","G15","G16"]\n',
    ),
], "V1 BarSlot")

ok &= patch("Theme.qml", "nightlightVisible", [
    (
        '        else if (name === "brightness") brightnessBarX = x\n',
        '        else if (name === "brightness") brightnessBarX = x\n'
        '        else if (name === "nightlight") nightlightBarX = x\n',
    ),
    (
        '        if (except !== "brightnessVisible") brightnessVisible = false\n',
        '        if (except !== "brightnessVisible") brightnessVisible = false\n'
        '        if (except !== "nightlightVisible") nightlightVisible = false\n',
    ),
    (
        '    onBrightnessVisibleChanged: popupOpened("brightnessVisible")\n',
        '    onBrightnessVisibleChanged: popupOpened("brightnessVisible")\n'
        '    property bool nightlightVisible: false\n'
        '    onNightlightVisibleChanged: popupOpened("nightlightVisible")\n',
    ),
    (
        '    property real brightnessBarX: 0\n',
        '    property real brightnessBarX: 0\n'
        '    property real nightlightBarX:   0\n',
    ),
], "V1 Theme")

ok &= patch("VariantRoot.qml", "NightLightPanel", [
    (
        '    BrightnessPanel { root: theme }\n',
        '    BrightnessPanel { root: theme }\n'
        '    NightLightPanel { root: theme }\n',
    ),
], "V1 VariantRoot")

# ── V2 tree ──
if v2_ready:
    ok &= patch("variants/V2/BarSlot.qml", "compNightLight", [
        (
            '    readonly property var registry: ({\n',
            '    Component {\n'
            '        id: compNightLight\n'
            '        NightLightWidget {\n'
            '            root: barSlot.root\n'
            '            readonly property real barContentLeftInset: 9\n'
            '            readonly property real barContentRightInset: 9\n'
            '        }\n'
            '    }\n'
            '\n'
            '    readonly property var registry: ({\n',
        ),
        (
            '        "G16": compCpuTemperature, "G17": compGpu, "G18": compStorage\n',
            '        "G16": compCpuTemperature, "G17": compGpu, "G18": compStorage,\n'
            '        "G19": compNightLight\n',
        ),
        (
            'ListElement { gid: "G15"; extra: true }  ListElement { gid: ""; extra: true }',
            'ListElement { gid: "G15"; extra: true }  ListElement { gid: "G19"; extra: true }',
        ),
        (
            '        var dR = ["G9","G10","G11","G14","G12","G13","G16",\n'
            '                  "G18","G17","G15","","",""]\n',
            '        var dR = ["G9","G10","G11","G14","G12","G13","G16",\n'
            '                  "G18","G17","G15","G19","",""]\n',
        ),
        (
            '                brightness:   island.groupX("G13", 0.5),\n',
            '                brightness:   island.groupX("G13", 0.5),\n'
            '                nightlight:   island.groupX("G19", 0.5),\n',
        ),
    ], "V2 BarSlot")

    ok &= patch("variants/V2/Theme.qml", "nightlightVisible", [
        (
            '        else if (name === "trayMenu") trayMenuX = x\n',
            '        else if (name === "trayMenu") trayMenuX = x\n'
            '        else if (name === "nightlight") nightlightBarX = x\n',
        ),
        (
            '        if (except !== "weatherVisible") weatherVisible = false\n',
            '        if (except !== "weatherVisible") weatherVisible = false\n'
            '        if (except !== "nightlightVisible") nightlightVisible = false\n',
        ),
        (
            '    property bool weatherVisible:   false\n'
            '    onWeatherVisibleChanged: popupOpened("weatherVisible")\n',
            '    property bool weatherVisible:   false\n'
            '    onWeatherVisibleChanged: popupOpened("weatherVisible")\n'
            '    property bool nightlightVisible: false\n'
            '    onNightlightVisibleChanged: popupOpened("nightlightVisible")\n',
        ),
        (
            '    property real weatherBarX:    0\n',
            '    property real weatherBarX:    0\n'
            '    property real nightlightBarX:  0\n',
        ),
    ], "V2 Theme")

    ok &= patch("variants/V2/VariantRoot.qml", "NightLightPanel", [
        (
            '    WeatherPanel { root: theme }\n',
            '    WeatherPanel { root: theme }\n'
            '    NightLightPanel { root: theme }\n',
        ),
    ], "V2 VariantRoot")

sys.exit(0 if ok else 1)
PY
rc=$?

if [ $rc -eq 0 ]; then
    log "night light widget applied to $DEST"
else
    log "ERROR: night light widget patch failed (see log)"
fi
exit $rc
