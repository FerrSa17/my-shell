import QtQuick
import Quickshell.Widgets
import qs.config
import qs.services

// The windows of one app stacked out from its dock icon, like a macOS stack: one black capsule per
// window, all the same width (the app icon and the title, dimmed when minimised), the nearest one
// first, each sliding out from the dock and fading in a moment after the previous one. `edge` is the
// dock's screen edge: the stack rises from a bottom dock, drops from a top one, and slides sideways
// from a side one. A click focuses that window, or brings it back when minimised; done() closes it.
Item {
    id: root
    property var app: null
    property string edge: "bottom"
    signal done()
    readonly property var windows: app ? app.windows.slice(0, 10) : []
    readonly property int rowH: 36
    readonly property int gap: 6
    width: 240; height: windows.length * (rowH + gap)

    Repeater {
        // By count: Dock.apps is rebuilt on every compositor event, and a new array as the model would
        // recreate the cards (and replay the rise) each time.
        model: root.windows.length
        delegate: Rectangle {
            id: card
            required property int index
            readonly property var modelData: root.windows[index] || ({})
            readonly property real restY: root.edge === "bottom" ? root.height - (index + 1) * (root.rowH + root.gap) : index * (root.rowH + root.gap)
            // Where a card starts: behind the dock (below, above, or to the dock's side).
            readonly property real fromY: root.edge === "bottom" ? root.height : root.edge === "top" ? -root.rowH : restY
            readonly property real fromX: root.edge === "left" ? -40 : root.edge === "right" ? 40 : 0
            width: root.width; height: root.rowH; radius: height / 2
            color: hit.containsMouse ? "#1a1a1a" : "#000000"
            border.width: 1; border.color: modelData.activated && !modelData.minimized ? Colors.islandPrimary : Qt.rgba(1, 1, 1, 0.06)
            opacity: 0; y: fromY; x: fromX
            Component.onCompleted: rise.start()
            ParallelAnimation {
                id: rise
                PropertyAnimation { target: card; property: "y"; from: card.fromY; to: card.restY; duration: Theme.durationNormal + card.index * 30; easing.type: Easing.OutBack; easing.overshoot: 1.1 }
                PropertyAnimation { target: card; property: "x"; from: card.fromX; to: 0; duration: Theme.durationNormal + card.index * 30; easing.type: Easing.OutBack; easing.overshoot: 1.1 }
                SequentialAnimation {
                    PauseAnimation { duration: card.index * 30 }
                    NumberAnimation { target: card; property: "opacity"; to: 1; duration: Theme.durationShort }
                }
            }
            IconImage {
                id: ico
                x: 8; anchors.verticalCenter: parent.verticalCenter
                width: 22; height: 22
                source: root.app ? root.app.icon : ""
                opacity: card.modelData.minimized ? 0.5 : 1
            }
            Text {
                id: label
                anchors { left: ico.right; leftMargin: 10; right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
                text: card.modelData.title; elide: Text.ElideRight
                color: card.modelData.minimized ? Colors.islandFgVar : Colors.islandFg
                font.family: Theme.fontUi; font.pixelSize: 13
            }
            MouseArea {
                id: hit
                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                Accessible.role: Accessible.Button; Accessible.name: card.modelData.title
                onClicked: {
                    const w = card.modelData
                    root.done()
                    w.minimized ? Dock.restore(w.address) : Dock.focus(w.address)
                }
            }
        }
    }
}
