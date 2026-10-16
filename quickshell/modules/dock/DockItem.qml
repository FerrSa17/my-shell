import QtQuick
import qs.config
import qs.services

// One app in the dock: its icon (lifted away from the screen edge and enlarged under the pointer,
// with the name beside it), a dot on the edge side while it runs (hollow when every window is
// minimised) and a badge with the window count when there are several. `edge` is the dock's screen
// edge (bottom, top, left, right). menu(at) asks the dock for the context menu at `at` (item
// coordinates); hover(on, at) tells it the pointer came or went, so an app with several windows
// shows its stack. `stacked` (that stack is open) hides the name. A pinned app (`reorderable`) can be
// dragged along the dock: dragMoved(delta) reports how far (px) while the button is held and
// dragEnded() the drop; `offset` is where the dock wants the icon shifted, in px along the dock.
Item {
    id: root
    property var app: null
    property int size: 44
    property string edge: "bottom"
    property bool stacked: false
    // dock.magnify / dock.zoom / dock.labels / dock.indicators / dock.dotColor / dock.windowCount.
    property bool magnify: true
    property real zoom: 1.14
    property bool labels: true
    property bool indicators: true
    property color dotColor: Colors.islandFg
    property bool windowCount: true
    property bool reorderable: false
    property real offset: 0
    property bool dragged: false
    signal menu(point at)
    signal hover(bool on, point at)
    signal dragMoved(real delta)
    signal dragEnded()
    readonly property bool vertical: edge === "left" || edge === "right"
    readonly property bool running: !!app && app.windows.length > 0
    readonly property bool allMinimized: running && app.minimizedCount === app.windows.length
    readonly property point centre: Qt.point(width / 2, height / 2)
    width: vertical ? size + 6 : size; height: vertical ? size : size + 6

    // Shifted along the dock by `offset`: the dragged icon follows the pointer, the ones it passes
    // slide aside (animated; the dragged icon itself is not, it must stay under the pointer).
    transform: Translate { x: root.vertical ? 0 : root.offset; y: root.vertical ? root.offset : 0 }
    Behavior on offset { enabled: !root.dragged; NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
    opacity: dragged ? 0.9 : 1

    // The icon is decoded once at twice the largest size (crisp on HiDPI too) and drawn at its real
    // pixel size: the hover grows the item itself rather than scaling a bitmap, which would blur it.
    readonly property bool lifted: hit.containsMouse && magnify
    readonly property int shown: Math.round(root.size * (dragged ? zoom : hit.pressed ? 0.92 : lifted ? zoom : 1))
    // How far the icon sits from the dot's side: the 6 px dot lane, plus the lift under the pointer.
    property real away: 6 + (lifted ? 4 : 0)
    Behavior on away { NumberAnimation { duration: Theme.durationShort; easing.type: Easing.OutCubic } }
    Image {
        id: img
        width: root.shown; height: root.shown
        Behavior on width { NumberAnimation { duration: Theme.durationShort; easing.type: Easing.OutCubic } }
        Behavior on height { NumberAnimation { duration: Theme.durationShort; easing.type: Easing.OutCubic } }
        x: root.vertical ? (root.edge === "left" ? root.away : root.width - width - root.away) : (root.width - width) / 2
        y: root.vertical ? (root.height - height) / 2 : (root.edge === "top" ? root.away : root.height - height - root.away)
        source: root.app ? root.app.icon : ""
        sourceSize: Qt.size(Math.round(root.size * 1.5 * 2), Math.round(root.size * 1.5 * 2))
        fillMode: Image.PreserveAspectFit
        smooth: true; mipmap: true; asynchronous: true
        opacity: root.allMinimized ? 0.75 : 1
    }
    // The run dot, on the screen-edge side; a short bar for the active app.
    Rectangle {
        visible: root.running && root.indicators
        readonly property real len: root.app && root.app.active ? 10 : 4
        width: root.vertical ? 4 : len; height: root.vertical ? len : 4; radius: 2
        x: root.vertical ? (root.edge === "left" ? 0 : root.width - 4) : (root.width - width) / 2
        y: root.vertical ? (root.height - height) / 2 : (root.edge === "top" ? 0 : root.height - 4)
        color: root.allMinimized ? "transparent" : root.dotColor
        border.width: root.allMinimized ? 1 : 0; border.color: Colors.islandFgVar
        Behavior on width { NumberAnimation { duration: Theme.durationShort } }
        Behavior on height { NumberAnimation { duration: Theme.durationShort } }
    }
    // How many windows the app has, on the icon's corner away from the edge.
    Rectangle {
        visible: root.windowCount && root.running && root.app.windows.length > 1
        width: Math.max(16, count.implicitWidth + 8); height: 16; radius: 8
        x: img.x + img.width - width + 4; y: root.edge === "top" ? img.y + img.height - height + 4 : img.y - 4
        color: Colors.islandPrimary
        Text { id: count; anchors.centerIn: parent; text: root.app ? root.app.windows.length : ""
            color: Colors.islandOnPrimary; font.family: Theme.fontUi; font.pixelSize: 10; font.weight: Font.Bold }
    }
    // The name beside the icon (away from the edge) while hovered.
    Rectangle {
        visible: root.labels && hit.containsMouse && !hit.pressed && !root.stacked
        width: tip.implicitWidth + 20; height: 26; radius: 13
        x: root.vertical ? (root.edge === "left" ? img.x + img.width + 12 : img.x - width - 12) : (root.width - width) / 2
        y: root.vertical ? (root.height - height) / 2 : (root.edge === "top" ? img.y + img.height + 12 : img.y - height - 12)
        color: "#000000"
        border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.06)
        Text {
            id: tip
            anchors.centerIn: parent
            text: root.app ? root.app.name : ""
            color: Colors.islandFg; font.family: Theme.fontUi; font.pixelSize: 12; font.weight: Font.Medium
        }
    }
    MouseArea {
        id: hit
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onContainsMouseChanged: root.hover(containsMouse, root.centre)
        Accessible.role: Accessible.Button; Accessible.name: root.app ? root.app.name : ""
        // A left drag along the dock (past 8 px) reorders a pinned app; the click that ends it is not a click.
        property real pressAt: 0
        property bool moved: false
        function along(mouse) { const p = hit.mapToItem(null, mouse.x, mouse.y); return root.vertical ? p.y : p.x }
        onPressed: mouse => { if (mouse.button === Qt.LeftButton) { pressAt = along(mouse); moved = false } }
        onPositionChanged: mouse => {
            if (!root.reorderable || !pressed || !(pressedButtons & Qt.LeftButton)) return
            const d = along(mouse) - pressAt
            if (!root.dragged && Math.abs(d) > 8) { root.dragged = true; moved = true }
            if (root.dragged) root.dragMoved(d)
        }
        onReleased: if (root.dragged) { root.dragged = false; root.dragEnded() }
        onCanceled: if (root.dragged) { root.dragged = false; root.dragEnded() }
        onClicked: mouse => {
            if (!root.app || moved) { moved = false; return }
            if (mouse.button === Qt.RightButton) root.menu(root.centre)
            else if (mouse.button === Qt.MiddleButton) Dock.launch(root.app)
            else Dock.activate(root.app)
        }
    }
}
