import QtQuick
import QtCore
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore

PlasmoidItem {
    id: root

    readonly property string appStateUrl: StandardPaths.writableLocation(
        StandardPaths.GenericDataLocation
    ).toString().replace(/\/$/, "") + "/atomic-time/clock-state.json"
    property string timeText: "--:--:--"
    property string millisecondText: "000"
    property string periodText: ""
    property string readoutText: "--:--:--.000"
    readonly property color readoutColor: Plasmoid.configuration.readoutColor || "#57ef7e"
    property int appHourFormat: 24
    property double appClockOffsetMs: 0
    property double appTimeZoneOffsetMs: 0
    property double appStateUpdatedAt: 0
    property bool appStateAvailable: false
    property bool stateReadInProgress: false
    property bool stateWarningReported: false
    property bool fallbackSyncAttempted: false
    property double synchronizedWallTime: 0
    property double synchronizationStartedAt: 0
    property bool hasSynced: false
    property bool requestInProgress: false
    property int requestSequence: 0

    Plasmoid.backgroundHints: Plasmoid.configuration.transparentBackground
                              ? PlasmaCore.Types.NoBackground
                              : PlasmaCore.Types.DefaultBackground

    preferredRepresentation: Plasmoid.formFactor === PlasmaCore.Types.Planar
                            ? fullRepresentation : compactRepresentation

    function pad(value, width) {
        return String(value).padStart(width, "0")
    }

    function updateDisplay() {
        var date = appStateAvailable
                ? new Date(Date.now() + appClockOffsetMs + appTimeZoneOffsetMs)
                : hasSynced
                    ? new Date(synchronizedWallTime + Date.now() - synchronizationStartedAt)
                    : new Date()
        var hour = appStateAvailable ? date.getUTCHours() : date.getHours()
        var minute = appStateAvailable ? date.getUTCMinutes() : date.getMinutes()
        var second = appStateAvailable ? date.getUTCSeconds() : date.getSeconds()
        var millisecond = appStateAvailable ? date.getUTCMilliseconds() : date.getMilliseconds()
        var use24Hour = appStateAvailable ? appHourFormat === 24 : true

        periodText = hour < 12 ? "AM" : "PM"
        if (!use24Hour) {
            hour = hour % 12 || 12
        } else {
            periodText = ""
        }

        timeText = pad(hour, 2) + ":" + pad(minute, 2) + ":" + pad(second, 2)
        millisecondText = pad(millisecond, 3)
        readoutText = timeText + "." + millisecondText + (periodText.length ? " " + periodText : "")
    }

    function requestFallbackSync() {
        if (appStateAvailable || fallbackSyncAttempted) {
            return
        }

        fallbackSyncAttempted = true
        syncClock()
    }

    function readAppState() {
        if (stateReadInProgress) {
            return
        }

        stateReadInProgress = true
        var request = new XMLHttpRequest()
        request.open("GET", appStateUrl + "?t=" + Date.now())
        request.timeout = 5000
        request.onreadystatechange = function() {
            if (request.readyState !== 4) {
                return
            }

            stateReadInProgress = false
            var state
            try {
                state = JSON.parse(request.responseText)
            } catch (error) {
                if (request.responseText.length > 0 && !root.stateWarningReported) {
                    console.warn("Atomic Time could not parse the app clock state:", error)
                    root.stateWarningReported = true
                }
                root.requestFallbackSync()
                return
            }

            if (!state || state.version !== 1 || typeof state.timeZone !== "string"
                    || (state.hourFormat !== 12 && state.hourFormat !== 24)
                    || typeof state.synced !== "boolean"
                    || !Number.isFinite(state.clockOffsetMs)
                    || !Number.isFinite(state.timeZoneOffsetMs)
                    || !Number.isFinite(state.updatedAt)) {
                if (!root.stateWarningReported) {
                    console.warn("Atomic Time received invalid app clock state")
                    root.stateWarningReported = true
                }
                root.requestFallbackSync()
                return
            }

            root.stateWarningReported = false
            if (state.updatedAt === root.appStateUpdatedAt) {
                return
            }

            root.appStateAvailable = true
            root.appStateUpdatedAt = state.updatedAt
            root.appHourFormat = state.hourFormat
            root.appClockOffsetMs = state.synced ? state.clockOffsetMs : 0
            root.appTimeZoneOffsetMs = state.timeZoneOffsetMs
            root.hasSynced = state.synced
            if (root.requestInProgress) {
                root.requestSequence += 1
                root.requestInProgress = false
            }
            root.updateDisplay()
        }
        request.onerror = function() {
            root.stateReadInProgress = false
            root.requestFallbackSync()
        }
        request.ontimeout = function() {
            root.stateReadInProgress = false
            root.requestFallbackSync()
        }
        request.send()
    }

    function syncClock() {
        if (appStateAvailable || requestInProgress) {
            return
        }

        requestInProgress = true
        requestSequence += 1
        var sequence = requestSequence
        var zone = "Etc/UTC"
        var request = new XMLHttpRequest()
        request.open("GET", "https://timeapi.io/api/Time/current/zone?timeZone=" + encodeURIComponent(zone))
        request.timeout = 10000
        request.onreadystatechange = function() {
            if (request.readyState !== 4 || sequence !== requestSequence) {
                return
            }

            requestInProgress = false
            if (request.status < 200 || request.status >= 300) {
                return
            }

            var data
            try {
                data = JSON.parse(request.responseText)
            } catch (error) {
                return
            }

            var fields = [data.year, data.month, data.day, data.hour, data.minute, data.seconds]
            if (!fields.every(function(value) { return Number.isFinite(value) })) {
                return
            }

            synchronizedWallTime = Date.UTC(
                data.year,
                data.month - 1,
                data.day,
                data.hour,
                data.minute,
                data.seconds,
                Number.isFinite(data.milliSeconds) ? data.milliSeconds : 0
            )
            synchronizationStartedAt = Date.now()
            hasSynced = true
            updateDisplay()
        }
        request.onerror = function() {
            if (sequence !== requestSequence) {
                return
            }
            requestInProgress = false
        }
        request.ontimeout = function() {
            if (sequence !== requestSequence) {
                return
            }
            requestInProgress = false
        }
        request.send()
    }

    compactRepresentation: Item {
        implicitWidth: 250
        implicitHeight: 36

        Text {
            anchors.fill: parent
            text: root.readoutText
            color: root.readoutColor
            font.family: "monospace"
            font.pixelSize: 28
            font.weight: Font.Bold
            fontSizeMode: Text.Fit
            minimumPixelSize: 10
            maximumLineCount: 1
            wrapMode: Text.NoWrap
            style: Text.Outline
            styleColor: "#dd000000"
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }

    fullRepresentation: Item {
        implicitWidth: 420
        implicitHeight: 120

        Rectangle {
            anchors.fill: parent
            radius: 12
            color: Plasmoid.configuration.transparentBackground ? "transparent" : "#101310"
            border.color: Plasmoid.configuration.transparentBackground ? "transparent" : "#354238"
        }

        Text {
            anchors.fill: parent
            anchors.margins: 12
            text: root.readoutText
            color: root.readoutColor
            font.family: "monospace"
            font.pixelSize: 112
            font.weight: Font.Bold
            fontSizeMode: Text.Fit
            minimumPixelSize: 14
            maximumLineCount: 1
            wrapMode: Text.NoWrap
            style: Text.Outline
            styleColor: "#dd000000"
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }

    Timer {
        interval: 16
        repeat: true
        running: true
        onTriggered: root.updateDisplay()
    }

    Timer {
        interval: 60000
        repeat: true
        running: true
        onTriggered: {
            if (root.appStateAvailable) {
                root.readAppState()
            } else {
                root.fallbackSyncAttempted = false
                root.syncClock()
            }
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: root.readAppState()
    }

    Component.onCompleted: {
        updateDisplay()
        readAppState()
    }
}
