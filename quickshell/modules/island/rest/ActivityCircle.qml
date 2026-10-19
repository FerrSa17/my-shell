import QtQuick
import QtQuick.Effects
import qs.config
import qs.services

// Left slot of the rest pill. Priority: countdown ring
// with mm:ss, then album art in a circle with a thin progress ring while a player is playing (a
// music-note glyph when it has no art). `shown` is false when there is nothing to show; the parent
// then collapses the slot so the pill narrows. The timer/media inputs are plain properties
// bound to the services.
Item {
    id: root
    // The countdown is drawn around the island and beside it (TimerRing), not inside the pill.
    property bool timerOn: false
    property int timerSecs: Countdown.remaining
    property bool mediaOn: Media.player !== null && Media.playing
    property real mediaProgress: Media.length > 0 ? Math.max(0, Math.min(1, Media.position / Media.length)) : 0
    property string artUrl: Media.artUrl
    // While music plays the art breathes slowly (a steady sine, not the waveform's random bars: those
    // made it tremble).
    property bool beating: false
    readonly property string mode: !Settings.island.liveActivities ? "" : timerOn ? "timer" : mediaOn ? "media" : ""
    readonly property bool shown: mode !== ""
    readonly property real progress: mode === "timer" ? timerProgress : mediaProgress
    readonly property bool hasArt: artUrl !== "" && art.status === Image.Ready
    readonly property string timeText: { const s = Math.max(0, timerSecs); const m = Math.floor(s / 60)
        return (m < 10 ? "0" : "") + m + ":" + (s % 60 < 10 ? "0" : "") + (s % 60) }
    property int timerTotal: Countdown.total
    property real timerProgress: timerTotal > 0 ? Math.max(0, Math.min(1, timerSecs / timerTotal)) : 0
    implicitWidth: mode === "timer" ? 24 + 6 + timeLabel.implicitWidth : 24; implicitHeight: 24
    width: implicitWidth; height: implicitHeight

    Text {
        id: timeLabel
        objectName: "timeLabel"
        visible: root.mode === "timer"
        anchors.left: ringBox.right; anchors.leftMargin: 6; anchors.verticalCenter: parent.verticalCenter
        text: root.timeText; color: Colors.darkOnSurface
        font.family: Theme.fontMono; font.pixelSize: 11
    }
    Item { id: ringBox; x: 0; width: 24; height: 24 }

    Item {
        id: artBox
        visible: root.mode === "media"
        anchors.centerIn: ringBox; width: 18; height: 18
        SequentialAnimation on scale {
            running: root.beating && root.visible; loops: Animation.Infinite
            NumberAnimation { to: 1.07; duration: 700; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1.0; duration: 700; easing.type: Easing.InOutSine }
            onRunningChanged: if (!running) artBox.scale = 1
        }
        Image {
            id: art
            anchors.fill: parent; source: root.artUrl; fillMode: Image.PreserveAspectCrop
            sourceSize.width: 48; sourceSize.height: 48; asynchronous: true
            visible: false; layer.enabled: true
        }
        // A visible copy through the mask; the plain Image above only feeds it.
        MultiEffect { anchors.fill: parent; source: art; visible: root.hasArt; maskEnabled: true; maskSource: maskItem
            maskThresholdMin: 0.5; maskSpreadAtMin: 1.0 }
        Item { id: maskItem; anchors.fill: parent; visible: false; layer.enabled: true
            Rectangle { anchors.fill: parent; radius: width / 2; color: "black" } }
        Rectangle { anchors.fill: parent; radius: width / 2; visible: !root.hasArt; color: Qt.rgba(1, 1, 1, 0.10)
            Text { anchors.centerIn: parent; text: "music_note"; font.family: Theme.fontIcon; font.pixelSize: 12; color: Colors.darkOnSurface } }
    }
    Canvas {
        id: ring
        anchors.fill: ringBox
        visible: root.mode === "media" || root.mode === "timer"
        property real p: root.progress
        property color track: Qt.rgba(1, 1, 1, 0.16)
        property color fill: Colors.darkPrimary
        onPChanged: requestPaint(); onFillChanged: requestPaint()
        onPaint: {
            const c = getContext("2d"); c.reset(); c.lineWidth = 1.5; c.lineCap = "round"
            const cx = width / 2, cy = height / 2, r = width / 2 - 1.25
            c.strokeStyle = track; c.beginPath(); c.arc(cx, cy, r, 0, Math.PI * 2); c.stroke()
            if (p > 0.005) { c.strokeStyle = fill; c.beginPath(); c.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + p * Math.PI * 2); c.stroke() }
        }
    }
}
