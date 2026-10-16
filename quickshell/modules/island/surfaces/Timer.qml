import QtQuick
import qs.config
import qs.services

// Timer surface (360x236): the time in large SF Pro Display figures over a thin progress line,
// presets and -/+ one minute while idle (the wheel on the figures steps too), then Start, or Pause /
// Resume and Cancel while it runs. The countdown itself is the Countdown service, so it keeps going
// with the surface closed and shows in the rest pill's activity circle.
Item {
    id: root
    property size size: Sizes.timer
    // The length the next Start uses, in seconds.
    property int setSecs: 300
    readonly property bool active: Countdown.active
    readonly property int shownSecs: active ? Countdown.remaining : setSecs
    readonly property var presets: [1, 3, 5, 10, 15, 25, 45, 60]

    function fmt(s) {
        s = Math.max(0, s)
        const h = Math.floor(s / 3600), m = Math.floor(s / 60) % 60, x = s % 60
        const two = n => (n < 10 ? "0" : "") + n
        return (h > 0 ? h + ":" + two(m) : two(m)) + ":" + two(x)
    }
    function adjust(min) { setSecs = Math.max(60, Math.min(5 * 3600, setSecs + min * 60)) }

    component Pill: Rectangle {
        id: pill
        property string text
        property string glyph
        property bool primary: false
        property bool on: false
        signal clicked()
        implicitWidth: glyph !== "" && text === "" ? 36 : lbl.implicitWidth + (glyph !== "" ? 46 : 28); implicitHeight: 36
        radius: height / 2
        color: primary ? (hit.containsMouse ? Qt.lighter(Colors.islandPrimary, 1.08) : Colors.islandPrimary)
            : on ? Colors.islandSecondaryContainer : (hit.containsMouse ? Colors.islandSurfaceHigh : Colors.islandSurface)
        Row {
            anchors.centerIn: parent; spacing: 6
            Text {
                visible: pill.glyph !== ""; anchors.verticalCenter: parent.verticalCenter
                text: pill.glyph; font.family: Theme.fontIcon; font.pixelSize: 18
                color: pill.primary ? Colors.islandOnPrimary : Colors.islandFg
            }
            Text {
                id: lbl
                visible: pill.text !== ""; anchors.verticalCenter: parent.verticalCenter
                text: pill.text; font.family: Theme.fontUi; font.pixelSize: 13; font.weight: Font.Medium
                color: pill.primary ? Colors.islandOnPrimary : pill.on ? Colors.islandOnSecondaryContainer : Colors.islandFg
            }
        }
        MouseArea { id: hit; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pill.clicked()
            Accessible.role: Accessible.Button; Accessible.name: pill.text || pill.glyph }
    }

    Item {
        anchors.fill: parent; anchors.margins: 16

        Text {
            id: title
            text: "Timer"; color: Colors.islandFg
            font.family: Theme.fontUi; font.pixelSize: 15; font.weight: Font.DemiBold
        }
        Text {
            anchors { right: parent.right; verticalCenter: title.verticalCenter }
            text: Countdown.paused ? "Paused" : Countdown.running ? "Ends " + Qt.formatTime(new Date(Countdown.endsAt), "hh:mm") : ""
            color: Colors.islandFgVar; font.family: Theme.fontUi; font.pixelSize: 12
        }

        Row {
            id: figures
            anchors { horizontalCenter: parent.horizontalCenter; top: title.bottom; topMargin: 8 }
            spacing: 14
            Pill { visible: !root.active; anchors.verticalCenter: parent.verticalCenter; glyph: "remove"; onClicked: root.adjust(-1) }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.fmt(root.shownSecs)
                color: Countdown.paused ? Colors.islandFgVar : Colors.islandFg
                font.family: Theme.fontDisplay; font.pixelSize: 52; font.weight: Font.Light
                font.features: { "tnum": 1 }
                MouseArea {
                    anchors.fill: parent; acceptedButtons: Qt.NoButton
                    onWheel: wheel => { if (!root.active && wheel.angleDelta.y !== 0) root.adjust(wheel.angleDelta.y > 0 ? 1 : -1) }
                }
            }
            Pill { visible: !root.active; anchors.verticalCenter: parent.verticalCenter; glyph: "add"; onClicked: root.adjust(1) }
        }

        Rectangle {
            id: track
            anchors { left: parent.left; right: parent.right; top: figures.bottom; topMargin: 6 }
            height: 3; radius: 1.5; color: Colors.islandSurfaceHighest
            Rectangle {
                height: parent.height; radius: parent.radius; color: Colors.islandPrimary
                width: root.active && Countdown.total > 0 ? parent.width * Countdown.remaining / Countdown.total : (root.active ? 0 : parent.width)
                Behavior on width { NumberAnimation { duration: 450 } }
            }
        }

        Row {
            id: presetRow
            visible: !root.active
            anchors { horizontalCenter: parent.horizontalCenter; top: track.bottom; topMargin: 14 }
            spacing: 6
            Repeater {
                model: root.presets
                delegate: Rectangle {
                    required property int modelData
                    readonly property bool on: root.setSecs === modelData * 60
                    width: 34; height: 26; radius: 13
                    color: on ? Colors.islandSecondaryContainer : (presetHit.containsMouse ? Colors.islandSurfaceHigh : Colors.islandSurface)
                    Text {
                        anchors.centerIn: parent; text: parent.modelData
                        color: parent.on ? Colors.islandOnSecondaryContainer : Colors.islandFg
                        font.family: Theme.fontUi; font.pixelSize: 12; font.weight: Font.Medium; font.features: { "tnum": 1 }
                    }
                    MouseArea { id: presetHit; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        Accessible.role: Accessible.Button; Accessible.name: parent.modelData + " minutes"
                        onClicked: root.setSecs = parent.modelData * 60 }
                }
            }
        }

        Row {
            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom }
            spacing: 10
            Pill { visible: !root.active; primary: true; glyph: "play_arrow"; text: "Start"; onClicked: Countdown.start(root.setSecs, "") }
            Pill { visible: root.active; on: Countdown.paused; glyph: Countdown.paused ? "play_arrow" : "pause"; text: Countdown.paused ? "Resume" : "Pause"
                onClicked: Countdown.paused ? Countdown.resume() : Countdown.pause() }
            Pill { visible: root.active; glyph: "stop"; text: "Cancel"; onClicked: Countdown.stop() }
        }
    }
}
