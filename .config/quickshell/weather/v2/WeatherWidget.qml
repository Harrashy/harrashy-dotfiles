import QtQuick
import Quickshell
import Quickshell.Io
import "WeatherModel.js" as Model

// Weather bar widget for Quickshell Rise, matching omarchy.weather:
// honors the configured location from weather.json (omarchy-weather-location),
// uses Open-Meteo for a day/night-aware icon when coordinates are stored and
// wttr.in otherwise. Left = toggle panel, right = status notification,
// middle = refresh.
Item {
    id: rootMod
    required property var root

    property var configuredLocationState: ({ name: "", latitude: null, longitude: null })
    readonly property string locationQuery: Model.wttrLocationQuery(configuredLocationState.name, configuredLocationState.latitude, configuredLocationState.longitude)
    readonly property bool hasConfiguredCoordinates: !isNaN(parseFloat(String(configuredLocationState.latitude))) && !isNaN(parseFloat(String(configuredLocationState.longitude)))

    property var dailyForecastReport: null
    readonly property var openMeteoCurrent: Model.openMeteoCurrentCondition(dailyForecastReport)

    property string weatherIcon: ""
    property string weatherTemp: ""
    property string weatherDesc: ""
    property string weatherPlace: ""
    property bool weatherLoaded: false
    property bool weatherUnavailable: false
    property var lastAreaInfo: null
    property bool _fileLoaded: false

    readonly property color contentColor: root.widgetContentColor("G8", root.ink)

    readonly property string weatherTempStr: root.weatherImperial
        ? (Math.round((parseFloat(weatherTemp) || 0) * 9 / 5 + 32) + "°F")
        : (weatherTemp + "°C")

    readonly property string displayPlace: configuredLocationState.name !== ""
        ? configuredLocationState.name
        : weatherPlace

    readonly property string tooltipText: weatherUnavailable
        ? (weatherLoaded
            ? "Weather stale · " + (displayPlace ? displayPlace + " · " : "") + weatherTempStr + (weatherDesc ? " / " + weatherDesc : "")
            : "Weather offline")
        : (weatherLoaded
            ? (displayPlace ? displayPlace + " · " : "") + weatherTempStr + (weatherDesc ? " / " + weatherDesc : "")
            : "Weather…")

    implicitWidth: root.modWeather ? ico.implicitWidth : 0
    implicitHeight: 28

    function refresh(force) {
        if (wttrProc.running) {
            if (!force) return
            wttrProc.running = false
        }
        wttrProc.running = true
        refreshDailyForecast(null)
    }

    function refreshDailyForecast(area) {
        if (!hasConfiguredCoordinates && !area) area = lastAreaInfo
        if (dailyProc.running) return
        var lat = parseFloat(String(configuredLocationState.latitude))
        var lon = parseFloat(String(configuredLocationState.longitude))
        if (isNaN(lat) || isNaN(lon)) {
            if (!area) return
            lat = parseFloat(String(area.latitude || ""))
            lon = parseFloat(String(area.longitude || ""))
        }
        if (isNaN(lat) || isNaN(lon)) return

        var url = "https://api.open-meteo.com/v1/forecast"
            + "?latitude=" + encodeURIComponent(String(lat))
            + "&longitude=" + encodeURIComponent(String(lon))
            + "&daily=weather_code,temperature_2m_max,temperature_2m_min"
            + "&current=temperature_2m,apparent_temperature,relative_humidity_2m,wind_speed_10m,weather_code,is_day"
            + "&forecast_days=2"
            + "&timezone=auto"
        dailyProc.command = ["curl", "-fsS", "--max-time", "5", url]
        dailyProc.running = true
    }

    onLocationQueryChanged: {
        if (!rootMod._fileLoaded) return
        wttrProc.running = false
        dailyProc.running = false
        Qt.callLater(refresh)
    }

    UiText {
        id: ico
        anchors.centerIn: parent
        text: rootMod.weatherIcon !== ""
            ? rootMod.weatherIcon
            : (rootMod.weatherUnavailable ? "?" : "·")
        color: rootMod.weatherUnavailable && rootMod.weatherIcon === ""
            ? Qt.rgba(rootMod.contentColor.r, rootMod.contentColor.g, rootMod.contentColor.b, 0.4)
            : rootMod.contentColor
        font.family: root.mono
        font.pixelSize: 14
    }

    // ── data ──
    property FileView locationFile: FileView {
        path: Quickshell.env("HOME") + "/.local/state/omarchy/settings/weather.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: { rootMod.configuredLocationState = Model.parseLocationFile(text()); rootMod._fileLoaded = true }
        onLoadFailed: { rootMod.configuredLocationState = Model.parseLocationFile(""); rootMod._fileLoaded = true }
    }

    Timer {
        interval: 1500
        running: true
        onTriggered: rootMod.locationFile.reload()
    }

    Process {
        id: wttrProc
        command: ["curl", "-fs", "--max-time", "3", "https://wttr.in/" + rootMod.locationQuery + "?format=j1"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                var raw = String(this.text || "").trim()
                if (raw === "") {
                    rootMod.weatherUnavailable = true
                    return
                }
                try {
                    var parsed = JSON.parse(raw)
                    var current = parsed.current_condition && parsed.current_condition[0] ? parsed.current_condition[0] : null
                    var area = parsed.nearest_area && parsed.nearest_area[0] ? parsed.nearest_area[0] : null
                    if (!current) {
                        rootMod.weatherUnavailable = true
                        return
                    }
                    rootMod.lastAreaInfo = area
                    rootMod.weatherIcon = Model.provisionalCurrentIcon(current, rootMod.weatherIcon)
                    rootMod.weatherTemp = current.temp_C || ""
                    rootMod.weatherDesc = current.weatherDesc && current.weatherDesc[0] ? (current.weatherDesc[0].value || "") : ""
                    rootMod.weatherPlace = area && area.areaName && area.areaName[0] ? (area.areaName[0].value || "") : ""
                    rootMod.weatherLoaded = true
                    rootMod.weatherUnavailable = false
                    if (!rootMod.hasConfiguredCoordinates) rootMod.refreshDailyForecast(area)
                } catch (e) {
                    rootMod.weatherUnavailable = true
                }
            }
        }
    }

    Process {
        id: dailyProc
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                var raw = String(this.text || "").trim()
                if (raw === "") return
                try {
                    var parsed = JSON.parse(raw)
                    var parsedCurrent = Model.openMeteoCurrentCondition(parsed)
                    rootMod.dailyForecastReport = parsed
                    rootMod.weatherIcon = Model.currentIcon(parsedCurrent, rootMod.weatherIcon)
                } catch (e) {
                    // keep the last valid icon
                }
            }
        }
    }

    Timer {
        interval: 15 * 60 * 1000
        running: root.modWeather && rootMod._fileLoaded
        repeat: true
        triggeredOnStart: true
        onTriggered: rootMod.refresh(false)
    }

    Process {
        id: rightNotifyProc
        command: ["bash", "-c",
            "if command -v omarchy-notification-send >/dev/null 2>&1; then omarchy-notification-send \"$(omarchy-weather-status)\"; " +
            "else notify-send -u low \"$(omarchy-weather-status)\" 2>/dev/null || true; fi"]
    }

    TooltipMixin { id: tip; root: rootMod.root; owner: rootMod; text: rootMod.tooltipText }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onEntered: { if (rootMod.tooltipText) tip.show(); }
        onExited: { tip.hide(); }
        onClicked: (e) => {
            tip.hide();
            if (e.button === Qt.RightButton) {
                rightNotifyProc.running = false;
                rightNotifyProc.running = true;
            } else if (e.button === Qt.MiddleButton) {
                rootMod.refresh(true);
            } else {
                root.weatherVisible = !root.weatherVisible;
            }
        }
    }
}