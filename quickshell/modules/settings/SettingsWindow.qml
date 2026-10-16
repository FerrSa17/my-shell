import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services

// The settings window: a black panel (the island's look) in the middle of the focused screen over a
// dimmed backdrop, not part of the pill. Ipc.settingsOpen shows it (the control center's gear, the
// Settings tile, `qs ipc call shell toggleSettings`); Esc or a click on the backdrop closes it.
PanelWindow {
    id: win
    readonly property bool open: Ipc.settingsOpen
    // Mapped from the moment it opens until its fade-out has finished. (Binding visibility to the
    // fade animation's `running` unmapped the window for a frame before the fade began, so a close
    // flashed it back open.)
    property bool mapped: false
    onOpenChanged: { if (open) { unmap.stop(); mapped = true } else unmap.restart() }
    Timer { id: unmap; interval: Theme.durationNormal + 40; onTriggered: win.mapped = false }
    visible: mapped
    screen: Quickshell.screens.find(s => s.name === Hypr.focusedMonitorName) || Quickshell.screens[0]
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.namespace: "settings"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Rectangle {
        id: backdrop
        anchors.fill: parent
        color: "#000000"
        opacity: win.open ? 0.5 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.durationNormal; easing.type: Easing.OutCubic } }
        MouseArea { anchors.fill: parent; onClicked: Ipc.settingsOpen = false }
    }

    Rectangle {
        id: panel
        anchors.centerIn: parent
        width: Sizes.settings.width; height: Sizes.settings.height
        radius: Sizes.radiusExpanded
        color: "#000000"
        border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.06)
        opacity: win.open ? 1 : 0
        scale: win.open ? 1 : 0.94
        Behavior on opacity { NumberAnimation { duration: Theme.durationNormal; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: Theme.durationNormal; easing.type: Easing.OutCubic } }
        // Clicks inside the panel stay in it.
        MouseArea { anchors.fill: parent }

        Loader {
            anchors.fill: parent
            active: win.visible
            focus: true
            sourceComponent: SettingsPanel {
                focus: true
                warning: Notifs.passive ? "Another daemon owns org.freedesktop.Notifications; shell notifications are off." : ""
                onCloseRequested: Ipc.settingsOpen = false
                onOpenWallpapers: { Ipc.settingsOpen = false; if (Ipc.island) Ipc.island.openSurface("wallpapers") }
            }
            onLoaded: item.forceActiveFocus()
        }
    }
}
