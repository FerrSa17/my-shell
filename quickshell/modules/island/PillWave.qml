import QtQuick
import qs.config
import qs.services
import "PillOutline.js" as Outline

// The wave as a ring around the island's pill: the level of each point pushes the ring outward, a
// smooth line follows it and the area between the ring and the pill is filled. The levels mirror
// left to right (bass at the top centre). Drawn under the pill, so a translucent pill shows the fill.
Canvas {
    id: cv
    required property Item pill
    readonly property int pad: 44
    readonly property real amp: Wave.thick * 0.13
    readonly property int points: 120
    visible: Wave.enabled && Wave.position === "pill"
    opacity: Wave.alpha
    x: pill.x - pad; y: pill.y - pad
    width: pill.width + 2 * pad; height: pill.height + 2 * pad
    readonly property var levels: Wave.levels
    readonly property real r: Math.min(pill.bodyRadius, pill.height / 2, pill.width / 2)
    onLevelsChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onRChanged: requestPaint()
    Connections { target: Wave; function onStopsChanged() { cv.requestPaint() } function onBorderStopsChanged() { cv.requestPaint() } function onBaseChanged() { cv.requestPaint() } function onBorderOnChanged() { cv.requestPaint() } }

    // The pill's outline from the top centre, clockwise: [x, y, outward normal x, y] at distance s.
    function outline(s) { return Outline.outline(s, pill.width, pill.height, cv.r, pad) }
    function perimeter() { return Outline.perimeter(pill.width, pill.height, cv.r) }

    // A closed Catmull-Rom curve through pts, as cubic Béziers.
    function trace(ctx, pts) {
        const n = pts.length
        ctx.moveTo(pts[0].x, pts[0].y)
        for (let i = 0; i < n; i++) {
            const p0 = pts[(i + n - 1) % n], p1 = pts[i], p2 = pts[(i + 1) % n], p3 = pts[(i + 2) % n]
            ctx.bezierCurveTo(p1.x + (p2.x - p0.x) / 6, p1.y + (p2.y - p0.y) / 6, p2.x - (p3.x - p1.x) / 6, p2.y - (p3.y - p1.y) / 6, p2.x, p2.y)
        }
        ctx.closePath()
    }

    onPaint: {
        const ctx = getContext("2d"), n = points, L = levels.length
        ctx.reset()
        if (L < 2 || pill.width < 10) return
        const P = perimeter(), outer = [], inner = []
        for (let k = 0; k < n; k++) {
            const o = outline(k / n * P)
            const t = k / n, m = (t < 0.5 ? t * 2 : (1 - t) * 2) * (L - 1)
            const lo = Math.floor(m), v = levels[lo] + (levels[Math.min(L - 1, lo + 1)] - levels[lo]) * (m - lo)
            const d = -3 + Wave.base * 0.13 + v * amp
            outer.push(Qt.point(o[0] + o[2] * d, o[1] + o[3] * d))
            inner.push(Qt.point(o[0], o[1]))
        }
        // The ring between the pill and the curve: the curve one way, the pill's outline back the other.
        ctx.beginPath()
        trace(ctx, outer)
        trace(ctx, inner.slice().reverse())
        ctx.fillStyle = Wave.style(ctx, Wave.stops, 0, 0, width, 0)
        ctx.fill()
        if (!Wave.borderOn) return
        ctx.beginPath()
        trace(ctx, outer)
        ctx.strokeStyle = Wave.style(ctx, Wave.borderStops, 0, 0, width, 0)
        ctx.lineWidth = 3; ctx.lineJoin = "round"
        ctx.stroke()
    }
}
