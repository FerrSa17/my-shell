import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services

// The wave along one screen edge (wave.position): one smooth line through the band levels, the area
// between it and the edge filled, moving with whatever the speakers (or the microphone) play. The
// window covers the screen on a top layer with an empty input mask, so every click goes through; only
// the strip along the edge is drawn on. Changing the position floods the screen: the line runs from
// the old edge across to the far side (the screen fills up), then recedes to the new edge.
Scope {
    id: scope
    required property ShellScreen modelData
    readonly property string edge: Wave.position
    readonly property var edges: ["top", "bottom", "left", "right"]
    readonly property int thick: Wave.thick
    readonly property int travelMs: 700

    // The edge the canvas is drawn against (the target one, except while the screen floods), the
    // baseline's distance from it, and the last position seen (to tell a move from a first show).
    property string shown: edges.indexOf(edge) >= 0 ? edge : "bottom"
    property real reach: 0
    property bool moving: false
    property string prev: edge
    readonly property bool vertical: shown === "left" || shown === "right"
    function span(e) { return e === "left" || e === "right" ? modelData.width : modelData.height }

    onEdgeChanged: {
        flood.stop()
        const old = prev
        prev = edge
        reach = 0
        if (edges.indexOf(edge) < 0) { moving = false; return }
        if (Wave.enabled && edges.indexOf(old) >= 0 && old !== edge) {
            shown = old; moving = true
            flood.restart()
        } else { shown = edge; moving = false }
    }
    SequentialAnimation {
        id: flood
        NumberAnimation { target: scope; property: "reach"; to: scope.span(scope.shown); duration: scope.travelMs; easing.type: Easing.InOutCubic }
        ScriptAction { script: { scope.shown = scope.edge; scope.reach = scope.span(scope.edge) } }
        NumberAnimation { target: scope; property: "reach"; to: 0; duration: scope.travelMs; easing.type: Easing.InOutCubic }
        ScriptAction { script: scope.moving = false }
    }

    Loader {
        active: Wave.enabled && scope.edges.indexOf(scope.edge) >= 0
        sourceComponent: PanelWindow {
            screen: scope.modelData
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            WlrLayershell.namespace: "wave"
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            mask: Region {}

            Canvas {
                id: canvas
                // The strip along the edge; the whole screen while flooding.
                readonly property real fullW: parent.width
                readonly property real fullH: parent.height
                x: scope.moving || scope.shown !== "right" ? 0 : fullW - scope.thick
                y: scope.moving || scope.shown !== "bottom" ? 0 : fullH - scope.thick
                width: scope.moving ? fullW : (scope.vertical ? scope.thick : fullW)
                height: scope.moving ? fullH : (scope.vertical ? fullH : scope.thick)
                opacity: Wave.alpha
                readonly property var levels: Wave.levels
                readonly property real len: scope.vertical ? height : width
                onLevelsChanged: requestPaint()
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                Connections {
                    target: scope
                    function onReachChanged() { canvas.requestPaint() }
                    function onShownChanged() { canvas.requestPaint() }
                }
                Connections {
                    target: Wave
                    function onStopsChanged() { canvas.requestPaint() }
                    function onBorderStopsChanged() { canvas.requestPaint() }
                    function onBaseChanged() { canvas.requestPaint() }
                    function onThickChanged() { canvas.requestPaint() }
                    function onBorderOnChanged() { canvas.requestPaint() }
                }

                // The point `along` the edge and `out` from it.
                function at(along, out) {
                    switch (scope.shown) {
                    case "top": return Qt.point(along, out)
                    case "left": return Qt.point(out, along)
                    case "right": return Qt.point(width - out, along)
                    default: return Qt.point(along, height - out)
                    }
                }
                // Point i of n at level v; the baseline sits `reach` px off the edge.
                // At rest (v = 0, base 0) the line sits just off the edge, so nothing shows until the sound lifts it.
                function pt(i, n, v) { return at(i / (n - 1) * len, scope.reach - 3 + Wave.base + v * Math.max(1, scope.thick - 20 - Wave.base)) }

                onPaint: {
                    const ctx = getContext("2d"), n = levels.length
                    ctx.reset()
                    if (n < 2) return
                    const pts = levels.map((v, i) => pt(i, n, v))
                    // Gradients run along the edge.
                    const gx = scope.vertical ? 0 : width, gy = scope.vertical ? height : 0
                    ctx.strokeStyle = Wave.style(ctx, Wave.borderStops, 0, 0, gx, gy)
                    ctx.fillStyle = Wave.style(ctx, Wave.stops, 0, 0, gx, gy)
                    ctx.lineWidth = 3; ctx.lineJoin = "round"; ctx.lineCap = "round"
                    // Catmull-Rom through the points, as cubic Béziers.
                    ctx.beginPath()
                    ctx.moveTo(pts[0].x, pts[0].y)
                    for (let i = 0; i < n - 1; i++) {
                        const p0 = pts[Math.max(0, i - 1)], p1 = pts[i], p2 = pts[i + 1], p3 = pts[Math.min(n - 1, i + 2)]
                        ctx.bezierCurveTo(p1.x + (p2.x - p0.x) / 6, p1.y + (p2.y - p0.y) / 6,
                                          p2.x - (p3.x - p1.x) / 6, p2.y - (p3.y - p1.y) / 6, p2.x, p2.y)
                    }
                    if (Wave.borderOn) ctx.stroke()
                    // The area between the line and the edge.
                    ctx.lineTo(at(len, 0).x, at(len, 0).y)
                    ctx.lineTo(at(0, 0).x, at(0, 0).y)
                    ctx.closePath()
                    ctx.fill()
                }
            }
        }
    }
}
