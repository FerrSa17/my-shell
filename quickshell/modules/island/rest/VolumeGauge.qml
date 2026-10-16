import QtQuick
import qs.config
import qs.services

// Volume for the rest pill: a ring that fills with the level around the speaker glyph. When the
// level changes the glyph flips to the number for a moment and the ring pops; muted, the ring dims
// and the glyph crosses out. The wheel steps it by 5 %, a click mutes.
Item {
    id: root
    readonly property real level: Audio.volume
    readonly property bool muted: Audio.muted || level <= 0.001
    readonly property string glyph: muted ? "volume_off" : level < 0.34 ? "volume_mute" : level < 0.67 ? "volume_down" : "volume_up"
    property bool flash: false
    implicitWidth: 24; implicitHeight: 24
    width: implicitWidth; height: implicitHeight

    Timer { id: flashTimer; interval: 1200; onTriggered: root.flash = false }
    Connections {
        target: Audio
        function onChanged(kind) { if (kind === "volume") { root.flash = true; flashTimer.restart(); pop.restart() } }
    }

    Canvas {
        id: ring
        anchors.fill: parent
        property real p: root.muted ? 0 : root.level
        property color track: Qt.rgba(1, 1, 1, 0.16)
        property color fill: root.flash ? Colors.darkPrimary : Colors.alpha(Colors.darkOnSurface, 0.85)
        Behavior on p { NumberAnimation { duration: Theme.durationNormal; easing.type: Easing.OutCubic } }
        onPChanged: requestPaint(); onFillChanged: requestPaint()
        onPaint: {
            const c = getContext("2d"); c.reset(); c.lineWidth = 2; c.lineCap = "round"
            const cx = width / 2, cy = height / 2, r = width / 2 - 1.5
            c.strokeStyle = track; c.beginPath(); c.arc(cx, cy, r, 0, Math.PI * 2); c.stroke()
            if (p > 0.005) { c.strokeStyle = fill; c.beginPath(); c.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + p * Math.PI * 2); c.stroke() }
        }
        SequentialAnimation on scale {
            id: pop
            running: false
            NumberAnimation { to: 1.18; duration: 90; easing.type: Easing.OutQuad }
            NumberAnimation { to: 1; duration: 220; easing.type: Easing.OutBack }
        }
    }
    Text {
        anchors.centerIn: parent
        opacity: root.flash ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: Theme.durationShort } }
        text: root.glyph; color: Colors.alpha(Colors.darkOnSurface, root.muted ? 0.5 : 0.9)
        font.family: Theme.fontIcon; font.pixelSize: 13
    }
    Text {
        anchors.centerIn: parent
        opacity: root.flash ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.durationShort } }
        text: Math.round(root.level * 100); color: Colors.darkOnSurface
        font.family: Theme.fontUi; font.pixelSize: 9; font.weight: Font.Bold; font.features: { "tnum": 1 }
    }
    MouseArea {
        anchors.fill: parent; anchors.margins: -4
        cursorShape: Qt.PointingHandCursor
        Accessible.role: Accessible.Button; Accessible.name: "Volume " + Math.round(root.level * 100) + " %"
        onClicked: Audio.toggleMute()
        onWheel: wheel => { if (wheel.angleDelta.y !== 0) Audio.step(wheel.angleDelta.y > 0 ? 1 : -1) }
    }
}
