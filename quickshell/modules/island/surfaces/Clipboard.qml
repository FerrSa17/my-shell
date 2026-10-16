import QtQuick
import Quickshell
import qs.config
import "clipboard"
import "launcher"

// Clipboard history surface (the cliphist list): a search field, then every copied text and image,
// newest first (images with a thumbnail). Enter or a click copies the entry back and closes; Delete
// or the cross removes one; "Clear all" wipes the history. Up/Down/Tab move, Esc emits close().
// The history is recorded by `wl-paste --watch cliphist store` (started with Hyprland).
FocusScope {
    id: root
    property size size: Sizes.clipboard
    property bool wantsKeyboard: true
    property string query: ""
    property int currentIndex: 0
    signal close()

    readonly property var results: clip.items(query.trim().toLowerCase())
    readonly property int count: results.length
    readonly property var current: count > 0 && currentIndex < count ? results[currentIndex] : null

    function move(d) { if (count > 0) currentIndex = (currentIndex + d + count) % count }
    function activate(i) {
        const item = results[i === undefined ? currentIndex : i]
        if (!item) return
        root.close()
        item.run()
    }
    function removeAt(i) {
        const item = results[i]
        if (!item) return
        item.remove()
        if (currentIndex >= count - 1) currentIndex = Math.max(0, count - 2)
    }

    Clip { id: clip; active: true }

    Component.onCompleted: input.forceActiveFocus()
    onVisibleChanged: if (visible) input.forceActiveFocus()

    Item {
        anchors.fill: parent; anchors.margins: 16

        Item {
            id: field
            anchors { left: parent.left; right: parent.right; top: parent.top }
            height: 36
            Text {
                id: glyph
                anchors { left: parent.left; leftMargin: 4; verticalCenter: parent.verticalCenter }
                text: "content_paste"; font.family: Theme.fontIcon; font.pixelSize: 20; color: Colors.islandFgVar
            }
            TextInput {
                id: input
                Accessible.role: Accessible.EditableText; Accessible.name: "Search the clipboard"
                anchors { left: glyph.right; leftMargin: 10; right: clearChip.left; rightMargin: 10; verticalCenter: parent.verticalCenter }
                font.family: Theme.fontUi; font.pixelSize: Theme.textLauncher
                color: Colors.islandFg
                selectionColor: Colors.islandPrimary; selectedTextColor: Colors.islandOnPrimary
                clip: true; focus: true
                onTextEdited: { root.query = text; root.currentIndex = 0 }
                Keys.onPressed: event => {
                    const ctrl = event.modifiers & Qt.ControlModifier
                    if (event.key === Qt.Key_Escape) root.close()
                    else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) root.activate()
                    else if (event.key === Qt.Key_Delete) root.removeAt(root.currentIndex)
                    else if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab || (ctrl && event.key === Qt.Key_N)) root.move(1)
                    else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab || (ctrl && event.key === Qt.Key_P)) root.move(-1)
                    else return
                    event.accepted = true
                }
                Text {
                    anchors.fill: parent; verticalAlignment: Text.AlignVCenter
                    visible: input.text.length === 0
                    text: "Search the clipboard, Delete removes"
                    font: input.font; color: Colors.islandFgVar
                }
            }
            Rectangle {
                id: clearChip
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                width: clearText.implicitWidth + 20; height: 26; radius: 13
                opacity: clip.lines.length > 0 ? 1 : 0.4
                color: clearHit.containsMouse && clip.lines.length > 0 ? Colors.islandSurfaceHighest : Colors.islandSurfaceHigh
                Text { id: clearText; anchors.centerIn: parent; text: "Clear all"; color: Colors.islandFg
                    font.family: Theme.fontUi; font.pixelSize: 12; font.weight: Font.Medium }
                MouseArea { id: clearHit; anchors.fill: parent; hoverEnabled: true; enabled: clip.lines.length > 0
                    cursorShape: Qt.PointingHandCursor; onClicked: clip.clear()
                    Accessible.role: Accessible.Button; Accessible.name: "Clear the clipboard history" }
            }
        }
        Rectangle {
            id: rule
            anchors { left: parent.left; right: parent.right; top: field.bottom; topMargin: 8 }
            height: 1; color: Qt.rgba(1, 1, 1, 0.12)
        }
        ListView {
            id: list
            anchors { left: parent.left; right: parent.right; top: rule.bottom; topMargin: 6; bottom: parent.bottom }
            clip: true
            model: root.results
            currentIndex: root.currentIndex
            highlightMoveDuration: 80
            boundsBehavior: Flickable.StopAtBounds
            delegate: ResultRow {
                id: row
                required property var modelData
                required property int index
                width: list.width
                entry: modelData
                thumbs: clip.thumbs
                selected: index === root.currentIndex
                onClicked: root.activate(index)
                onHovered: root.currentIndex = index
                // The cross for this entry, over the hint's place while the row is under the pointer.
                Rectangle {
                    visible: row.selected
                    anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
                    width: 28; height: 28; radius: 14
                    color: crossHit.containsMouse ? Colors.alpha(Colors.islandError, 0.25) : Colors.islandSurfaceHigh
                    Text { anchors.centerIn: parent; text: "close"; font.family: Theme.fontIcon; font.pixelSize: 16
                        color: crossHit.containsMouse ? Colors.islandError : Colors.islandFgVar }
                    MouseArea { id: crossHit; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: root.removeAt(row.index)
                        Accessible.role: Accessible.Button; Accessible.name: "Remove this entry" }
                }
            }
            Text {
                anchors.centerIn: parent; visible: list.count === 0
                text: !clip.loaded ? "Loading clipboard" : !clip.available ? "cliphist is not installed"
                    : clip.lines.length === 0 ? "Clipboard is empty" : "No matches"
                font.family: Theme.fontUi; font.pixelSize: Theme.textLauncher; color: Colors.islandFgVar
            }
        }
    }
}
