pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.config as Cfg // State: QtQuick has a State type

// `qs ipc call shell <function>`: what the Hyprland binds drive.
Singleton {
    id: root
    // Modules register themselves here so IPC can reach them without import cycles.
    property var island: null
    // The settings window (modules/settings), centred on the focused screen.
    property bool settingsOpen: false
    // Islands by screen name. `island` (what IPC, OSD and notifications drive) is the one on the focused
    // monitor; an expanded island keeps the role until it collapses, so it never jumps between screens.
    property var islands: ({})
    function registerIsland(name, isl) { const m = Object.assign({}, islands); m[name] = isl; islands = m; pick() }
    function unregisterIsland(name) { const m = Object.assign({}, islands); delete m[name]; islands = m; pick() }
    function pick() {
        if (island && island.surfaceOpen && Object.values(islands).indexOf(island) >= 0) return
        const names = Object.keys(islands)
        if (!names.length) { island = null; return }
        const n = islands[Hypr.focusedMonitorName] ? Hypr.focusedMonitorName
            : (Quickshell.screens.length && islands[Quickshell.screens[0].name] ? Quickshell.screens[0].name : names[0])
        if (island !== islands[n]) island = islands[n]
    }
    Connections { target: Hypr; function onFocusedMonitorNameChanged() { root.pick() } }

    IpcHandler {
        target: "shell"
        function reload(): void { Quickshell.reload(false) }
        function toggleControlCenter(): void { if (root.island) root.island.toggleExpanded() }
        function toggleLauncher(): void { root.toggle("launcher", { mode: "apps" }) }
        function showLauncher(mode: string): void { if (root.island) root.island.openSurface("launcher", { mode: mode || "apps" }) }
        function toggleWallpapers(): void { root.toggle("wallpapers") }
        function toggleSettings(): void { root.openSettings(!root.settingsOpen) }
        function toggleCalendar(): void { root.toggle("calendar") }
        function toggleMedia(): void { root.toggle("mediaSurface") }
        function toggleTodo(): void { root.toggle("todo") }
        function toggleClipboard(): void { root.toggle("clipboard") }
        function toggleTimer(): void { root.toggle("timer") }
        function closeSurface(): void { if (root.island) root.island.closeSurface() }
        function wallpaper(path: string): void { Cfg.State.setWallpaper(path, "") }
        function wallpaperRandom(): void { root.randomWallpaper() }
        function theme(name: string): void { root.setTheme(name) }
        function minimize(): void { Dock.minimizeActive() }
        function clearNotifications(): void { Notifs.clearAll() }
        function toggleDnd(): bool { Notifs.dnd = !Notifs.dnd; return Notifs.dnd }
        function timerStart(sec: int): void { Countdown.start(sec, "") }
        function timerStop(): void { Countdown.stop() }
        function settingsSet(key: string, json: string): void { try { Settings.set(key, JSON.parse(json)) } catch (e) { console.warn("settingsSet: bad json for " + key) } }
        function settingsReset(key: string): void { Settings.unset(key) }
    }
    function openSettings(on) {
        if (on && root.island) root.island.closeSurface()
        root.settingsOpen = on
    }
    function toggle(name, opts) { if (root.island) root.island.toggleSurface(name, opts) }


    // Themes are the folders of themes/ that hold a palette.
    property var themeNames: []
    function setTheme(name) { if (themeNames.indexOf(name) >= 0) Cfg.State.setTheme(name) }
    Process {
        running: true
        command: ["sh", "-c", 'for d in "$1"/*/; do [ -f "$d/colors.json" ] && basename "$d"; done', "sh", Paths.themes]
        stdout: StdioCollector { onStreamFinished: root.themeNames = text.trim().split("\n").filter(n => n) }
    }

    // The wallpaper grid: the current theme's own wallpapers first, then every image under
    // ~/Pictures/Wallpapers (the other themes' stay out of it).
    readonly property var wallpaperCmd: ["sh", "-c", 'for d in "$1" "$2"; do find "$d" -maxdepth 2 -type f \\( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.webp" \\) 2>/dev/null | sort -V; done',
        "sh", Paths.themes + "/" + Cfg.State.theme, Paths.wallpapers]
    // Super+C: a random wallpaper of the current theme (themes/<theme>/), never the one already set.
    function randomWallpaper() { if (!randomProc.running) randomProc.running = true }
    Process {
        id: randomProc
        command: ["sh", "-c", 'find "$1" -maxdepth 1 -type f \\( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.webp" \\)',
            "sh", Paths.themes + "/" + Cfg.State.theme]
        stdout: StdioCollector {
            onStreamFinished: {
                const l = text.trim().split("\n").filter(f => f && f !== Cfg.State.wallpaper)
                if (l.length) Cfg.State.setWallpaper(l[Math.floor(Math.random() * l.length)], "")
            }
        }
    }
    Component.onCompleted: Settings.data
}
