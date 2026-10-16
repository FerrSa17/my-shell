import QtQuick
import qs.config
import qs.services

// The dock's context menu for one app: New window, Keep in dock / Remove from dock, Move left / right
// for a pinned app, Show all for minimised windows and Quit (its windows are the hover stack, DockStack).
// done() closes it.
Rectangle {
    id: root
    property var app: null
    signal done()
    readonly property var items: {
        const a = root.app
        if (!a) return []
        const out = []
        out.push({ label: "New window", glyph: "add", run: () => Dock.launch(a) })
        out.push({ label: a.pinned ? "Remove from dock" : "Keep in dock", glyph: a.pinned ? "keep_off" : "keep", run: () => Dock.setPinned(a.id, !a.pinned) })
        if (a.pinned) {
            out.push({ label: "Move left", glyph: "chevron_left", run: () => Dock.movePinned(a.id, -1) })
            out.push({ label: "Move right", glyph: "chevron_right", run: () => Dock.movePinned(a.id, 1) })
        }
        if (a.minimizedCount > 0) out.push({ label: "Show all windows", glyph: "open_in_full", run: () => Dock.restoreAll(a) })
        if (a.windows.length) out.push({ label: "Quit", glyph: "close", run: () => Dock.closeAll(a) })
        return out
    }
    width: 220; height: col.implicitHeight + 12
    radius: 14
    color: "#000000"
    border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.06)

    Column {
        id: col
        x: 6; y: 6; width: parent.width - 12
        Text {
            width: parent.width; height: 26; leftPadding: 8; verticalAlignment: Text.AlignVCenter
            text: root.app ? root.app.name : ""; elide: Text.ElideRight
            color: Colors.islandFgVar; font.family: Theme.fontUi; font.pixelSize: 11; font.weight: Font.DemiBold
        }
        Repeater {
            model: root.items
            delegate: Item {
                required property var modelData
                width: col.width; height: 30
                Rectangle {
                    anchors.fill: parent; radius: 8
                    color: hit.containsMouse ? Colors.islandSurfaceHigh : "transparent"
                    Text {
                        id: glyph
                        x: 8; anchors.verticalCenter: parent.verticalCenter
                        text: parent.parent.modelData.glyph || ""; color: Colors.islandFgVar
                        font.family: Theme.fontIcon; font.pixelSize: 16
                    }
                    Text {
                        anchors { left: glyph.right; leftMargin: 8; right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                        text: parent.parent.modelData.label || ""; elide: Text.ElideRight
                        color: Colors.islandFg; font.family: Theme.fontUi; font.pixelSize: 13
                    }
                    MouseArea {
                        id: hit
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        Accessible.role: Accessible.MenuItem; Accessible.name: parent.parent.modelData.label || ""
                        onClicked: { const m = parent.parent.modelData; root.done(); m.run() }
                    }
                }
            }
        }
    }
}
