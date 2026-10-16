pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.config

// What the dock shows: the pinned apps (settings dock.pinned, desktop entry ids) in their order,
// then every other running app, each with its windows. Minimising moves a window to the hidden
// special:minimized workspace (Hyprland has no minimised state of its own); restoring brings it
// back onto the focused workspace. With the Lua config, dispatch takes a Lua expression.
Singleton {
    id: root
    readonly property string special: "special:minimized"
    readonly property var pinned: Array.isArray(Settings.get("dock.pinned")) ? Settings.get("dock.pinned") : []
    // [{id, name, icon, pinned, entry, windows: [{address, title, minimized, activated}], active, minimizedCount}]
    property var apps: []

    function addr(t) { const a = String(t.address || ""); return a.startsWith("0x") ? a : "0x" + a }
    function classOf(t) {
        if (t.wayland && t.wayland.appId) return t.wayland.appId
        return (t.lastIpcObject && t.lastIpcObject.class) || ""
    }
    // A window's app: the desktop entry its class names, else the bare class.
    function entryFor(cls) { return cls ? (DesktopEntries.byId(cls) || DesktopEntries.heuristicLookup(cls)) : null }
    function iconFor(entry, id) { return Quickshell.iconPath(entry && entry.icon ? entry.icon : id.toLowerCase(), "application-x-executable") }

    function rebuild() {
        const groups = {}, order = []
        const make = (id, entry, pin) => ({
            id: id, entry: entry, pinned: pin,
            name: entry ? entry.name : id,
            icon: iconFor(entry, id), windows: []
        })
        for (const id of root.pinned) {
            const e = DesktopEntries.byId(id)
            groups[id.toLowerCase()] = make(id, e, true); order.push(id.toLowerCase())
        }
        for (const t of Hyprland.toplevels.values) {
            const cls = classOf(t)
            if (!t.address || !cls) continue
            const e = entryFor(cls)
            const id = e ? e.id : cls
            let key = id.toLowerCase()
            // A pinned id that is the window's class itself (or the entry's StartupWMClass).
            if (!groups[key]) for (const k of order) {
                const g = groups[k]
                if (k === cls.toLowerCase() || (g.entry && (g.entry.startupClass || "").toLowerCase() === cls.toLowerCase())) { key = k; break }
            }
            if (!groups[key]) { groups[key] = make(id, e, false); order.push(key) }
            groups[key].windows.push({
                address: addr(t), title: t.title || cls,
                minimized: !!(t.workspace && t.workspace.name === root.special),
                activated: t.activated
            })
        }
        const out = order.map(k => {
            const g = groups[k]
            g.active = g.windows.some(w => w.activated && !w.minimized)
            g.minimizedCount = g.windows.filter(w => w.minimized).length
            return g
        })
        root.apps = out
    }
    Timer { id: debounce; interval: 60; onTriggered: root.rebuild() }
    Connections { target: Hyprland.toplevels; function onValuesChanged() { debounce.restart() } }
    Connections { target: Hyprland; function onRawEvent(ev) { debounce.restart() } }
    Connections { target: DesktopEntries; function onApplicationsChanged() { debounce.restart() } }
    onPinnedChanged: debounce.restart()
    Component.onCompleted: rebuild()

    function dispatch(lua) { Hyprland.dispatch(lua) }
    function minimize(address) {
        dispatch("hl.dsp.window.move({ workspace = \"" + special + "\", window = \"address:" + address + "\", follow = false })")
        debounce.restart()
    }
    function restore(address) {
        dispatch("hl.dsp.window.move({ workspace = " + Hypr.focusedId + ", window = \"address:" + address + "\" })")
        focus(address)
    }
    function focus(address) { dispatch("hl.dsp.focus({ window = \"address:" + address + "\" })"); debounce.restart() }
    function close(address) { dispatch("hl.dsp.window.close({ window = \"address:" + address + "\" })") }
    function minimizeActive() {
        const t = Hyprland.activeToplevel
        if (t && !(t.workspace && t.workspace.name === special)) minimize(addr(t))
    }
    function launch(app) {
        if (app.entry) app.entry.execute()
        else Quickshell.execDetached([app.id])
    }
    // A click on an app: launch it; minimise its focused window; bring back a minimised one when
    // none is on screen; otherwise focus its next window (cycling on repeated clicks).
    function activate(app) {
        const ws = app.windows
        if (!ws.length) { launch(app); return }
        const cur = ws.find(w => w.activated && !w.minimized)
        const shown = ws.filter(w => !w.minimized)
        if (cur && shown.length === 1) { minimize(cur.address); return }
        if (!shown.length) { restore(ws[ws.length - 1].address); return }
        const i = cur ? shown.indexOf(cur) : -1
        focus(shown[(i + 1) % shown.length].address)
    }
    function restoreAll(app) { for (const w of app.windows) if (w.minimized) restore(w.address) }
    function closeAll(app) { for (const w of app.windows) close(w.address) }
    function setPinned(id, on) {
        const l = root.pinned.filter(p => p.toLowerCase() !== id.toLowerCase())
        if (on) l.push(id)
        Settings.set("dock.pinned", l)
    }
    // Drop a pinned app at slot `index` of the pinned list (a drag in the dock); the others close up.
    function movePinnedTo(id, index) {
        const l = root.pinned.slice(), i = l.findIndex(p => p.toLowerCase() === id.toLowerCase())
        if (i < 0 || index < 0 || index >= l.length || index === i) return
        const [moved] = l.splice(i, 1)
        l.splice(index, 0, moved)
        Settings.set("dock.pinned", l)
    }
    readonly property int pinnedCount: apps.filter(a => a.pinned).length
    function movePinned(id, dir) {
        const l = root.pinned.slice(), i = l.findIndex(p => p.toLowerCase() === id.toLowerCase()), j = i + dir
        if (i < 0 || j < 0 || j >= l.length) return
        const t = l[i]; l[i] = l[j]; l[j] = t
        Settings.set("dock.pinned", l)
    }
}
