import QtQuick
import qs.config
import qs.services

// Tasks surface: a small to-do list inside the island (420x300). The field on top adds a task on
// Enter; a click on the circle checks it off, a double click on the text edits it, the cross
// deletes it. Completed tasks sink to the bottom; "Clear completed" drops them. Esc emits close().
FocusScope {
    id: root
    property size size: Sizes.todo
    property bool wantsKeyboard: true
    signal close()

    Component.onCompleted: input.forceActiveFocus()
    onVisibleChanged: if (visible) input.forceActiveFocus()

    Item {
        anchors.fill: parent; anchors.margins: 16

        Item {
            id: head
            anchors { left: parent.left; right: parent.right; top: parent.top }
            height: 24
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Tasks"; color: Colors.islandFg
                font.family: Theme.fontUi; font.pixelSize: 15; font.weight: Font.DemiBold
            }
            Text {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                text: Todo.open === 0 ? (Todo.tasks.length ? "All done" : "") : Todo.open + " left"
                color: Colors.islandFgVar
                font.family: Theme.fontUi; font.pixelSize: 12; font.features: { "tnum": 1 }
            }
        }

        Rectangle {
            id: field
            anchors { left: parent.left; right: parent.right; top: head.bottom; topMargin: 10 }
            height: 36; radius: 10
            color: Colors.islandSurface
            Text {
                id: plus
                anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                text: "add"; font.family: Theme.fontIcon; font.pixelSize: 18; color: Colors.islandFgVar
            }
            TextInput {
                id: input
                Accessible.role: Accessible.EditableText; Accessible.name: "New task"
                anchors { left: plus.right; leftMargin: 8; right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                font.family: Theme.fontUi; font.pixelSize: Theme.textLauncher
                color: Colors.islandFg
                selectionColor: Colors.islandPrimary; selectedTextColor: Colors.islandOnPrimary
                clip: true; focus: true
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape) root.close()
                    else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { Todo.add(text); text = "" }
                    else return
                    event.accepted = true
                }
                Text {
                    anchors.fill: parent; verticalAlignment: Text.AlignVCenter
                    visible: input.text.length === 0
                    text: "New task"; font: input.font; color: Colors.islandFgVar
                }
            }
        }

        ListView {
            id: list
            anchors { left: parent.left; right: parent.right; top: field.bottom; topMargin: 8; bottom: foot.top; bottomMargin: 4 }
            clip: true; spacing: 2
            boundsBehavior: Flickable.StopAtBounds
            model: Todo.tasks
            delegate: Item {
                id: row
                required property var modelData
                property bool editing: false
                width: list.width; height: 32
                Rectangle {
                    anchors.fill: parent; radius: 8
                    color: rowHover.hovered ? Colors.islandSurface : "transparent"
                }
                HoverHandler { id: rowHover }
                Rectangle {
                    id: check
                    x: 8; anchors.verticalCenter: parent.verticalCenter
                    width: 18; height: 18; radius: 9
                    color: row.modelData.done ? Colors.islandPrimary : "transparent"
                    border.width: row.modelData.done ? 0 : 1.5
                    border.color: Colors.islandFgVar
                    Behavior on color { ColorAnimation { duration: Theme.durationShort } }
                    Text {
                        anchors.centerIn: parent; visible: row.modelData.done
                        text: "check"; font.family: Theme.fontIcon; font.pixelSize: 14; font.weight: Font.Bold
                        color: Colors.islandOnPrimary
                    }
                    MouseArea {
                        anchors.fill: parent; anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        Accessible.role: Accessible.CheckBox; Accessible.name: row.modelData.text; Accessible.checked: row.modelData.done
                        onClicked: Todo.toggle(row.modelData.id)
                    }
                }
                Text {
                    id: label
                    visible: !row.editing
                    anchors { left: check.right; leftMargin: 10; right: del.left; rightMargin: 6; verticalCenter: parent.verticalCenter }
                    text: row.modelData.text; elide: Text.ElideRight
                    color: row.modelData.done ? Colors.islandFgVar : Colors.islandFg
                    font.family: Theme.fontUi; font.pixelSize: 13; font.strikeout: row.modelData.done
                    opacity: row.modelData.done ? 0.6 : 1
                    MouseArea {
                        anchors.fill: parent
                        onDoubleClicked: { row.editing = true; editor.text = row.modelData.text; editor.forceActiveFocus(); editor.selectAll() }
                    }
                }
                TextInput {
                    id: editor
                    visible: row.editing
                    anchors { left: check.right; leftMargin: 10; right: del.left; rightMargin: 6; verticalCenter: parent.verticalCenter }
                    font.family: Theme.fontUi; font.pixelSize: 13; color: Colors.islandFg
                    selectionColor: Colors.islandPrimary; selectedTextColor: Colors.islandOnPrimary
                    clip: true
                    function finish(save) { if (!row.editing) return; row.editing = false; if (save) Todo.edit(row.modelData.id, text); input.forceActiveFocus() }
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Escape) finish(false)
                        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) finish(true)
                        else return
                        event.accepted = true
                    }
                    onActiveFocusChanged: if (!activeFocus) finish(true)
                }
                Item {
                    id: del
                    anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter }
                    width: 24; height: 24
                    opacity: rowHover.hovered ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Theme.durationShort } }
                    Text {
                        anchors.centerIn: parent; text: "close"; font.family: Theme.fontIcon; font.pixelSize: 16
                        color: delHit.containsMouse ? Colors.islandError : Colors.islandFgVar
                    }
                    MouseArea {
                        id: delHit
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        Accessible.role: Accessible.Button; Accessible.name: "Delete " + row.modelData.text
                        onClicked: Todo.remove(row.modelData.id)
                    }
                }
            }
            Text {
                anchors.centerIn: parent
                visible: list.count === 0
                text: "No tasks"; color: Colors.islandFgVar
                font.family: Theme.fontUi; font.pixelSize: 13
            }
        }

        Item {
            id: foot
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: Todo.done > 0 ? 22 : 0
            visible: Todo.done > 0
            Text {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                text: "Clear completed (" + Todo.done + ")"
                color: clearHit.containsMouse ? Colors.islandFg : Colors.islandFgVar
                font.family: Theme.fontUi; font.pixelSize: 12; font.weight: Font.Medium
                MouseArea {
                    id: clearHit
                    anchors.fill: parent; anchors.margins: -4; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    Accessible.role: Accessible.Button; Accessible.name: "Clear completed tasks"
                    onClicked: Todo.clearDone()
                }
            }
        }
    }
}
