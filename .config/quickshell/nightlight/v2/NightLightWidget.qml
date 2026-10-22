import QtQuick
import Quickshell
import Quickshell.Io

// Night light bar widget for Quickshell Rise (V2 chrome).
// Left click opens the NightLightPanel (toggle + intensity slider).
// Scroll wheel nudges the temperature directly.
Item {
    id: rootMod
    required property var root

    readonly property int identityTemperature: 6000
    readonly property int nightTemperature: 4000
    readonly property int dayTemperature: 6500
    readonly property int minTemperature: 1000
    readonly property int maxTemperature: 6500
    readonly property int stepTemperature: 200

    property bool stateLoaded: false
    property int temperature: dayTemperature
    readonly property bool enabled: stateLoaded && temperature < identityTemperature

    readonly property color contentColor: root.widgetContentColor("G19", root.ink)

    readonly property string tooltipText: enabled
        ? "Night light · " + temperature + "K"
        : "Night light · off"

    implicitWidth: row.implicitWidth + 18
    implicitHeight: 28
    visible: implicitWidth > 0.5
    opacity: 1

    function refreshTemperature() {
        if (probe.running) return
        probe.running = true
    }

    function applyTemperature(t) {
        t = Math.max(minTemperature, Math.min(maxTemperature, Math.round(t)))
        temperature = t
        stateLoaded = true
        applyProc.command = ["bash", "-c",
            "pgrep -x hyprsunset >/dev/null || { setsid uwsm-app -- hyprsunset >/dev/null 2>&1 & sleep 1; }; " +
            "hyprctl hyprsunset temperature " + t]
        applyProc.running = false
        applyProc.running = true
    }

    function toggle() { applyTemperature(enabled ? dayTemperature : nightTemperature) }

    function step(delta) {
        var base = enabled ? temperature : dayTemperature
        applyTemperature(base + delta)
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 5

        UiText {
            anchors.verticalCenter: parent.verticalCenter
            text: String.fromCodePoint(0xF0594)
            renderType: Text.QtRendering
            color: rootMod.enabled
                ? root.seal
                : Qt.rgba(rootMod.contentColor.r, rootMod.contentColor.g, rootMod.contentColor.b, 0.45)
            font.family: root.mono
            font.pixelSize: 14
            Behavior on color { ColorAnimation { duration: 150 } }
        }

        UiText {
            anchors.verticalCenter: parent.verticalCenter
            visible: rootMod.enabled
            text: rootMod.temperature + "K"
            color: Qt.rgba(rootMod.contentColor.r, rootMod.contentColor.g, rootMod.contentColor.b, 0.85)
            font.family: root.mono
            font.pixelSize: 12
        }
    }

    Process {
        id: probe
        command: ["hyprctl", "hyprsunset", "temperature"]
        stdout: StdioCollector {
            onStreamFinished: {
                var m = String(this.text).match(/[0-9]+/)
                if (m) rootMod.temperature = parseInt(m[0])
                rootMod.stateLoaded = true
            }
        }
        onExited: (code) => { if (code !== 0) rootMod.stateLoaded = true }
    }

    Process {
        id: applyProc
        onExited: (code) => { rootMod.refreshTemperature() }
    }

    Timer {
        interval: 3000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: rootMod.refreshTemperature()
    }

    TooltipMixin { id: tip; root: rootMod.root; owner: rootMod; text: rootMod.tooltipText }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        onEntered: { if (rootMod.tooltipText) tip.show(); }
        onExited: { tip.hide(); }
        onClicked: (e) => {
            tip.hide();
            if (e.button === Qt.MiddleButton) rootMod.refreshTemperature();
            else root.nightlightVisible = !root.nightlightVisible;
        }
        onWheel: (e) => {
            tip.hide();
            rootMod.step((e.angleDelta.y > 0 ? 1 : -1) * rootMod.stepTemperature);
        }
    }
}
