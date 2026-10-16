import QtQuick
import Quickshell
import qs.config

// lock / reboot / power off. Lock runs Paths.lockCmd; reboot and power off turn red on the first
// click and run on a second click within 2 s.
Row {
    id: row
    spacing: 6
    property string armed: ""
    readonly property var actions: [
        { id: "lock", glyph: "lock", cmd: Paths.lockCmd, confirm: false },
        { id: "reboot", glyph: "restart_alt", cmd: ["systemctl", "reboot"], confirm: true },
        { id: "poweroff", glyph: "power_settings_new", cmd: ["systemctl", "poweroff"], confirm: true }
    ]
    function press(a) {
        if (a.confirm && armed !== a.id) { armed = a.id; disarm.restart(); return }
        armed = ""; disarm.stop()
        Quickshell.execDetached(a.cmd)
    }
    Timer { id: disarm; interval: 2000; onTriggered: row.armed = "" }

    Repeater {
        model: row.actions
        delegate: Rectangle {
            id: btn
            required property var modelData
            readonly property bool isArmed: row.armed === modelData.id
            width: 32; height: 32; radius: 16
            // Armed (first click of a confirm action): solid red until the second click or 2 s pass.
            color: isArmed ? "#ff453a" : Colors.islandSurfaceHigh
            Behavior on color { ColorAnimation { duration: Theme.durationShort } }
            Text {
                anchors.centerIn: parent; text: btn.modelData.glyph
                color: btn.isArmed ? "#ffffff" : Colors.islandFg
                font.family: Theme.fontIcon; font.pixelSize: 18
            }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: row.press(btn.modelData)
                Accessible.role: Accessible.Button; Accessible.name: btn.isArmed ? "Confirm " + btn.modelData.id : ({ lock: "Lock", reboot: "Reboot", poweroff: "Power off" })[btn.modelData.id] }
        }
    }
}
