import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../modules"
import "WeatherModel.js" as Model

// Weather detail popup for Quickshell Rise, matching the behavior of the
// omarchy.weather plugin: configured-location support (via the shared
// weather.json state / omarchy-weather-location), Open-Meteo as the primary
// source when coordinates are stored (faster, day/night-aware icons) and
// wttr.in as a fallback, plus click-to-edit geocoded location search, a 3-day
// forecast, and Rise unit handling.
PanelWindow {
    id: wxPanel
    required property var root

    screen: root.activePopupScreen
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "omarchy-weather"

    readonly property int barBottom: root.v2BarHeight
    readonly property int gap: 6
    readonly property int refreshMinutes: 15

    // ── Parsed reports. Kept on failure so stale data stays visible. ──
    property var report: null
    property var dailyForecastReport: null
    property string wttrLocation: ""

    // ── Configured location, from weather.json (owned by omarchy-weather-location).
    //    The query is the wttr.in path segment (coordinates when stored, else the
    //    encoded name); empty means IP auto-detect. FileView live-updates hand edits.
    property var configuredLocationState: ({ name: "", latitude: null, longitude: null })
    readonly property string configuredLocation: configuredLocationState.name
    readonly property string locationQuery: Model.wttrLocationQuery(configuredLocationState.name, configuredLocationState.latitude, configuredLocationState.longitude)
    readonly property bool hasConfiguredCoordinates: !isNaN(parseFloat(String(configuredLocationState.latitude))) && !isNaN(parseFloat(String(configuredLocationState.longitude)))

    property int forecastRetries: 0
    property int dailyForecastRetries: 0

    // ── Click-to-edit location state ──
    property bool editingLocation: false
    property bool savingLocation: false
    property bool savingLocationQueryStarted: false
    property var locationSuggestions: []
    property int suggestionIndex: 0
    property string geocodePendingQuery: ""
    property string geocodeActiveQuery: ""

    // ── Shared hero/bar icon state ──
    property string label: ""

    readonly property var openMeteoCurrent: Model.openMeteoCurrentCondition(dailyForecastReport)
    readonly property var current: (hasConfiguredCoordinates && openMeteoCurrent)
        ? openMeteoCurrent
        : ((report && report.current_condition && report.current_condition[0]) ? report.current_condition[0] : openMeteoCurrent)
    readonly property var areaInfo: report && report.nearest_area && report.nearest_area[0] ? report.nearest_area[0] : null
    readonly property var forecastDays: buildForecastDays()
    readonly property string reportCountry: areaInfo && areaInfo.country && areaInfo.country[0] ? areaInfo.country[0].value : ""
    readonly property bool useImperial: root.weatherImperial

    readonly property string reportLocation: configuredLocation || wttrLocation || (areaInfo && areaInfo.areaName && areaInfo.areaName[0] ? areaInfo.areaName[0].value : "")
    readonly property string reportTempNum: current ? String(useImperial ? current.temp_F : current.temp_C) : ""
    readonly property string tempUnit: "°" + (useImperial ? "F" : "C")
    readonly property string reportFeels: current ? Model.formatTemp(useImperial ? current.FeelsLikeF : current.FeelsLikeC) : ""
    readonly property string reportWind: current ? (useImperial ? (current.windspeedMiles + " mph") : (current.windspeedKmph + " km/h")) : ""
    readonly property string reportHumidity: current ? (current.humidity + "%") : ""

    // Keep the previous report visible while a new location loads; reset the
    // retry budgets so a hand edit is never starved.
    onLocationQueryChanged: {
        if (savingLocation) savingLocationQueryStarted = true
        forecastRetries = 0
        dailyForecastRetries = 0
        forecastProc.running = false
        dailyForecastProc.running = false
        if (root.weatherVisible) Qt.callLater(refresh)
    }

    function refresh() {
        // Each full refresh cycle gets a fresh retry budget, so an earlier
        // exhausted round (e.g. waking with the network still down) doesn't
        // starve retries for the rest of the session.
        forecastRetries = 0
        dailyForecastRetries = 0
        if (!forecastProc.running) forecastProc.running = true
        if (locationQuery === "" && !locationProc.running) locationProc.running = true
        refreshDailyForecast(null)
    }

    function refreshDailyForecast(sourceReport) {
        if (dailyForecastProc.running) return
        var lat = parseFloat(String(configuredLocationState.latitude))
        var lon = parseFloat(String(configuredLocationState.longitude))
        if (isNaN(lat) || isNaN(lon)) {
            var area = sourceReport && sourceReport.nearest_area && sourceReport.nearest_area[0]
                ? sourceReport.nearest_area[0]
                : areaInfo
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
            + "&forecast_days=4"
            + "&timezone=auto"
        dailyForecastProc.command = ["curl", "-fsS", "--max-time", "5", url]
        dailyForecastProc.running = true
    }

    // ── Location editing ──
    function startEditingLocation() {
        editingLocation = true
        savingLocation = false
        savingLocationQueryStarted = false
        locationSuggestions = []
        suggestionIndex = 0
        Qt.callLater(function() {
            locationField.text = configuredLocation
            locationField.selectAll()
            locationField.forceActiveFocus()
        })
    }

    function cancelEditingLocation() {
        editingLocation = false
        savingLocation = false
        savingLocationQueryStarted = false
        locationSuggestions = []
        geocodeDebounce.stop()
    }

    function commitLocation() {
        var location = Model.locationCommit(locationField.text, locationSuggestions, suggestionIndex)
        if (location.name === "") { clearLocation(); return }
        savingLocation = true
        savingLocationQueryStarted = false
        configuredLocationState = {
            name: location.name,
            latitude: location.latitude,
            longitude: location.longitude
        }
        persistLocation(location.name, location.latitude, location.longitude)
    }

    function clearLocation() {
        persistLocation("", null, null)
        wttrLocation = ""
        cancelEditingLocation()
    }

    function pickSuggestion(suggestion) {
        if (!suggestion) return
        savingLocation = true
        savingLocationQueryStarted = false
        configuredLocationState = {
            name: suggestion.name,
            latitude: suggestion.latitude,
            longitude: suggestion.longitude
        }
        persistLocation(suggestion.name, suggestion.latitude, suggestion.longitude)
    }

    function finishSavingLocation() {
        if (savingLocation && savingLocationQueryStarted) cancelEditingLocation()
    }

    function persistLocation(name, latitude, longitude) {
        if (name && latitude !== null && longitude !== null)
            locationSaveProc.command = ["omarchy-weather-location", "--set", name, latitude + "," + longitude]
        else if (name)
            locationSaveProc.command = ["omarchy-weather-location", "--set", name]
        else
            locationSaveProc.command = ["omarchy-weather-location", "--clear"]
        locationSaveProc.running = true
    }

    function requestGeocode() {
        var query = locationField.text.trim()
        if (query.length < 2) {
            locationSuggestions = []
            return
        }
        geocodePendingQuery = query
        if (!geocodeProc.running) startGeocode()
    }

    function startGeocode() {
        geocodeActiveQuery = geocodePendingQuery
        geocodeProc.command = ["curl", "-fsS", "--max-time", "5",
            "https://geocoding-api.open-meteo.com/v1/search?name=" + encodeURIComponent(geocodeActiveQuery) + "&count=5&language=en&format=json"]
        geocodeProc.running = true
    }

    function scheduleForecastRetry() {
        if (forecastRetries >= 3) return
        forecastRetries++
        forecastRetryTimer.restart()
    }

    function scheduleDailyForecastRetry() {
        if (dailyForecastRetries >= 3) return
        dailyForecastRetries++
        dailyForecastRetryTimer.restart()
    }

    function buildForecastDays() {
        return Model.buildForecastDays(report, dailyForecastReport, Qt.formatDate(new Date(), "yyyy-MM-dd"))
    }

    function dayName(dateString) {
        return Model.dayName(dateString, function(date) { return Qt.formatDate(date, "dddd") })
    }

    function bareTempForDay(day, kind) {
        return Model.bareTempForDay(day, kind, useImperial)
    }

    function dayIcon(day) {
        return Model.dayIcon(day)
    }

    // ───────────────────────── UI ─────────────────────────
    property real reveal: root.weatherVisible ? 1 : 0
    Behavior on reveal {
        NumberAnimation {
            duration: root.weatherVisible ? 160 : 120
            easing.type: root.weatherVisible ? Easing.OutCubic : Easing.InCubic
        }
    }
    visible: reveal > 0.001
    WlrLayershell.keyboardFocus: root.weatherVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    MouseArea { anchors.fill: parent; onClicked: root.weatherVisible = false }

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
            root: wxPanel.root
            ownerActive: wxPanel.root.weatherVisible
            targetX: wxPanel.root.weatherBarX
            reveal: wxPanel.reveal
        }

        x: Math.round(Math.max(6, Math.min(root.weatherBarX - width / 2, parent.width - width - 6)))
        y: root.barPosition === "bottom"
            ? (parent.height - barBottom - gap - height) + 2 * (1 - wxPanel.reveal)
            : (barBottom + gap) - 2 * (1 - wxPanel.reveal)
        opacity: wxPanel.reveal
        focus: root.weatherVisible

        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) { root.weatherVisible = false; event.accepted = true }
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
                    text: "Weather"
                    color: root.ink; font.family: root.mono; font.pixelSize: 13
                    font.letterSpacing: 2; font.weight: Font.Medium
                }
                UiText {
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    text: "✕"; color: closeMa.containsMouse ? root.seal : root.sumi; font.pixelSize: 12
                    Behavior on color { ColorAnimation { duration: 120 } }
                    MouseArea { id: closeMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.weatherVisible = false }
                }
            }

            Rectangle { width: parent.width; height: 1; color: root.sep }

            // ── Hero: big icon + temperature ──
            Row {
                width: parent.width
                spacing: 14
                UiText {
                    width: 62
                    height: 56
                    text: wxPanel.label || "—"
                    color: root.ink
                    font.family: root.mono
                    font.pixelSize: 46
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    UiText {
                        text: wxPanel.reportTempNum || "—"
                        color: root.seal
                        font.family: root.mono
                        font.pixelSize: 40
                        font.weight: Font.Medium
                    }
                    UiText {
                        anchors.top: parent.top
                        anchors.topMargin: 6
                        text: wxPanel.current ? wxPanel.tempUnit : ""
                        color: root.sumiHi
                        font.family: root.mono
                        font.pixelSize: 14
                    }
                }
            }

            // ── Location (click to edit) / editor ──
            Item {
                width: parent.width
                height: 26
                visible: !wxPanel.editingLocation
                UiText {
                    anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                    text: "\uF041"
                    color: root.sumi
                    font.family: root.mono
                    font.pixelSize: 12
                }
                UiText {
                    anchors.left: parent.left; anchors.leftMargin: 20; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    text: (wxPanel.reportLocation || "").toUpperCase()
                    color: root.sumi
                    font.family: root.mono; font.pixelSize: 11; font.letterSpacing: 1
                    elide: Text.ElideRight
                }
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: wxPanel.startEditingLocation()
                }
            }

            Row {
                width: parent.width
                visible: wxPanel.editingLocation
                spacing: 6
                Rectangle {
                    id: fieldBox
                    width: parent.width - 32
                    height: 26
                    radius: root.tileRadius
                    color: root.fillIdle
                    border.color: locationField.activeFocus ? root.seal : root.sep
                    border.width: 1
                    Behavior on border.color { ColorAnimation { duration: 120 } }
                    TextInput {
                        id: locationField
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        verticalAlignment: TextInput.AlignVCenter
                        color: root.ink
                        font.family: root.mono
                        font.pixelSize: 12
                        clip: true
                        selectByMouse: true
                        enabled: !wxPanel.savingLocation
                        onTextChanged: if (wxPanel.editingLocation && !wxPanel.savingLocation) geocodeDebounce.restart()
                        Keys.onPressed: function(event) {
                            if (event.key === Qt.Key_Escape) {
                                wxPanel.cancelEditingLocation(); event.accepted = true
                            } else if (event.key === Qt.Key_Down) {
                                if (wxPanel.suggestionIndex < wxPanel.locationSuggestions.length - 1) wxPanel.suggestionIndex++
                                event.accepted = true
                            } else if (event.key === Qt.Key_Up) {
                                if (wxPanel.suggestionIndex > 0) wxPanel.suggestionIndex--
                                event.accepted = true
                            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                wxPanel.commitLocation(); event.accepted = true
                            }
                        }
                    }
                }
                Rectangle {
                    width: 26
                    height: 26
                    radius: root.tileRadius
                    color: clearMa.containsMouse && !wxPanel.savingLocation ? root.fillHover : (wxPanel.savingLocation ? "transparent" : root.fillIdle)
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Text {
                        anchors.centerIn: parent
                        text: wxPanel.savingLocation ? "\uF0996" : "✕"
                        color: root.sumi
                        font.family: root.mono
                        font.pixelSize: 12
                        RotationAnimator on rotation {
                            running: wxPanel.savingLocation
                            from: 0; to: 360
                            duration: 800
                            loops: Animation.Infinite
                        }
                    }
                    MouseArea {
                        id: clearMa
                        anchors.fill: parent
                        enabled: !wxPanel.savingLocation
                        hoverEnabled: true
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: wxPanel.clearLocation()
                    }
                }
            }

            // ── Geocoding suggestions ──
            Column {
                visible: wxPanel.editingLocation && !wxPanel.savingLocation && wxPanel.locationSuggestions.length > 0
                width: parent.width
                spacing: 2
                Repeater {
                    model: wxPanel.locationSuggestions
                    Rectangle {
                        required property var modelData
                        required property int index
                        width: parent.width
                        height: 30
                        radius: root.tileRadius
                        color: index === wxPanel.suggestionIndex ? root.fillHover : "transparent"
                        Behavior on color { ColorAnimation { duration: 80 } }
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onPositionChanged: wxPanel.suggestionIndex = index
                            onClicked: wxPanel.pickSuggestion(modelData)
                        }
                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 8
                            UiText {
                                text: modelData.name
                                color: index === wxPanel.suggestionIndex ? root.seal : root.ink
                                font.family: root.mono; font.pixelSize: 12
                            }
                            UiText {
                                text: modelData.description
                                visible: modelData.description !== ""
                                color: root.sumi
                                font.family: root.mono; font.pixelSize: 10
                            }
                        }
                    }
                }
            }

            // ── Stats ──
            Row {
                width: parent.width
                spacing: 20
                visible: !!wxPanel.current
                Repeater {
                    model: [
                        { label: "FEELS", value: wxPanel.reportFeels },
                        { label: "WIND", value: wxPanel.reportWind },
                        { label: "HUMID", value: wxPanel.reportHumidity }
                    ]
                    Column {
                        required property var modelData
                        width: root.evenW((wxPanel.current ? parent.width - 40 : 0) / 3)
                        spacing: 2
                        UiText {
                            text: modelData.label
                            color: root.sumiHi
                            font.family: root.mono; font.pixelSize: 9; font.letterSpacing: 1
                        }
                        UiText {
                            text: modelData.value
                            color: root.ink
                            font.family: root.mono; font.pixelSize: 12
                        }
                    }
                }
            }

            UiText {
                visible: !wxPanel.current
                text: "Fetching forecast…"
                color: root.sumi
                font.family: root.mono; font.pixelSize: 11
                font.italic: true
            }

            Rectangle {
                visible: wxPanel.forecastDays.length > 0
                width: parent.width; height: 1; color: root.sep
            }

            // ── Forecast: day icon + name + hi/lo ──
            Row {
                visible: wxPanel.forecastDays.length > 0
                width: parent.width
                spacing: 20
                Repeater {
                    model: wxPanel.forecastDays
                    Row {
                        required property var modelData
                        width: root.evenW((wxPanel.forecastDays.length > 0 ? parent.width - 40 : 0) / 3)
                        spacing: 8
                        UiText {
                            width: 32
                            text: wxPanel.dayIcon(modelData)
                            color: root.seal
                            font.family: root.mono
                            font.pixelSize: 24
                            horizontalAlignment: Text.AlignHCenter
                        }
                        Column {
                            width: 44
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 1
                            UiText {
                                text: wxPanel.dayName(modelData.date).toUpperCase()
                                color: root.sumiHi
                                font.family: root.mono; font.pixelSize: 10; font.letterSpacing: 1
                                elide: Text.ElideRight
                            }
                            Row {
                                spacing: 6
                                UiText {
                                    text: wxPanel.bareTempForDay(modelData, "max")
                                    color: root.ink
                                    font.family: root.mono; font.pixelSize: 12
                                }
                                UiText {
                                    text: wxPanel.bareTempForDay(modelData, "min")
                                    color: root.sumi
                                    font.family: root.mono; font.pixelSize: 12
                                }
                            }
                        }
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: root.sep; visible: wxPanel.forecastDays.length > 0 }

            // ── Actions: Refresh + unit toggle ──
            Row {
                width: parent.width
                height: 28
                spacing: 6
                Rectangle {
                    width: root.evenW((parent.width - parent.spacing) / 2)
                    height: 28; radius: root.panelButtonRadius
                    color: wxPanel.savingLocation ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.45)
                           : wxBtnMa.containsMouse ? root.fillPrimaryHover : root.seal
                    Behavior on color { ColorAnimation { duration: 120 } }
                    UiText {
                        anchors.centerIn: parent
                        text: wxPanel.savingLocation ? "Saving…" : "Refresh"
                        color: root.paper; font.family: root.mono; font.pixelSize: 11
                    }
                    MouseArea {
                        id: wxBtnMa
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: wxPanel.refresh()
                    }
                }
                Rectangle {
                    width: root.evenW((parent.width - parent.spacing) / 2)
                    height: 28; radius: root.panelButtonRadius
                    color: unitMa.containsMouse ? root.fillHover : root.fillIdle
                    border.color: unitMa.containsMouse ? root.seal : root.sep
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Behavior on border.color { ColorAnimation { duration: 120 } }
                    UiText {
                        anchors.centerIn: parent
                        text: root.weatherImperial ? "metric" : "imperial"
                        color: unitMa.containsMouse ? root.seal : root.ink
                        font.family: root.mono; font.pixelSize: 11
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }
                    MouseArea {
                        id: unitMa
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: root.weatherImperial = !root.weatherImperial
                    }
                }
            }
        }
    }

    // ───────────────────── data ─────────────────────
    property FileView locationFile: FileView {
        path: Quickshell.env("HOME") + "/.local/state/omarchy/settings/weather.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: wxPanel.configuredLocationState = Model.parseLocationFile(text())
        onLoadFailed: wxPanel.configuredLocationState = Model.parseLocationFile("")
    }

    // The first read can race shell startup, leaving a stored location unhonored
    // until the next file write; one delayed reload self-corrects.
    Timer {
        interval: 1500
        running: true
        onTriggered: wxPanel.locationFile.reload()
    }

    Process {
        id: forecastProc
        command: ["curl", "-fsS", "--max-time", "10", "https://wttr.in/" + wxPanel.locationQuery + "?format=j1"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                var raw = String(text || "").trim()
                if (!raw) {
                    wxPanel.scheduleForecastRetry()
                    return
                }
                try {
                    var parsed = JSON.parse(raw)
                    wxPanel.report = parsed
                    if (!wxPanel.hasConfiguredCoordinates)
                        wxPanel.label = Model.provisionalCurrentIcon(parsed.current_condition && parsed.current_condition[0], wxPanel.label)
                    wxPanel.forecastRetries = 0
                    if (Model.weatherResponseCompletesSave(wxPanel.hasConfiguredCoordinates, "wttr"))
                        wxPanel.finishSavingLocation()
                    if (isNaN(parseFloat(String(wxPanel.configuredLocationState.latitude))))
                        wxPanel.refreshDailyForecast(parsed)
                } catch (e) {
                    wxPanel.scheduleForecastRetry()
                }
            }
        }
    }

    Timer {
        id: forecastRetryTimer
        interval: 2500
        onTriggered: if (!forecastProc.running) forecastProc.running = true
    }

    Process {
        id: dailyForecastProc
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                var raw = String(text || "").trim()
                if (!raw) {
                    wxPanel.scheduleDailyForecastRetry()
                    return
                }
                try {
                    var parsed = JSON.parse(raw)
                    var parsedCurrent = Model.openMeteoCurrentCondition(parsed)
                    wxPanel.dailyForecastReport = parsed
                    wxPanel.label = Model.currentIcon(parsedCurrent, wxPanel.label)
                    wxPanel.dailyForecastRetries = 0
                    if (Model.weatherResponseCompletesSave(wxPanel.hasConfiguredCoordinates, "open-meteo"))
                        wxPanel.finishSavingLocation()
                } catch (e) {
                    wxPanel.scheduleDailyForecastRetry()
                }
            }
        }
    }

    Timer {
        id: dailyForecastRetryTimer
        interval: 2500
        onTriggered: wxPanel.refreshDailyForecast(null)
    }

    Process {
        id: geocodeProc
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                wxPanel.locationSuggestions = wxPanel.editingLocation ? Model.parseGeocodingResults(text) : []
                wxPanel.suggestionIndex = 0
                if (wxPanel.geocodePendingQuery !== wxPanel.geocodeActiveQuery)
                    Qt.callLater(wxPanel.startGeocode)
            }
        }
    }

    Timer {
        id: geocodeDebounce
        interval: 300
        onTriggered: wxPanel.requestGeocode()
    }

    Process {
        id: locationSaveProc
        onExited: function(exitCode) {
            if (exitCode !== 0 || !wxPanel.savingLocation) return
            // FileView handles changed locations; refresh explicitly too so saving
            // the already-active location cannot strand the spinner.
            wxPanel.locationFile.reload()
            if (!wxPanel.savingLocationQueryStarted) {
                wxPanel.savingLocationQueryStarted = true
                wxPanel.forecastRetries = 0
                wxPanel.dailyForecastRetries = 0
                forecastProc.running = false
                dailyForecastProc.running = false
                Qt.callLater(wxPanel.refresh)
            }
        }
    }

    Process {
        id: locationProc
        command: ["curl", "-fsS", "--max-time", "4", "https://wttr.in/?format=%l"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                var raw = String(text || "").trim()
                if (!raw) return
                wxPanel.wttrLocation = raw.split(",")[0]
            }
        }
    }

    Timer {
        id: refreshTimer
        interval: wxPanel.refreshMinutes * 60 * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: wxPanel.refresh()
    }

    onVisibleChanged: { if (visible) wxPanel.refresh() }
}