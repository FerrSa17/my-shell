pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import qs.config

// The notification daemon. Incoming notifications land in `list` (newest first, what the
// control center lists) and in `toasts` (waiting for, or showing on, the island). Each toast
// is raised on the driven island's Arbiter by NotificationRegistrar, which queues them one at a time
// (5 s hold, paused on hover; critical ones sticky) and calls toastDone() when one ends.
//
// Ownership: org.freedesktop.Notifications is probed first; when another daemon holds it, the shell stays
// `passive` (no server, the settings surface says so) and re-probes every 15 s to take over once free.
Singleton {
    id: root
    property var list: []
    property var toasts: []
    property int unread: 0
    property bool dnd: false
    // settings notifications.*: a sound per notification, dropping ones older than maxAgeMin, apps
    // whose notifications are dropped (muted), and a nightly do-not-disturb window (dndFrom..dndTo).
    readonly property var cfg: Settings.data.notifications || ({})
    readonly property var muted: Array.isArray(cfg.muted) ? cfg.muted : []
    // Quiet: do not disturb by hand, or inside the scheduled window.
    readonly property bool quiet: dnd || scheduledQuiet
    readonly property bool scheduledQuiet: {
        if (cfg.dndSchedule !== true) return false
        const mins = s => { const m = /^(\d{1,2}):(\d{2})$/.exec(s || ""); return m ? +m[1] * 60 + +m[2] : -1 }
        const from = mins(cfg.dndFrom || "23:00"), to = mins(cfg.dndTo || "08:00"), now = clock.date.getHours() * 60 + clock.date.getMinutes()
        if (from < 0 || to < 0 || from === to) return false
        return from < to ? now >= from && now < to : now >= from || now < to
    }
    SystemClock { id: clock; precision: SystemClock.Minutes }
    // Every app seen sending a notification this session (the settings list them to mute).
    property var apps: []
    // Arrival time by notification id, for the auto-removal.
    property var arrivedAt: ({})
    // True while another process owns the notifications bus name.
    property bool passive: false
    property bool probed: false
    readonly property int count: list.length
    // The toast on the driven island right now, or null.
    readonly property var current: {
        const isl = Ipc.island
        if (!isl || (isl.arbiter.current !== "notification" && isl.arbiter.current !== "critical")) return null
        return isl.arbiter.payload.n || null
    }

    signal toast(var n)
    signal untoast(int id)
    signal toastsCleared()

    // Owner pid of the bus name (if any) and our own pid (the shell is the probe's parent).
    Process {
        id: probe
        command: ["sh", "-c", "echo \"$(busctl --user status org.freedesktop.Notifications 2>/dev/null | sed -n 's/^PID=//p') $PPID\""]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim().split(/\s+/)
                const owner = p.length > 1 ? p[0] : ""
                const me = p[p.length - 1]
                root.passive = owner !== "" && owner !== me
                if (root.passive && !root.probed) console.log("org.freedesktop.Notifications is owned by pid " + owner + "; notifications passive")
                root.probed = true
            }
        }
    }
    Timer { interval: 15000; repeat: true; running: root.passive; onTriggered: probe.running = true }

    Instantiator {
        active: root.probed && !root.passive
        delegate: NotificationServer {
            bodySupported: true; actionsSupported: true; imageSupported: true
            persistenceSupported: true; keepOnReload: true
            onNotification: n => root.arrived(n)
        }
    }

    function arrived(n) {
        const app = n.appName || ""
        if (app && root.apps.indexOf(app) < 0) root.apps = root.apps.concat([app]).sort()
        if (app && root.muted.indexOf(app) >= 0) { n.dismiss(); return }
        n.tracked = true
        const t = Object.assign({}, root.arrivedAt); t[n.id] = Date.now(); root.arrivedAt = t
        if (root.list.indexOf(n) < 0 && !n.transient) root.list = [n].concat(root.list)
        n.closed.connect(() => root.forget(n))
        // Carried over from before a reload: keep it in the center, do not pop it again.
        if (n.lastGeneration) return
        const centerOpen = Ipc.island && Ipc.island.state === "expanded"
        if (!centerOpen) root.unread++
        // Do not disturb, the control center open, or island.notifToasts off: listed, never popped.
        if (root.quiet || centerOpen || Settings.island.notifToasts === false) { if (n.transient) n.expire(); return }
        if (root.cfg.sound === true) Quickshell.execDetached(["pw-play", "/usr/share/sounds/freedesktop/stereo/message-new-instant.oga"])
        // A replacement (same id) updates the toast in place; the arbiter dedupes on the key.
        if (root.toasts.indexOf(n) < 0) root.toasts = root.toasts.concat([n])
        root.toast(n)
    }
    // The island finished showing a toast (hold ran out, acted on, lowered).
    function toastDone(n) {
        root.toasts = root.toasts.filter(x => x !== n)
        if (n && n.transient) n.expire()
    }
    // The control center opened: every pending toast counts as seen.
    function seenAll() {
        const t = root.toasts
        root.toasts = []
        root.toastsCleared()
        for (const n of t) if (n.transient) n.expire()
    }
    function dismiss(n) { if (n) n.dismiss() }
    function clearAll() {
        const all = list.slice()
        for (const n of toasts) if (all.indexOf(n) < 0) all.push(n)
        toasts = []
        toastsCleared()
        for (const n of all) n.dismiss()
        list = []
        unread = 0
    }
    function markSeen() { unread = 0 }
    // Called from a notification's closed signal, before the object is destroyed.
    function forget(n) {
        list = list.filter(x => x !== n)
        if (toasts.indexOf(n) >= 0) { toasts = toasts.filter(x => x !== n); untoast(n.id) }
    }
    function invokeDefault(n) {
        if (!n) return false
        const a = n.actions.find(x => x.identifier === "default")
        if (!a) return false
        a.invoke()
        return true
    }
    function iconSource(n) {
        if (!n) return ""
        const i = n.appIcon || ""
        if (i.startsWith("/")) return "file://" + i
        if (i.startsWith("file://") || i.startsWith("image://")) return i
        if (i) { const p = Quickshell.iconPath(i, true); if (p) return p }
        if (n.image) return n.image
        // No icon sent (plain notify-send): try the app name as an icon theme name.
        return n.appName ? Quickshell.iconPath(n.appName.toLowerCase(), true) : ""
    }
    // notifications.maxAgeMin: dismiss what has been in the list longer than that (checked each minute).
    Timer {
        interval: 60000; repeat: true; running: (root.cfg.maxAgeMin || 0) > 0
        onTriggered: {
            const limit = Date.now() - root.cfg.maxAgeMin * 60000
            for (const n of root.list.slice()) if ((root.arrivedAt[n.id] || Date.now()) < limit) n.dismiss()
        }
    }
    function setMuted(app, on) {
        const l = root.muted.filter(a => a !== app)
        if (on) l.push(app)
        Settings.set("notifications.muted", l)
    }
}
