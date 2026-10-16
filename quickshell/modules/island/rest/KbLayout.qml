import QtQuick
import qs.config
import qs.services

// The keyboard layout for the rest pill ("EN", "RU"); a click switches to the next one.
Item {
    id: root
    implicitWidth: label.implicitWidth; implicitHeight: 16
    width: implicitWidth; height: implicitHeight
    Text {
        id: label
        anchors.centerIn: parent
        text: Hypr.kbShort; color: Colors.alpha(Colors.darkOnSurface, 0.85)
        font.family: Theme.fontUi; font.pixelSize: 12; font.weight: Font.DemiBold; font.letterSpacing: 0.2
    }
    MouseArea {
        anchors.fill: parent; anchors.margins: -4
        cursorShape: Qt.PointingHandCursor
        Accessible.role: Accessible.Button; Accessible.name: "Keyboard layout " + Hypr.kbLayout
        onClicked: Hypr.nextLayout()
    }
}
