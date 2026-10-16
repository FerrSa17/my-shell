pragma Singleton
import QtQuick
import Quickshell

// The control center's composition (settings key `layout.cc`): its tiles (order, size) and sections. The
// renderers read the normalised lists here; the Settings Modules page edits them through the
// functions below, which write the whole list back with Settings.set (applies live, persists).
// Normalising: unknown ids are dropped, duplicates keep the first, known ids missing from a user's
// list are appended disabled (so an id added later still shows up in the editor), and an empty or
// malformed list falls back to the defaults.
Singleton {
    id: root
    readonly property var tileIds: ["network", "dnd"]
    readonly property var sectionKeys: ["sliders", "media", "power", "system", "weather"]
    readonly property var labels: ({
        network: "Network", dnd: "Do not disturb",
        sliders: "Sliders", power: "Power row", system: "System load", weather: "Weather"
    })
    readonly property var sectionLabels: ({ sliders: "Sliders", media: "Media", power: "Power", system: "System", weather: "Weather" })
    // Built-in fallbacks for a settings.default.json without a layout block.
    readonly property var builtinTiles: ["network", "dnd"]

    readonly property var defaults: Settings.defaults.layout || ({})
    readonly property var cfg: Settings.layout

    readonly property var ccCfg: root.cfg.cc || ({})
    readonly property var defaultTiles: root.norm((root.defaults.cc || {}).tiles, root.tileIds, root.builtinTiles, true, null)
    readonly property var tiles: root.norm(root.ccCfg.tiles, root.tileIds, root.builtinTiles, true, root.defaultTiles)
    readonly property var tilesShown: root.tiles.filter(e => e.enabled)
    // Rows the 4-column tile grid takes (a 2x1 tile spans two columns; one that does not fit starts a row).
    readonly property int tileRows: {
        let r = 0, c = 0
        for (const t of root.tilesShown) { const span = t.size === "2x1" ? 2 : 1; if (c + span > 4) { r++; c = 0 } c += span }
        return root.tilesShown.length ? r + 1 : 0
    }
    function section(key) { return root.ccCfg[key] !== false }
    readonly property bool sliders: root.section("sliders")
    readonly property bool media: root.section("media")
    readonly property bool power: root.section("power")
    readonly property bool system: root.section("system")
    readonly property bool weather: root.section("weather")

    function label(id) { return root.labels[id] || id }
    // list (anything) -> [{id, enabled[, size]}] over `known`; `fallback` (normalised) when empty.
    function norm(list, known, builtin, sized, fallback) {
        const out = [], seen = {}
        if (Array.isArray(list)) for (const e of list) {
            const id = e && typeof e === "object" ? String(e.id) : String(e)
            if (known.indexOf(id) < 0 || seen[id]) continue
            seen[id] = true
            const o = { id: id, enabled: !(e && typeof e === "object" && e.enabled === false) }
            if (sized) o.size = e && e.size === "2x1" ? "2x1" : "1x1"
            out.push(o)
        }
        if (out.length === 0) {
            if (fallback) return fallback
            for (const id of builtin) { seen[id] = true; out.push(sized ? { id: id, enabled: true, size: "2x1" } : { id: id, enabled: true }) }
        }
        for (const id of known) if (!seen[id]) out.push(sized ? { id: id, enabled: false, size: "1x1" } : { id: id, enabled: false })
        return out
    }

    // --- editing (the Settings Modules page, IPC) ---
    function listOf(sectionName) { return root.tiles }
    function pathOf(sectionName) { return "layout.cc.tiles" }
    function copy(sectionName) { return root.listOf(sectionName).map(e => Object.assign({}, e)) }
    function indexOf(sectionName, id) { return root.listOf(sectionName).findIndex(e => e.id === id) }
    // Moves `id` one place up (dir -1) or down (+1); false at either end.
    function move(sectionName, id, dir) {
        const l = root.copy(sectionName), i = l.findIndex(e => e.id === id), j = i + dir
        if (i < 0 || j < 0 || j >= l.length) return false
        const t = l[i]; l[i] = l[j]; l[j] = t
        Settings.set(root.pathOf(sectionName), l)
        return true
    }
    function setEnabled(sectionName, id, on) {
        const l = root.copy(sectionName), e = l.find(x => x.id === id)
        if (!e) return
        e.enabled = !!on
        Settings.set(root.pathOf(sectionName), l)
    }
    function setSize(id, size) {
        const l = root.copy("cc"), e = l.find(x => x.id === id)
        if (!e) return
        e.size = size === "2x1" ? "2x1" : "1x1"
        Settings.set("layout.cc.tiles", l)
    }
    function setSection(key, on) { if (root.sectionKeys.indexOf(key) >= 0) Settings.set("layout.cc." + key, !!on) }
    function reset() { Settings.unset("layout") }
}
