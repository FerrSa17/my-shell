pragma Singleton
import QtQuick
import Quickshell

// Declared island sizes per state: the pill morphs to these before the state's content
// loads, so the shape never waits on a layout. Widths sit on the 8 px grid (snap()); a state item may
// still report a different `size` (a tall notification) and the pill follows it once that item shows.
Singleton {
    id: root
    readonly property size rest: Qt.size(104, 36)
    // Up to this height the pill is a full capsule (the rest pill, the OSD, a notification).
    readonly property int capsuleMax: 44
    readonly property size media: Qt.size(424, 36)
    readonly property size mediaSurface: Qt.size(420, 200)
    readonly property size osd: Qt.size(304, 36)
    readonly property size notification: Qt.size(520, 36)
    readonly property size notificationTall: Qt.size(520, 56)
    readonly property size expanded: Qt.size(560, 304)
    readonly property size calendar: Qt.size(360, 300)
    readonly property size wallpapers: Qt.size(656, 320)
    readonly property size settings: Qt.size(660, 440)
    // The control center's notifications section grows up to this, then scrolls.
    readonly property int ccNotifMax: 400
    // The notifications section's height right now (capped), measured by the island (a hidden copy of
    // the list) so the control center's full size is known before it loads: one morph, not two.
    property real ccNotifH: 0
    // The main part's height, from what it shows (set by the island): 12 px margins, the date, the media card
    // while a player exists, the tile rows, the sliders and buttons row, 12 px between sections.
    property bool ccMedia: false
    readonly property int ccDateH: 44
    readonly property real ccMainH: {
        const parts = [ccDateH]
        if (ccMedia) parts.push(44)
        const rows = Composer.tileRows
        if (rows > 0) parts.push(rows * 56 + (rows - 1) * (rows > 2 ? 8 : 12))
        if (Composer.sliders || Composer.power) parts.push(32)
        if (Composer.system) parts.push(40)
        return 24 + parts.reduce((a, b) => a + b, 0) + Math.max(0, parts.length - 1) * 12
    }
    readonly property size ccFull: Qt.size(expanded.width, ccMainH + 1 + ccNotifH)
    readonly property size launcher: Qt.size(520, 300)
    readonly property size todo: Qt.size(420, 300)
    readonly property size clipboard: Qt.size(520, 340)
    readonly property size timer: Qt.size(360, 236)
    readonly property int radiusExpanded: 20

    function snap(w) { return Math.ceil(w / 8) * 8 }
    function of(name) {
        switch (name) {
        case "media": return media
        case "mediaSurface": return mediaSurface
        case "osd": return osd
        case "notification": return notification
        case "expanded": return ccFull
        case "calendar": return calendar
        case "wallpapers": return wallpapers
        case "launcher": return launcher
        case "todo": return todo
        case "clipboard": return clipboard
        case "timer": return timer
        default: return rest
        }
    }
    function area(s) { return s.width * s.height }
    // Pill corner radius for a size: a full capsule up to capsuleMax, a rounded panel above.
    function radiusFor(h) { return h <= capsuleMax ? h / 2 : radiusExpanded }
}
