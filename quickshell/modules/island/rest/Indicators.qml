import QtQuick
import qs.config
import qs.services

// Privacy indicators for the rest pill, coloured like macOS / iOS: a screen recording in red
// (pulsing) and the microphone in orange. island.recIndicator / island.micIndicator switch each off.
// The row has no width while neither shows, so the pill does not make room for it.
Row {
    id: root
    spacing: 4
    readonly property bool recording: Recording.active && Settings.island.recIndicator !== false
    readonly property bool mic: Privacy.micInUse && Settings.island.micIndicator !== false
    visible: recording || mic

    Text {
        objectName: "privacyRecording"
        visible: root.recording; anchors.verticalCenter: parent.verticalCenter
        text: "screen_record"; color: "#ff453a"; font.family: Theme.fontIcon; font.pixelSize: 16
        SequentialAnimation on opacity {
            running: root.recording; loops: Animation.Infinite
            NumberAnimation { to: 0.35; duration: 700; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1.0; duration: 700; easing.type: Easing.InOutSine }
        }
    }
    Text {
        objectName: "privacyMic"
        visible: root.mic; anchors.verticalCenter: parent.verticalCenter
        text: "mic"; color: "#ff9f0a"; font.family: Theme.fontIcon; font.pixelSize: 16
    }
}
