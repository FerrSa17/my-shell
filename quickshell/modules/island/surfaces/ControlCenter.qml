import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.services as Svc
import "../cc"

// Control center surface, 560 wide on a 12 px grid, as tall as what it shows (Sizes.ccMainH): the
// date, the media card while a player exists, tiles from layout.cc.tiles (Composer), volume and
// microphone with the Wallpapers, Clipboard, Settings and power buttons, the system load; then the
// notifications. layout.cc.{sliders, media, power, system, weather} switch those sections off. Esc asks the host to close it.
FocusScope {
    id: cc
    // The panel grows downward by the notifications section (capped; it scrolls beyond that).
    readonly property real notifH: Sizes.ccNotifH
    readonly property size size: Sizes.ccFull
    signal openWallpapers()
    signal openSettings()
    signal openCalendar()
    signal openClipboard()
    signal closeRequested()
    focus: true
    Keys.onEscapePressed: closeRequested()

    // Swallow clicks on empty space so they do not collapse the island.
    MouseArea { anchors.fill: parent }

    ColumnLayout {
        id: mainPage
        objectName: "mainPage"
        anchors { top: parent.top; left: parent.left; right: parent.right; margins: 12 }
        height: Sizes.ccMainH - 24; spacing: 12

        // The media card only while a player exists (layout.cc.media on); the panel is shorter without it.
        // The date, large, with the weekday above it (a click opens the calendar), and the weather in
        // Saint Petersburg at the right end (a click refreshes it).
        Item {
            Layout.fillWidth: true; Layout.preferredHeight: Sizes.ccDateH
            SystemClock { id: today; precision: SystemClock.Minutes }
            Binding { target: Svc.Weather; property: "active"; value: Composer.weather }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                Text { text: Qt.formatDate(today.date, "dddd"); color: Colors.islandPrimary
                    font.family: Theme.fontUi; font.pixelSize: 12; font.weight: Font.DemiBold }
                Text { text: Qt.formatDate(today.date, Settings.island.dateFormat || "d MMMM yyyy"); color: Colors.islandFg
                    font.family: Theme.fontDisplay; font.pixelSize: 22; font.weight: Font.DemiBold }
            }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: cc.openCalendar()
                Accessible.role: Accessible.Button; Accessible.name: "Calendar" }
            Item {
                visible: Composer.weather && Svc.Weather.ready
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                width: weatherRow.width; height: weatherRow.height
                Row {
                    id: weatherRow
                    spacing: 8
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        Text { anchors.right: parent.right; text: Svc.Weather.tempText; color: Colors.islandFg
                            font.family: Theme.fontDisplay; font.pixelSize: 22; font.weight: Font.DemiBold }
                        Text { anchors.right: parent.right; text: Svc.Weather.description; color: Colors.islandFgVar
                            font.family: Theme.fontUi; font.pixelSize: 11 }
                    }
                    Text { anchors.verticalCenter: parent.verticalCenter; text: Svc.Weather.glyph; color: Colors.islandPrimary
                        font.family: Theme.fontIcon; font.pixelSize: 30 }
                }
                MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: Svc.Weather.refresh(true)
                    Accessible.role: Accessible.Button; Accessible.name: "Weather in Saint Petersburg, " + Svc.Weather.tempText + ", " + Svc.Weather.description }
            }
        }
        MediaRow { id: media; Layout.fillWidth: true; Layout.preferredHeight: 44; visible: Sizes.ccMedia }

        // Tiles in layout.cc.tiles order on a 4-column grid: a 2x1 tile spans two columns, a tile
        // that does not fit the rest of a row starts the next one. Rows share the height left over by
        // the other sections (56 px each at most, 28 at least; the surface never grows).
        Item {
            id: grid
            objectName: "ccGrid"
            Layout.fillWidth: true; Layout.fillHeight: true; Layout.minimumHeight: 28
            Layout.preferredHeight: rows * 56 + Math.max(0, rows - 1) * rowGap; Layout.maximumHeight: Layout.preferredHeight
            clip: true
            readonly property int gap: 12
            readonly property real colW: (width - 3 * gap) / 4
            readonly property var placed: {
                const out = []; let r = 0, c = 0
                for (const t of Composer.tilesShown) {
                    const span = t.size === "2x1" ? 2 : 1
                    if (c + span > 4) { r++; c = 0 }
                    out.push({ id: t.id, span: span, row: r, col: c })
                    c += span
                }
                return out
            }
            readonly property int rows: placed.length ? placed[placed.length - 1].row + 1 : 0
            readonly property real rowGap: rows > 2 ? 8 : gap
            visible: rows > 0
            readonly property real tileH: rows ? Math.max(28, Math.min(56, (height - (rows - 1) * rowGap) / rows)) : 0
            Repeater {
                model: grid.placed
                delegate: Loader {
                    required property var modelData
                    objectName: "ccTile_" + modelData.id
                    x: modelData.col * (grid.colW + grid.gap); y: modelData.row * (grid.tileH + grid.rowGap)
                    width: modelData.span * grid.colW + (modelData.span - 1) * grid.gap; height: grid.tileH
                    sourceComponent: cc.tileComps[modelData.id] || null
                    onLoaded: item.compact = Qt.binding(() => modelData.span === 1 || grid.tileH < 44)
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true; Layout.preferredHeight: 32; spacing: 12
            visible: Composer.sliders || Composer.power
            Slider {
                visible: Composer.sliders
                Layout.fillWidth: true; Layout.minimumWidth: 90; Layout.preferredWidth: 150; Layout.alignment: Qt.AlignVCenter
                objectName: "volumeSlider"; label: "Volume"; icon: Svc.Audio.muted ? "volume_off" : "volume_up"; value: Svc.Audio.volume
                onMoved: v => Svc.Audio.setVolume(v)
            }
            Slider {
                visible: Composer.sliders
                Layout.fillWidth: true; Layout.minimumWidth: 90; Layout.preferredWidth: 150; Layout.alignment: Qt.AlignVCenter
                objectName: "micSlider"; label: "Microphone"; icon: Svc.Audio.micMuted ? "mic_off" : "mic"
                value: Svc.Audio.micMuted ? 0 : Svc.Audio.micVolume
                onMoved: v => Svc.Audio.setMicVolume(v)
            }
            Item { visible: !Composer.sliders; Layout.fillWidth: true }
            // Wallpapers and Settings sit with the round buttons.
            Rectangle {
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: wallRow.implicitWidth + 24; implicitHeight: 32; radius: 16
                color: wallHit.containsMouse ? Colors.islandSurfaceHighest : Colors.islandSurfaceHigh
                Row {
                    id: wallRow; anchors.centerIn: parent; spacing: 6
                    Text { anchors.verticalCenter: parent.verticalCenter; text: "wallpaper"; color: Colors.islandFg; font.family: Theme.fontIcon; font.pixelSize: 18 }
                    Text { anchors.verticalCenter: parent.verticalCenter; text: "Обои"; color: Colors.islandFg; font.family: Theme.fontUi; font.pixelSize: 12; font.weight: Font.Medium }
                }
                MouseArea { id: wallHit; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: cc.openWallpapers()
                    Accessible.role: Accessible.Button; Accessible.name: "Wallpapers" }
            }
            // The clipboard history, then the settings window.
            Rectangle {
                Layout.alignment: Qt.AlignVCenter
                width: 32; height: 32; radius: 16
                color: clipHit.containsMouse ? Colors.islandSurfaceHighest : Colors.islandSurfaceHigh
                Text { anchors.centerIn: parent; text: "content_paste"; color: Colors.islandFg; font.family: Theme.fontIcon; font.pixelSize: 18 }
                MouseArea { id: clipHit; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: cc.openClipboard()
                    Accessible.role: Accessible.Button; Accessible.name: "Clipboard history" }
            }
            // Settings: the centred settings window.
            Rectangle {
                Layout.alignment: Qt.AlignVCenter
                width: 32; height: 32; radius: 16
                color: gearHit.containsMouse ? Colors.islandSurfaceHighest : Colors.islandSurfaceHigh
                Text { anchors.centerIn: parent; text: "settings"; color: Colors.islandFg; font.family: Theme.fontIcon; font.pixelSize: 18 }
                MouseArea { id: gearHit; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: cc.openSettings()
                    Accessible.role: Accessible.Button; Accessible.name: "Settings" }
            }
            PowerRow { visible: Composer.power; Layout.alignment: Qt.AlignVCenter | Qt.AlignRight }
        }

        // System load (layout.cc.system): processor, memory, disk and the network speed.
        Row {
            visible: Composer.system
            Layout.fillWidth: true; Layout.preferredHeight: 40; spacing: 8
            Binding { target: Svc.Sys; property: "active"; value: Composer.system }
            Repeater {
                model: [
                    { glyph: "speed", label: "CPU", value: Svc.Sys.cpu, text: Math.round(Svc.Sys.cpu * 100) + "%" },
                    { glyph: "memory", label: "RAM", value: Svc.Sys.mem, text: Math.round(Svc.Sys.mem * 100) + "%" },
                    { glyph: "hard_drive", label: "Disk", value: Svc.Sys.disk, text: Math.round(Svc.Sys.disk * 100) + "%" },
                    { glyph: "swap_vert", label: "Net", value: -1, text: "↓" + Svc.Net.rate(Svc.Net.rxRate) }]
                delegate: Rectangle {
                    required property var modelData
                    width: (parent.width - 3 * parent.spacing) / 4; height: 40; radius: 12
                    color: Colors.islandSurfaceHigh
                    Text { x: 10; anchors.verticalCenter: parent.verticalCenter; text: parent.modelData.glyph
                        color: Colors.islandFgVar; font.family: Theme.fontIcon; font.pixelSize: 18 }
                    Column {
                        x: 36; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 44; spacing: 2
                        Text { text: parent.parent.modelData.text; color: Colors.islandFg; elide: Text.ElideRight; width: parent.width
                            font.family: Theme.fontUi; font.pixelSize: 13; font.weight: Font.DemiBold; font.features: { "tnum": 1 } }
                        Rectangle {
                            visible: parent.parent.modelData.value >= 0
                            width: parent.width; height: 3; radius: 1.5; color: Colors.alpha(Colors.islandFg, 0.14)
                            Rectangle {
                                width: parent.width * Math.min(1, parent.parent.parent.modelData.value); height: parent.height; radius: parent.radius
                                color: parent.parent.parent.modelData.value > 0.85 ? Colors.islandError : Colors.islandPrimary
                                Behavior on width { NumberAnimation { duration: Theme.durationNormal; easing.type: Easing.OutCubic } }
                            }
                        }
                        Text { visible: parent.parent.modelData.value < 0; text: "↑" + Svc.Net.rate(Svc.Net.txRate)
                            color: Colors.islandFgVar; font.family: Theme.fontUi; font.pixelSize: 11; font.features: { "tnum": 1 } }
                    }
                }
            }
        }
    }
    // --- tiles (ids from Composer.tileIds) ---
    readonly property var tileComps: ({ network: networkTile, dnd: dndTile })
    // The wired network: live traffic, the VPN when one is up, and a click copies the local address.
    property bool ipCopied: false
    Timer { id: ipCopiedOff; interval: 1600; onTriggered: cc.ipCopied = false }
    Component {
        id: networkTile
        Toggle {
            toggle: false; checked: Svc.Net.connected
            icon: !Svc.Net.connected ? "lan" : Svc.Net.vpn ? "vpn_lock" : "lan"
            label: !Svc.Net.connected ? "Ethernet" : Svc.Net.vpn ? "Ethernet · VPN" : "Ethernet"
            subtitle: !Svc.Net.connected ? "Cable unplugged" : cc.ipCopied ? "Copied " + Svc.Net.ip
                : "↓ " + Svc.Net.rate(Svc.Net.rxRate) + "   ↑ " + Svc.Net.rate(Svc.Net.txRate)
            onClicked: if (Svc.Net.ip) { Quickshell.execDetached(["wl-copy", "--", Svc.Net.ip]); cc.ipCopied = true; ipCopiedOff.restart() }
        }
    }
    Component {
        id: dndTile
        Toggle {
            objectName: "dndToggle"
            icon: Svc.Notifs.quiet ? "notifications_off" : "notifications"; label: "Do not disturb"
            subtitle: Svc.Notifs.dnd ? "On" : Svc.Notifs.scheduledQuiet ? "Scheduled until " + (Svc.Notifs.cfg.dndTo || "08:00") : "Off"
            checked: Svc.Notifs.dnd
            onClicked: Svc.Notifs.dnd = !Svc.Notifs.dnd
        }
    }
    // Notifications under the main page, behind a hairline.
    Rectangle {
        y: Sizes.ccMainH; x: 12; width: parent.width - 24; height: 1
        color: Qt.rgba(1, 1, 1, 0.08)
    }
    Notifications {
        id: notifs
        objectName: "ccNotifications"
        y: Sizes.ccMainH + 1; width: parent.width; height: cc.notifH
        host: Svc.Notifs
    }
}
