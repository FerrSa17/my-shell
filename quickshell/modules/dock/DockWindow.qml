import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.config
import qs.services

// The dock along one edge of a screen (dock.position: bottom, top, left or right): pinned apps, then
// the other running ones after a divider. A dot on the edge side of an icon marks a running app
// (hollow when all its windows are minimised), a badge counts its windows. Left click launches,
// minimises the focused window or brings one back (Dock.activate); hovering an app with several
// windows shows them stacked out from its icon (DockStack), and the stack stays while the pointer is
// on the icon or on it; middle click opens a new window; right click opens the menu. With
// dock.autohide the dock slides away and returns when the pointer rests on the screen edge
// (dock.showDelay), leaving after dock.hideDelay. The window is fixed-size and only the dock body
// (and an open menu or stack) takes input.
Scope {
    id: scope
    required property ShellScreen modelData
    readonly property bool enabled: Settings.modules.dock !== false
    readonly property var cfg: Settings.data.dock || ({})
    readonly property string edge: ["top", "left", "right"].indexOf(cfg.position) >= 0 ? cfg.position : "bottom"
    readonly property bool vertical: edge === "left" || edge === "right"
    readonly property int icon: cfg.iconSize || 44
    readonly property bool autohide: cfg.autohide === true
    readonly property int pad: 8
    // Gap to the screen edge; at the top it also clears the island's reserved band.
    readonly property int margin: (cfg.margin !== undefined ? cfg.margin : 8)
        + (edge === "top" && Settings.island.mode === "reserve" ? (Settings.island.reserve !== undefined ? Settings.island.reserve : 40) : 0)
    readonly property int spacing: cfg.spacing !== undefined ? cfg.spacing : 6
    // The body's size across the edge (the icon plus padding and the dot's lane).
    readonly property int thick: icon + pad * 2 + 6
    // Room beside the body for tooltips, the menu and the stack (input only where they show).
    readonly property int room: vertical ? 320 : 480
    readonly property var hyprMonitor: Hyprland.monitorFor(modelData)
    readonly property bool fullscreen: !!(hyprMonitor && hyprMonitor.activeWorkspace && hyprMonitor.activeWorkspace.hasFullscreen)
    property var menuApp: null
    property point menuAt: Qt.point(0, 0)
    readonly property bool menuOpen: menuApp !== null
    // The open stack, by app id: Dock.apps is rebuilt on every window change, so it is looked up live
    // and closes by itself once the app is down to one window.
    property string stackId: ""
    property point stackAt: Qt.point(0, 0)
    readonly property var stackApp: stackId === "" ? null : (Dock.apps.find(a => a.id === stackId && a.windows.length > 1) || null)
    readonly property bool stackOpen: stackApp !== null
    readonly property bool popupOpen: menuOpen || stackOpen
    // Hover in/out of an icon or the stack: open at once, close after a short grace so the pointer can
    // cross the gap between the icon and the stack.
    function hoverApp(app, on, at) {
        if (on) {
            stackOff.stop()
            if (!menuOpen && dragIndex < 0 && app.windows.length > 1) { stackAt = at; stackId = app.id } else stackId = ""
        } else stackOff.restart()
    }
    property Timer stackOff: Timer { interval: 280; onTriggered: scope.stackId = "" }

    // Dragging a pinned icon: its index, where it would land, how far the pointer moved, and whether
    // the button is still held. After the drop the state stays until the pinned list has been
    // rewritten (Dock.apps changes), so the icons wait in their new places instead of jumping back.
    property int dragIndex: -1
    property int dragTarget: -1
    property real dragDelta: 0
    property bool dragActive: false
    readonly property real dragStep: icon + spacing
    function dragOffset(index) {
        if (dragIndex < 0) return 0
        if (index === dragIndex) return dragActive ? dragDelta : (dragTarget - dragIndex) * dragStep
        if (dragIndex < dragTarget && index > dragIndex && index <= dragTarget) return -dragStep
        if (dragIndex > dragTarget && index < dragIndex && index >= dragTarget) return dragStep
        return 0
    }
    function dragStop() { dragIndex = -1; dragTarget = -1; dragDelta = 0; dragActive = false }
    Connections { target: Dock; function onAppsChanged() { if (!scope.dragActive) scope.dragStop() } }

    // A popup of size (w, h) next to the body, centred on `at` along the edge and kept on screen.
    function popupPos(w, h, at, gap, bodyItem, win) {
        const W = win.width, H = win.height
        if (vertical) {
            const y = Math.max(8, Math.min(H - h - 8, at.y - h / 2))
            return Qt.point(edge === "left" ? bodyItem.x + bodyItem.width + gap : bodyItem.x - w - gap, y)
        }
        const x = Math.max(8, Math.min(W - w - 8, at.x - w / 2))
        return Qt.point(x, edge === "top" ? bodyItem.y + bodyItem.height + gap : Math.max(8, bodyItem.y - h - gap))
    }

    LazyLoader {
        active: scope.enabled
        PanelWindow {
            id: win
            // Autohide: the edge strip reveals after dock.showDelay; leaving keeps it dock.hideDelay.
            property bool edgeHeld: false
            readonly property bool revealed: !scope.fullscreen && (!scope.autohide || edgeHeld || bodyHover.hovered || scope.popupOpen || grace.running)
            screen: scope.modelData
            anchors {
                top: scope.edge !== "bottom"; bottom: scope.edge !== "top"
                left: scope.edge !== "right"; right: scope.edge !== "left"
            }
            implicitHeight: scope.vertical ? 0 : scope.thick + scope.margin + scope.room
            implicitWidth: scope.vertical ? scope.thick + scope.margin + scope.room : 0
            exclusionMode: ExclusionMode.Normal
            exclusiveZone: scope.autohide ? 0 : scope.thick + (scope.cfg.margin !== undefined ? scope.cfg.margin : 8)
            color: "transparent"
            WlrLayershell.namespace: "dock"
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            mask: Region {
                item: win.revealed ? body : edgeZone
                Region { item: scope.menuOpen ? menu : null }
                Region { item: scope.stackOpen ? stack : null }
            }

            // A click anywhere off the menu closes it.
            HyprlandFocusGrab { windows: [win]; active: scope.menuOpen; onCleared: scope.menuApp = null }

            Item {
                id: edgeZone
                x: scope.edge === "right" ? parent.width - width : 0
                y: scope.edge === "bottom" ? parent.height - height : 0
                width: scope.vertical ? 2 : parent.width
                height: scope.vertical ? parent.height : 2
                HoverHandler { id: edge; onHoveredChanged: hovered ? showTimer.restart() : showTimer.stop() }
            }
            Timer { id: showTimer; interval: Math.max(1, scope.cfg.showDelay || 0); onTriggered: win.edgeHeld = true }
            Timer { id: grace; interval: scope.cfg.hideDelay !== undefined ? scope.cfg.hideDelay : 300; onTriggered: if (!edge.hovered) win.edgeHeld = false }

            // dock.shadow: a soft shadow under the body.
            RectangularShadow {
                anchors.fill: body
                visible: scope.cfg.shadow === true && body.visible
                radius: body.radius; blur: 24; spread: 1; offset: Qt.vector2d(0, 6)
                color: Qt.rgba(0, 0, 0, 0.55)
            }
            Rectangle {
                id: body
                // Centred along the edge; across it, at the margin when shown, just past the edge when not.
                readonly property real inset: win.revealed ? scope.margin : -scope.thick - 2
                x: scope.vertical ? (scope.edge === "left" ? inset : parent.width - width - inset) : (parent.width - width) / 2
                y: scope.vertical ? (parent.height - height) / 2 : (scope.edge === "top" ? inset : parent.height - height - inset)
                Behavior on x { enabled: scope.vertical; NumberAnimation { duration: Theme.durationNormal; easing.type: Easing.OutCubic } }
                Behavior on y { enabled: !scope.vertical; NumberAnimation { duration: Theme.durationNormal; easing.type: Easing.OutCubic } }
                width: scope.vertical ? scope.thick : grid.implicitWidth + scope.pad * 2
                height: scope.vertical ? grid.implicitHeight + scope.pad * 2 : scope.thick
                Behavior on width { enabled: !scope.vertical; NumberAnimation { duration: Theme.durationNormal; easing.type: Easing.OutCubic } }
                Behavior on height { enabled: scope.vertical; NumberAnimation { duration: Theme.durationNormal; easing.type: Easing.OutCubic } }
                // dock.radius, dock.opacity, dock.border: the island's black and hairline by default.
                radius: scope.cfg.radius !== undefined ? scope.cfg.radius : 20
                color: Qt.rgba(0, 0, 0, (scope.cfg.opacity !== undefined ? scope.cfg.opacity : 100) / 100)
                border.width: scope.cfg.border === false ? 0 : 1; border.color: Qt.rgba(1, 1, 1, 0.06)
                HoverHandler { id: bodyHover; onHoveredChanged: if (!hovered) grace.restart() }

                Grid {
                    id: grid
                    x: scope.pad; y: scope.pad
                    flow: scope.vertical ? Grid.TopToBottom : Grid.LeftToRight
                    columns: scope.vertical ? 1 : Math.max(1, Dock.apps.length)
                    rows: scope.vertical ? Math.max(1, Dock.apps.length) : 1
                    columnSpacing: scope.spacing; rowSpacing: scope.spacing
                    Repeater {
                        model: Dock.apps
                        delegate: Item {
                            id: slot
                            z: scope.dragIndex === index ? 10 : 0
                            required property var modelData
                            required property int index
                            // The divider between the pinned apps and the other running ones (dock.separator).
                            readonly property bool divider: scope.cfg.separator !== false && !modelData.pinned && index > 0 && Dock.apps[index - 1].pinned
                            implicitWidth: scope.vertical ? item.width : item.width + (divider ? 1 + scope.spacing : 0)
                            implicitHeight: scope.vertical ? item.height + (divider ? 1 + scope.spacing : 0) : item.height
                            Rectangle {
                                visible: slot.divider
                                width: scope.vertical ? scope.icon - 8 : 1; height: scope.vertical ? 1 : scope.icon - 8
                                x: scope.vertical ? 4 + (scope.edge === "right" ? 6 : 0) : 0; y: scope.vertical ? 0 : 4
                                color: Qt.rgba(1, 1, 1, 0.14)
                            }
                            DockItem {
                                id: item
                                x: !scope.vertical && slot.divider ? 1 + scope.spacing : 0
                                y: scope.vertical && slot.divider ? 1 + scope.spacing : 0
                                app: slot.modelData; size: scope.icon; edge: scope.edge
                                magnify: scope.cfg.magnify !== false; zoom: (scope.cfg.zoom || 114) / 100
                                labels: scope.cfg.labels !== false; indicators: scope.cfg.indicators !== false
                                dotColor: Colors.pick(scope.cfg.dotColor, Colors.islandFg)
                                windowCount: scope.cfg.windowCount !== false
                                stacked: scope.stackId === slot.modelData.id && scope.stackOpen
                                reorderable: slot.modelData.pinned
                                offset: scope.dragOffset(slot.index)
                                onDragMoved: delta => {
                                    if (scope.dragIndex < 0) { scope.stackId = ""; scope.dragIndex = slot.index; scope.dragActive = true }
                                    // The icon stays within the pinned icons, even if the pointer leaves the dock.
                                    scope.dragDelta = Math.max(-slot.index * scope.dragStep, Math.min((Dock.pinnedCount - 1 - slot.index) * scope.dragStep, delta))
                                    scope.dragTarget = Math.max(0, Math.min(Dock.pinnedCount - 1, Math.round(slot.index + delta / scope.dragStep)))
                                }
                                onDragEnded: {
                                    scope.dragActive = false
                                    if (scope.dragTarget === scope.dragIndex) scope.dragStop()
                                    else Dock.movePinnedTo(slot.modelData.id, scope.dragTarget)
                                }
                                onMenu: at => { scope.stackId = ""; scope.menuAt = mapToItem(win.contentItem, at.x, at.y); scope.menuApp = slot.modelData }
                                onHover: (on, at) => scope.hoverApp(slot.modelData, on, mapToItem(win.contentItem, at.x, at.y))
                            }
                        }
                    }
                }
            }

            Loader {
                id: stack
                active: scope.stackOpen
                width: 240; height: item ? item.height : 0
                readonly property point pos: scope.popupPos(width, height, scope.stackAt, 4, body, win)
                x: pos.x; y: pos.y
                sourceComponent: DockStack { app: scope.stackApp; edge: scope.edge; onDone: scope.stackId = "" }
                // The stack keeps itself open while the pointer is on it.
                HoverHandler { onHoveredChanged: hovered ? scope.stackOff.stop() : scope.stackOff.restart() }
            }

            DockMenu {
                id: menu
                visible: scope.menuOpen
                app: scope.menuApp
                readonly property point pos: scope.popupPos(width, height, scope.menuAt, 8, body, win)
                x: pos.x; y: pos.y
                onDone: scope.menuApp = null
            }
        }
    }
}
