import QtQuick
import qs.config
import qs.services

// Workspace dots for the rest pill: this monitor's block of workspaces, the active one a wide
// capsule in the primary colour, occupied ones brighter than empty ones. A click goes to one,
// the wheel steps through them.
Item {
    id: root
    property string screenName: ""
    readonly property var list: Hypr.workspacesFor(screenName)
    readonly property int dot: 6
    readonly property int activeWidth: 16
    readonly property int gap: 5
    implicitWidth: row.implicitWidth; implicitHeight: 16
    width: implicitWidth; height: implicitHeight

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.gap
        Repeater {
            model: root.list
            delegate: Rectangle {
                required property var modelData
                width: modelData.active ? root.activeWidth : root.dot; height: root.dot; radius: height / 2
                anchors.verticalCenter: parent.verticalCenter
                color: modelData.active ? Colors.darkPrimary
                    : Colors.alpha(Colors.darkOnSurface, modelData.occupied ? 0.6 : 0.22)
                Behavior on width { NumberAnimation { duration: Theme.durationNormal; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: Theme.durationNormal } }
                MouseArea {
                    anchors.fill: parent; anchors.margins: -3
                    cursorShape: Qt.PointingHandCursor
                    Accessible.role: Accessible.Button; Accessible.name: "Workspace " + parent.modelData.id
                    onClicked: Hypr.go(parent.modelData.id)
                }
            }
        }
    }
    MouseArea {
        anchors.fill: parent; z: -1
        acceptedButtons: Qt.NoButton
        onWheel: wheel => { if (wheel.angleDelta.y !== 0) Hypr.step(wheel.angleDelta.y > 0 ? -1 : 1) }
    }
}
