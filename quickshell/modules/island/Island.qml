import QtQuick
import QtQuick as QQ
import QtQuick.Effects
import Quickshell
import qs.config
import qs.config as Cfg
import qs.services as Svc
import "states"
import "surfaces" as Surf
import "cc" as Cc

// The island body and its state machine. Bare `State` is QtQuick's type, so the shell's
// State singleton is reached as Cfg.State.
// `state` is Item's own state property; the names below are declared in `states` so
// assigning any of them is valid. Its built-in stateChanged() notifier is the state-change
// signal (handlers read `island.state`); a second stateChanged(string) cannot coexist with it.
Item {
    id: islandRoot
    state: "rest"
    states: [
        QQ.State { name: "rest" }, QQ.State { name: "media" },
        QQ.State { name: "notification" }, QQ.State { name: "osd" }, QQ.State { name: "expanded" },
        QQ.State { name: "mediaSurface" }, QQ.State { name: "calendar" },
        QQ.State { name: "launcher" }, QQ.State { name: "wallpapers" },
        QQ.State { name: "timer" }, QQ.State { name: "todo" }, QQ.State { name: "clipboard" }
    ]
    // Surfaces that grow out of the pill; "expanded" is the control center. The modal ones
    // take the keyboard and the whole island surface catches clicks.
    readonly property var panels: ["expanded", "mediaSurface", "calendar", "timer"]
    readonly property var modals: ["launcher", "wallpapers", "todo", "clipboard"]
    readonly property var surfaces: panels.concat(modals)
    readonly property bool surfaceOpen: surfaces.indexOf(state) >= 0
    readonly property bool modalOpen: modals.indexOf(state) >= 0
    // The settings module a surface belongs to (Settings.modules.<name> false disables it).
    readonly property var moduleOf: ({ mediaSurface: "media", calendar: "calendar",
        launcher: "launcher", wallpapers: "wallpapers", todo: "todo", timer: "timer", clipboard: "clipboard" })
    property var stateContent: ({})
    // The monitor this island lives on (the rest pill shows that monitor's workspaces).
    property string screenName: ""
    // The screen's top-left in global pixels (the wallpaper grid's --from origin).
    property point screenOrigin: Qt.point(0, 0)
    readonly property color fg: Colors.darkOnSurface
    // Set by IslandWindow while the pill is retracted (fullscreen, auto-hide); IPC reports "hidden".
    property bool hidden: false
    // Set by IslandWindow while the retracted island's OSD shows on the fullscreen OSD overlay.
    property bool overlayOsd: false
    // Launcher mode for the next open ("apps", "windows", "calc", "clip").
    property string launcherMode: "apps"

    // The single source of truth for what the pill shows. The island state mirrors
    // arbiter.current (a critical notification shows as "notification"); nothing assigns `state`
    // except syncState().
    readonly property Arbiter arbiter: Arbiter {
        // Deferred one turn, so a hand-over (surface lowered, queued notification promoted) is a
        // single state change, not a flash of rest in between.
        onCurrentChanged: Qt.callLater(islandRoot.syncState)
        Component.onCompleted: {
            for (const n of islandRoot.panels) declare(n, Priorities.expanded, {})
            for (const n of islandRoot.modals) declare(n, Priorities.modal, {})
            declare("critical", Priorities.critical, { sticky: true })
            declare("notification", Priorities.notification, { holdMs: islandRoot.notifHold })
            declare("osd", Priorities.osd, { holdMs: islandRoot.osdHold, coalesce: true })
            // "media" is the 1.1 s now-playing card on a track change (media at rest is the
            // activity circle inside the rest state, not a state of its own).
            declare("media", Priorities.osd, { holdMs: islandRoot.osdHold, coalesce: true })
        }
    }
    // How long a notification stays on the pill (island.notifHoldMs); re-declared when it changes.
    readonly property int notifHold: Settings.island.notifHoldMs || Theme.notificationHoldMs
    onNotifHoldChanged: arbiter.declare("notification", Priorities.notification, { holdMs: notifHold })
    // How long the volume OSD and the now-playing card stay before the pill folds back (island.osdHoldMs).
    readonly property int osdHold: Settings.island.osdHoldMs || Theme.osdHoldMs
    onOsdHoldChanged: {
        arbiter.declare("osd", Priorities.osd, { holdMs: osdHold, coalesce: true })
        arbiter.declare("media", Priorities.osd, { holdMs: osdHold, coalesce: true })
    }
    readonly property var payload: arbiter.payload
    readonly property int priority: arbiter.currentPriority
    // A notification card under the pointer keeps its hold (sticky critical ones never time out).
    readonly property bool holdPaused: hover.hovered && state === "notification"
    onHoldPausedChanged: arbiter.pause(holdPaused)

    function stateFor(name) { return name === "critical" ? "notification" : (name || "rest") }
    // A state assignment inside a state change is refused by the StateGroup, so a change that lands
    // while one is being handled is deferred to the next turn of the event loop.
    property bool inStateChange: false
    function syncState() {
        const s = stateFor(arbiter.current)
        if (state === s) return
        if (inStateChange) { Qt.callLater(syncState); return }
        state = s
    }
    readonly property bool armed: surface.armed

    width: body.width; height: body.height

    // A fresh object each time: reassigning the same object does not notify bindings. The new
    // object re-evaluates the Loader's sourceComponent binding, so no explicit reload is needed.
    function register(name, component) { const m = Object.assign({}, stateContent); m[name] = component; stateContent = m }

    // --- surfaces ---
    // Opening a surface closes any other one; transients raised meanwhile wait
    // in the arbiter's queue and play once the surface closes.
    function openSurface(name, opts) {
        if (surfaces.indexOf(name) < 0) return
        const m = moduleOf[name]
        if (m && Settings.modules[m] === false) return
        if (name === "launcher") launcherMode = opts && opts.mode ? opts.mode : "apps"
        // The control center lists every notification; none should pop again after it closes.
        if (name === "expanded") Svc.Notifs.seenAll()
        for (const n of surfaces) if (n !== name) arbiter.lower(n)
        arbiter.raise(name, opts || {})
    }
    // What the arbiter shows now (state follows it a turn later).
    readonly property bool surfaceCurrent: surfaces.indexOf(arbiter.current) >= 0
    function closeSurface() { if (surfaceCurrent) arbiter.lower(arbiter.current) }
    function toggleSurface(name, opts) { arbiter.current === name ? closeSurface() : openSurface(name, opts) }
    // Super+Backspace and IPC: open the control center, or close whatever surface is open.
    function toggleExpanded() { surfaceCurrent ? closeSurface() : openSurface("expanded") }
    // Click mapping (Settings.island.click*): cc | media | calendar | launcher | todo | timer | none.
    function act(action) {
        switch (action) {
        case "cc": toggleSurface("expanded"); break
        case "media": toggleSurface("mediaSurface"); break
        case "calendar": toggleSurface("calendar"); break
        case "launcher": toggleSurface("launcher"); break
        case "todo": toggleSurface("todo"); break
        case "timer": toggleSurface("timer"); break
        }
    }
    // Only the pill itself takes the click mapping: with a surface open, a click on its empty space
    // (a panel such as the timer has no background of its own) reaches this MouseArea and must not
    // open the control center over it.
    function click(button) {
        if (surfaceOpen) return
        const isl = Settings.island
        act(button === Qt.RightButton ? (isl.clickRight || "none")
            : button === Qt.MiddleButton ? (isl.clickMiddle || "media") : (isl.clickLeft || "cc"))
    }
    function scroll(dy) {
        const mode = Settings.island.scroll || "volume"
        if (surfaceOpen || dy === 0 || mode === "none") return false
        Svc.Audio.step(dy > 0 ? 1 : -1)
        return true
    }

    // The pointer over the pill: a notification under it keeps its hold.
    HoverHandler { id: hover }
    // The window activates only after the first surface opens (its keyboard focus turns on with
    // it), and Qt then hands focus to the root item: take it back, or keys go nowhere.
    Connections {
        target: islandRoot.Window.window
        function onActiveChanged() { if (islandRoot.surfaceOpen && islandRoot.Window.window.active) islandRoot.forceActiveFocus() }
    }

    onStateChanged: {
        inStateChange = true
        if (surfaceOpen) forceActiveFocus()
        navTarget = null
        if (state === "expanded") Svc.Notifs.markSeen()
        inStateChange = false
    }

    // --- keyboard navigation inside surfaces ---
    // Tab / Shift+Tab walk the open surface's controls in reading order, the arrows move to the
    // nearest control in that direction, Enter or Space clicks it, Esc steps back / closes. A ring
    // in the primary colour marks the control. Controls are the surface's enabled, visible
    // MouseAreas (every surface and the control center build their buttons from them), minus
    // full-surface click swallowers. A surface that owns its keys (the launcher) is left alone.
    property Item navTarget: null
    property rect navRect: Qt.rect(0, 0, 0, 0)
    function isControl(it) { return !!it && it.acceptedButtons !== undefined && it.pressAndHoldInterval !== undefined && it.enabled }
    function navCandidates() {
        const root = surface.item
        if (!root || !surfaceOpen || root.wantsKeyboard) return []
        const out = [], W = root.width, H = root.height
        const walk = it => {
            if (!it || !it.visible || it.opacity <= 0.01) return
            if (it !== root && isControl(it) && it.width > 1 && it.height > 1 && !(it.width >= W * 0.9 && it.height >= H * 0.9)) {
                const p = it.mapToItem(root, it.width / 2, it.height / 2)
                if (p.x >= 0 && p.y >= 0 && p.x <= W && p.y <= H) out.push({ item: it, x: p.x, y: p.y })
            }
            for (let i = 0; i < it.children.length; i++) walk(it.children[i])
        }
        walk(root)
        // Reading order: rows (8 px tolerance) top to bottom, then left to right.
        out.sort((a, b) => Math.abs(a.y - b.y) > 8 ? a.y - b.y : a.x - b.x)
        return out
    }
    function setNav(it) {
        navTarget = it
        if (!it) return
        const p = it.mapToItem(body, 0, 0)
        navRect = Qt.rect(p.x, p.y, it.width, it.height)
    }
    function navStep(delta) {
        const c = navCandidates(); if (!c.length) return false
        const i = c.findIndex(e => e.item === navTarget)
        setNav(c[i < 0 ? (delta > 0 ? 0 : c.length - 1) : (i + delta + c.length) % c.length].item)
        return true
    }
    function navMove(dx, dy) {
        const c = navCandidates(); if (!c.length) return false
        const cur = c.find(e => e.item === navTarget)
        if (!cur) { setNav(c[0].item); return true }
        let best = null, bestD = 1e9
        for (const e of c) {
            if (e.item === cur.item) continue
            const ax = (e.x - cur.x) * dx + (e.y - cur.y) * dy          // along the direction
            const ox = Math.abs((e.x - cur.x) * dy) + Math.abs((e.y - cur.y) * dx) // across it
            if (ax <= 2) continue
            const d = ax + 2 * ox
            if (d < bestD) { bestD = d; best = e }
        }
        if (best) setNav(best.item)
        return true
    }
    function navActivate() {
        const it = navTarget
        if (!it || !isControl(it) || !it.visible) return false
        it.clicked(null)
        return true
    }
    // A focused slider (its MouseArea exposes stepAdjust(n)) takes Left/Right as value steps
    // (Shift = 10 steps); Up/Down and Tab still move the focus.
    function navAdjust(dir, big) {
        const t = navTarget
        if (!t || !surfaceOpen || !t.visible || typeof t.stepAdjust !== "function") return false
        t.stepAdjust(dir * (big ? 10 : 1))
        return true
    }
    // Alt/Shift + Up/Down on a focused row of a reorderable list (the Settings Modules composer:
    // the surface exposes reorder(control, dir) -> a key, and controlFor(key)) moves the row; the
    // focus follows the moved row once the list has rebuilt.
    function navReorder(dir, mods) {
        const it = surface.item, t = navTarget
        if (!(mods & (Qt.AltModifier | Qt.ShiftModifier)) || !t || !it || typeof it.reorder !== "function") return false
        const key = it.reorder(t, dir)   // "" when the control is not on a row; at an end the row stays
        if (key === "") return false
        Qt.callLater(() => { const c = surface.item && surface.item.controlFor ? surface.item.controlFor(key) : null; if (c) setNav(c) })
        return true
    }
    Keys.onPressed: event => {
        if (!surfaceOpen) return
        let done = false
        switch (event.key) {
        case Qt.Key_Tab: done = navStep(event.modifiers & Qt.ShiftModifier ? -1 : 1); break
        case Qt.Key_Backtab: done = navStep(-1); break
        case Qt.Key_Left: done = navAdjust(-1, event.modifiers & Qt.ShiftModifier) || navMove(-1, 0); break
        case Qt.Key_Right: done = navAdjust(1, event.modifiers & Qt.ShiftModifier) || navMove(1, 0); break
        case Qt.Key_Up: done = navReorder(-1, event.modifiers) || navMove(0, -1); break
        case Qt.Key_Down: done = navReorder(1, event.modifiers) || navMove(0, 1); break
        case Qt.Key_Return: case Qt.Key_Enter: case Qt.Key_Space: done = navActivate(); break
        }
        if (done) event.accepted = true
    }

    // The shape springs to the staged surface's size; the content cross-fades inside it.
    // island.shadow: a soft shadow under the pill (drawn outside it, so never clipped by it).
    RectangularShadow {
        anchors.fill: body; z: -1
        visible: Settings.island.shadow === true
        radius: body.radius; blur: 22; spread: 1; offset: Qt.vector2d(0, 6)
        color: Qt.rgba(0, 0, 0, 0.55)
    }
    Pill {
        id: body
        target: surface.shapeSize
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            Accessible.role: Accessible.Button
            Accessible.name: "Island"
            Accessible.description: "Left click: control center. Middle click: media. Scroll: volume."
            onClicked: mouse => islandRoot.click(mouse.button)
            onWheel: wheel => { wheel.accepted = islandRoot.scroll(wheel.angleDelta.y) }
        }
        SurfaceLoader {
            id: surface
            anchors.fill: parent
            target: islandRoot.state
            components: islandRoot.stateContent
            armStates: islandRoot.surfaces
            onItemLoaded: item => { if (item && ("island" in item)) item.island = islandRoot }
            // The slow spring for any morph into or out of a panel, the quick one between capsules
            // (anything up to 44 px tall counts as a capsule).
            property string lastShape: "rest"
            onShapeChanged: {
                body.calm = Sizes.of(shape).height > Sizes.capsuleMax || Sizes.of(lastShape).height > Sizes.capsuleMax
                lastShape = shape
            }
        }
        // Keyboard focus ring: drawn over the focused control, inside the pill's clip.
        Rectangle {
            objectName: "focusRing"
            visible: islandRoot.navTarget !== null && islandRoot.surfaceOpen && islandRoot.navTarget.visible
            x: islandRoot.navRect.x - 3; y: islandRoot.navRect.y - 3
            width: islandRoot.navRect.width + 6; height: islandRoot.navRect.height + 6
            radius: Math.min(12, height / 2)
            color: "transparent"; border.width: 2; border.color: Colors.darkPrimary
            z: 20
        }
    }
    Keys.onEscapePressed: if (surfaceOpen) closeSurface()
    Component.onCompleted: {
        register("rest", restComp); register("expanded", ccComp)
        register("mediaSurface", mediaSurfaceComp); register("calendar", calendarComp)
        register("launcher", launcherComp); register("wallpapers", wallpapersComp)
        register("todo", todoComp); register("timer", timerComp); register("clipboard", clipboardComp)
    }
    Component { id: restComp; Rest { island: islandRoot } }
    OsdRegistrar { island: islandRoot }
    // Measures the control center's notification list while it is closed (never shown), so the pill
    // opens straight to the panel's full height.
    Cc.Notifications { id: notifMeasure; visible: false; width: Sizes.expanded.width; host: Svc.Notifs }
    Binding { target: Sizes; property: "ccNotifH"; value: Math.min(Sizes.ccNotifMax, notifMeasure.implicitHeight) }
    Binding { target: Sizes; property: "ccMedia"; value: Svc.Media.player !== null && Composer.media }
    Loader { source: "states/MediaRegistrar.qml"; onLoaded: item.island = islandRoot }
    NotificationRegistrar { island: islandRoot }
    Component {
        id: ccComp
        Surf.ControlCenter {
            onCloseRequested: islandRoot.closeSurface()
            onOpenWallpapers: islandRoot.openSurface("wallpapers")
            onOpenSettings: Svc.Ipc.openSettings(true)
            onOpenCalendar: islandRoot.openSurface("calendar")
            onOpenClipboard: islandRoot.openSurface("clipboard")
        }
    }
    Component { id: mediaSurfaceComp; Surf.Media {} }
    Component { id: calendarComp; Surf.Calendar {} }
    Component { id: todoComp; Surf.Todo { onClose: islandRoot.closeSurface() } }
    Component { id: clipboardComp; Surf.Clipboard { onClose: islandRoot.closeSurface() } }
    Component { id: timerComp; Surf.Timer {} }
    Component { id: launcherComp; Surf.Launcher { mode: islandRoot.launcherMode; onClose: islandRoot.closeSurface() } }
    Component {
        id: wallpapersComp
        Surf.Wallpapers { screenOffset: islandRoot.screenOrigin; onClose: islandRoot.closeSurface(); onPicked: islandRoot.closeSurface() }
    }
}
