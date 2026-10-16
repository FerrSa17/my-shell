pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Singleton {
    id: root

    readonly property int focusedId: (Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id) || 1
    // Sorted list of {id, name, active, occupied, monitor}: ids 1..count plus any others that exist.
    property var workspaces: []
    readonly property string focusedMonitorName: Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""

    function rebuild() {
        const byId = {};
        const vals = Hyprland.workspaces ? Hyprland.workspaces.values : [];
        for (let i = 0; i < vals.length; i++) {
            const w = vals[i];
            if (w.id > 0) byId[w.id] = w;
        }
        const ids = [];
        for (let i = 1; i <= root.count; i++) ids.push(i);
        for (const k in byId) { const n = parseInt(k); if (ids.indexOf(n) < 0) ids.push(n); }
        ids.sort((a, b) => a - b);
        const out = [];
        for (const id of ids) {
            const w = byId[id];
            out.push({
                id: id,
                name: w ? w.name : String(id),
                active: id === root.focusedId,
                occupied: w ? w.toplevels.values.length > 0 : false,
                monitor: w && w.monitor ? w.monitor.name : ""
            });
        }
        const ma = {};
        const mons = Hyprland.monitors ? Hyprland.monitors.values : [];
        for (const m of mons) if (m.activeWorkspace) ma[m.name] = m.activeWorkspace.id;
        if (JSON.stringify(ma) !== JSON.stringify(root.monActive)) root.monActive = ma;
        if (JSON.stringify(out) !== JSON.stringify(root.workspaces)) root.workspaces = out;
    }

    property var monActive: ({})

    // The workspaces the binds reach (Super+1..9 in hypr/modules/binds.lua).
    readonly property int count: 9
    // Workspaces to show on one monitor: 1..count, plus any higher one that exists on it.
    function workspacesFor(monitorName) {
        const aid = root.monActive[monitorName] !== undefined ? root.monActive[monitorName] : root.focusedId;
        const byId = {};
        for (const w of root.workspaces) byId[w.id] = w;
        const ids = [];
        for (let i = 1; i <= root.count; i++) ids.push(i);
        for (const w of root.workspaces) if (w.monitor === monitorName && ids.indexOf(w.id) < 0) ids.push(w.id);
        ids.sort((x, y) => x - y);
        return ids.map(id => ({
            id: id,
            name: byId[id] ? byId[id].name : String(id),
            active: id === aid,
            occupied: byId[id] ? byId[id].occupied : false,
            monitor: monitorName
        }));
    }

    // The main keyboard's active layout ("English (US)") and its short code for the pill ("EN").
    property string kbLayout: ""
    readonly property string kbShort: {
        const l = root.kbLayout.toLowerCase()
        const known = { english: "EN", russian: "RU", ukrainian: "UA", german: "DE", french: "FR", spanish: "ES", polish: "PL", belarusian: "BY", kazakh: "KZ" }
        for (const k in known) if (l.indexOf(k) === 0) return known[k]
        return root.kbLayout.slice(0, 2).toUpperCase()
    }
    function nextLayout() { Quickshell.execDetached(["hyprctl", "switchxkblayout", "all", "next"]) }
    Process {
        id: kbProbe
        running: true
        command: ["hyprctl", "devices", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const kbs = JSON.parse(text).keyboards || []
                    const k = kbs.find(x => x.main) || kbs[0]
                    if (k) root.kbLayout = k.active_keymap
                } catch (e) {}
            }
        }
    }

    function go(id) { Hyprland.dispatch("hl.dsp.focus({ workspace = " + id + " })") }
    function step(delta) {
        // Move through the focused monitor's workspaces.
        const m = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : "";
        const list = root.workspacesFor(m);
        let idx = list.findIndex(w => w.id === root.focusedId);
        if (idx < 0) return;
        idx = Math.max(0, Math.min(list.length - 1, idx + delta));
        root.go(list[idx].id);
    }

    Component.onCompleted: rebuild()
    Connections {
        target: Hyprland
        function onFocusedWorkspaceChanged() { root.rebuild() }
    }
    Connections {
        target: Hyprland.workspaces
        function onValuesChanged() { root.rebuild() }
    }
    Timer { id: debounce; interval: 100; onTriggered: root.rebuild() }
    Connections {
        target: Hyprland
        function onRawEvent(ev) {
            // One event per keyboard, each with its own layout: read the main keyboard's back.
            if (ev.name === "activelayout") { kbProbe.running = true; return }
            debounce.restart()
            // hasFullscreen is only re-read from a workspace refresh.
            if (ev.name === "fullscreen") Hyprland.refreshWorkspaces()
        }
    }
    Connections {
        target: Hyprland.toplevels
        function onValuesChanged() { root.rebuild() }
    }
}
