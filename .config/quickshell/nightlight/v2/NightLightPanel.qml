import QtQuick
import "../modules"
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Night light popup for Quickshell Rise (V2 chrome): on/off toggle + temperature
// slider. Opened by NightLightWidget through root.nightlightVisible, anchored
// under the widget via root.nightlightBarX.
PanelWindow {
    id: nlPanel
    required property var root

    screen: root.activePopupScreen
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "omarchy-nightlight"

    readonly property int barBottom: root.v2BarHeight
    readonly property int gap: 6

    readonly property int identityTemperature: 6000
    readonly property int nightTemperature: 4000
    readonly property int dayTemperature: 6500
    readonly property int minTemperature: 1000
    readonly property int maxTemperature: 6500
    readonly property int stepTemperature: 200

    property int temperature: dayTemperature
    property bool stateLoaded: false
    readonly property bool enabled: stateLoaded && temperature < identityTemperature

    property int queuedTemperature: -1

    property real reveal: root.nightlightVisible ? 1 : 0
    Behavior on reveal {
        NumberAnimation {
            duration: root.nightlightVisible ? 160 : 120
            easing.type: root.nightlightVisible ? Easing.OutCubic : Easing.InCubic
        }
    }
    visible: reveal > 0.001
    WlrLayershell.keyboardFocus: root.nightlightVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    MouseArea { anchors.fill: parent; onClicked: root.nightlightVisible = false }

    function refresh() { probe.running = false; probe.running = true }

    function requestTemperature(t) {
        t = Math.max(minTemperature, Math.min(maxTemperature, Math.round(t)))
        queuedTemperature = t
        temperature = t
        stateLoaded = true
        setDebounce.restart()
    }

    function toggle() { requestTemperature(enabled ? dayTemperature : nightTemperature) }

    function step(delta) {
        var base = enabled ? temperature : dayTemperature
        requestTemperature(base + delta)
    }

    function drainQueue() {
        if (setRunner.running || queuedTemperature < 0) return
        var t = queuedTemperature
        queuedTemperature = -1
        setRunner.command = ["bash", "-c",
            "pgrep -x hyprsunset >/dev/null || { setsid uwsm-app -- hyprsunset >/dev/null 2>&1 & sleep 1; }; " +
            "hyprctl hyprsunset temperature " + t]
        setRunner.running = true
    }

    Rectangle {
        id: card
        width: 300
        height: col.implicitHeight + 24
        radius: reveal > 0.001 ? root.panelRadius : 0
        color: "transparent"
        border.color: root.panelBorder
        border.width: 0
        PillShadow { theme: root }
        ConnectedPanelSurface {
            root: nlPanel.root
            ownerActive: nlPanel.root.nightlightVisible
            targetX: nlPanel.root.nightlightBarX
            reveal: nlPanel.reveal
        }

        x: Math.round(Math.max(6, Math.min(root.nightlightBarX - width / 2, parent.width - width - 6)))
        y: root.barPosition === "bottom"
            ? (parent.height - barBottom - gap - height) + 2 * (1 - nlPanel.reveal)
            : (barBottom + gap) - 2 * (1 - nlPanel.reveal)
        opacity: nlPanel.reveal
        focus: root.nightlightVisible

        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) { root.nightlightVisible = false; event.accepted = true }
        }

        MouseArea { anchors.fill: parent; onClicked: {} }

        Column {
            id: col
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            Item {
                width: parent.width
                height: 24
                UiText {
                    anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                    text: "Night Light"
                    color: root.ink; font.family: root.mono; font.pixelSize: 13
                    font.letterSpacing: 2; font.weight: Font.Medium
                }
                UiText {
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    text: "✕"; color: closeMa.containsMouse ? root.seal : root.sumi; font.pixelSize: 12
                    Behavior on color { ColorAnimation { duration: 120 } }
                    MouseArea { id: closeMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.nightlightVisible = false }
                }
            }

            Rectangle { width: parent.width; height: 1; color: root.sep }

            Rectangle {
                id: toggleBtn
                width: parent.width; height: 30; radius: root.panelButtonRadius
                color: _tg.containsMouse ? root.fillHover : root.fillIdle
                border.color: _tg.containsMouse ? root.seal : root.sep
                border.width: 1
                Behavior on color { ColorAnimation { duration: 120 } }
                UiText {
                    anchors.centerIn: parent
                    text: nlPanel.enabled ? "Turn Off" : "Turn On"
                    color: nlPanel.enabled ? root.seal : root.sumi
                    font.family: root.mono; font.pixelSize: 12; font.weight: Font.Medium
                }
                MouseArea {
                    id: _tg
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: nlPanel.toggle()
                }
            }

            Item {
                width: parent.width
                height: 30
                UiText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    text: nlPanel.enabled ? (Math.round(nlPanel.temperature) + " K") : "Off"
                    color: root.seal
                    font.family: root.mono; font.pixelSize: 11; font.weight: Font.Medium
                }
                Rectangle {
                    id: track
                    anchors.bottom: parent.bottom
                    width: parent.width; height: 8; radius: 4
                    color: root.fillActive
                    readonly property real ratio: nlPanel.enabled
                        ? (nlPanel.temperature - nlPanel.minTemperature) / (nlPanel.maxTemperature - nlPanel.minTemperature)
                        : 0
                    Rectangle {
                        width: track.width * Math.max(0, Math.min(1, track.ratio))
                        height: parent.height; radius: 4; color: root.seal
                        Behavior on width { NumberAnimation { duration: 120 } }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onPressed: (e) => setFromX(e.x)
                        onPositionChanged: (e) => { if (pressed) setFromX(e.x) }
                        function setFromX(px) {
                            var ratio = Math.max(0, Math.min(1, px / track.width))
                            nlPanel.requestTemperature(nlPanel.minTemperature
                                + ratio * (nlPanel.maxTemperature - nlPanel.minTemperature))
                        }
                    }
                }
            }

            Item {
                width: parent.width
                height: 12
                UiText {
                    anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                    text: "Warm"
                    color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.5)
                    font.family: root.mono; font.pixelSize: 10
                }
                UiText {
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    text: "Cool"
                    color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.5)
                    font.family: root.mono; font.pixelSize: 10
                }
            }

            Rectangle { width: parent.width; height: 1; color: root.sep }

            Row {
                width: parent.width
                spacing: 8
                Rectangle {
                    id: btnWarm
                    width: root.evenW((parent.width - 8) / 2); height: 28; radius: root.panelButtonRadius
                    color: _wm.containsMouse ? root.fillHover : root.fillIdle
                    border.color: _wm.containsMouse ? root.seal : root.sep
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 120 } }
                    UiText {
                        anchors.centerIn: parent
                        text: "Warmer"
                        color: _wm.containsMouse ? root.seal : root.sumi
                        font.family: root.mono; font.pixelSize: 11
                    }
                    MouseArea {
                        id: _wm
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor; hoverEnabled: true
                        onClicked: nlPanel.step(-nlPanel.stepTemperature)
                    }
                }
                Rectangle {
                    id: btnCool
                    width: root.evenW((parent.width - 8) / 2); height: 28; radius: root.panelButtonRadius
                    color: _cl.containsMouse ? root.fillHover : root.fillIdle
                    border.color: _cl.containsMouse ? root.seal : root.sep
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 120 } }
                    UiText {
                        anchors.centerIn: parent
                        text: "Cooler"
                        color: _cl.containsMouse ? root.seal : root.sumi
                        font.family: root.mono; font.pixelSize: 11
                    }
                    MouseArea {
                        id: _cl
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor; hoverEnabled: true
                        onClicked: nlPanel.step(nlPanel.stepTemperature)
                    }
                }
            }
        }
    }

    Timer {
        id: setDebounce
        interval: 90
        repeat: false
        onTriggered: nlPanel.drainQueue()
    }

    Process {
        id: probe
        command: ["hyprctl", "hyprsunset", "temperature"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var m = String(this.text).match(/[0-9]+/)
                if (m) nlPanel.temperature = parseInt(m[0])
                nlPanel.stateLoaded = true
            }
        }
        onExited: (code) => { if (code !== 0) nlPanel.stateLoaded = true }
    }

    Process {
        id: setRunner
        command: ["bash", "-c", "true"]
        onExited: (code) => {
            if (nlPanel.queuedTemperature >= 0) nlPanel.drainQueue()
            else nlPanel.refresh()
        }
    }

    onVisibleChanged: { if (visible) refresh() }
}
