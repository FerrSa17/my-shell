import QtQuick
import qs.config
import qs.services
import "PillOutline.js" as Outline

// The countdown around the island: a ring that starts as the full outline of the pill and shrinks
// (clockwise from the top centre) as the timer runs down, and the time left to the right of the pill on
// no background. Drawn under the pill, outside the input mask. A paused timer keeps its ring.
Item {
    id: root
    required property Item pill
    readonly property bool on: Countdown.active && Settings.island.timerActivity !== false
    // the share of the timer left, 0..1; updated every frame while running so the ring moves smoothly.
    property real fraction: 0
    function refresh() {
        const t = Countdown.total * 1000
        fraction = t > 0 ? Math.max(0, Math.min(1, (Countdown.running ? Countdown.endsAt - Date.now() : Countdown.remaining * 1000) / t)) : 0
    }
    FrameAnimation { running: root.on && Countdown.running; onTriggered: root.refresh() }
    Connections { target: Countdown; function onRemainingChanged() { root.refresh() } function onTotalChanged() { root.refresh() }
        function onRunningChanged() { root.refresh() } }
    onOnChanged: refresh()
    Component.onCompleted: refresh()

    // The last five minutes: the end of the ring (the part that shrinks) fades to red.
    readonly property bool warn: on && Countdown.remaining <= 300
    readonly property real tailPx: 70
    // Under three minutes the whole ring turns red (eased in over a moment).
    readonly property bool urgent: on && Countdown.remaining < 180
    property real alarm: urgent ? 1 : 0
    Behavior on alarm { NumberAnimation { duration: 600; easing.type: Easing.InOutQuad } }

    readonly property string timeText: {
        const s = Math.max(0, Countdown.remaining), h = Math.floor(s / 3600), m = Math.floor(s % 3600 / 60), q = s % 60
        const two = n => (n < 10 ? "0" : "") + n
        return h > 0 ? h + ":" + two(m) + ":" + two(q) : two(m) + ":" + two(q)
    }

    Canvas {
        id: ring
        // Painted on the GPU: a big (expanded) island would make the CPU canvas stutter.
        renderTarget: Canvas.FramebufferObject
        renderStrategy: Canvas.Immediate
        visible: root.on
        readonly property int pad: 14
        readonly property real gap: 4
        x: root.pill.x - pad; y: root.pill.y - pad
        width: root.pill.width + 2 * pad; height: root.pill.height + 2 * pad
        readonly property real r: Math.min(root.pill.bodyRadius, root.pill.height / 2, root.pill.width / 2)
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onRChanged: requestPaint()
        Connections { target: root; function onFractionChanged() { ring.requestPaint() } }
        Connections { target: Colors; function onIslandPrimaryChanged() { ring.requestPaint() } }
        Connections { target: root; function onWarnChanged() { ring.requestPaint() } function onAlarmChanged() { ring.requestPaint() } }
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            const w = root.pill.width, h = root.pill.height
            if (root.fraction <= 0 || w < 10) return
            const P = Outline.perimeter(w, h, r), len = P * root.fraction, step = Math.max(2, P / 500)
            const pt = s => { const o = Outline.outline(Math.min(s, len), w, h, r, pad); return [o[0] + o[2] * gap, o[1] + o[3] * gap] }
            ctx.lineWidth = 3; ctx.lineCap = "round"; ctx.lineJoin = "round"
            const red = Colors.islandError, accent = Colors.islandPrimary, k = root.alarm
            // The ring body: the accent colour, turning fully red under three minutes.
            const base = Qt.rgba(accent.r + (red.r - accent.r) * k, accent.g + (red.g - accent.g) * k, accent.b + (red.b - accent.b) * k, 1)
            const keep = root.warn ? Math.max(0, len - root.tailPx) : len
            // The ring in the accent colour (up to where the red tail starts).
            ctx.beginPath()
            for (let s = 0; s <= keep + 0.01; s += step) { const p = pt(s); if (s === 0) ctx.moveTo(p[0], p[1]); else ctx.lineTo(p[0], p[1]) }
            ctx.strokeStyle = base
            ctx.stroke()
            if (!root.warn) return
            // The tail: short pieces, each a step closer to red; the very tip is fully red.
            for (let s = keep; s < len; s += step) {
                const t = Math.max(0, Math.min(1, (s + step - (len - root.tailPx)) / root.tailPx)), a = pt(s), b = pt(Math.min(s + step, len))
                ctx.beginPath(); ctx.moveTo(a[0], a[1]); ctx.lineTo(b[0], b[1])
                ctx.strokeStyle = Qt.rgba(base.r + (red.r - base.r) * t, base.g + (red.g - base.g) * t, base.b + (red.b - base.b) * t, 1)
                ctx.stroke()
            }
        }
    }

    // The time left, to the right of the pill, vertically centred on it.
    Text {
        visible: root.on
        x: root.pill.x + root.pill.width + 12
        y: root.pill.y + root.pill.height / 2 - height / 2
        text: root.timeText
        opacity: Countdown.paused ? 0.6 : 1
        color: Colors.darkOnSurface
        style: Text.Outline; styleColor: Qt.rgba(0, 0, 0, 0.45)
        font.family: Theme.fontUi; font.pixelSize: 15; font.weight: Font.DemiBold; font.features: { "tnum": 1 }
    }
}
