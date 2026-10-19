import QtQuick
import qs.config

// The island's shape (black by default). Width, height and radius follow their targets through
// SpringAnimation Behaviors: a new target retargets the running spring (velocity is kept, nothing
// restarts). `calm` picks the slow open spring, otherwise the quick one; reduced motion swaps in a
// damping-1 spring that settles in about 80 ms. Target widths sit on the 8 px grid.
Rectangle {
    id: pill
    property size target: Sizes.rest
    property bool calm: false
    readonly property bool reduced: !!Settings.island.reducedMotion
    // motion.type "smooth" damps the spring critically: the same pace, no overshoot or bounce.
    readonly property bool smooth: Settings.motion.type === "smooth"
    readonly property var spec: reduced ? (Settings.motion.springReduced || ({ spring: 50, damping: 1 }))
        : smooth ? ({ spring: calm ? 5 : 9, damping: 1, velocity: 0 })
        : calm ? (Settings.motion.springCalm || ({ spring: 6, damping: 0.5, velocity: 0 }))
        : (Settings.motion.springQuick || ({ spring: 12, damping: 0.6, velocity: 0 }))
    // motion.speed (percent) scales the spring: a spring constant grows with the square of the speed.
    readonly property real speed: Math.max(25, Settings.motion.speed || 100) / 100
    readonly property real springK: spec.spring * speed * speed
    readonly property real springD: spec.damping
    // Speed cap in px/s (0 = none; the defaults are uncapped so a panel opens in ~250 ms).
    readonly property real springV: spec.velocity || 0


    width: Sizes.snap(target.width)
    height: target.height
    radius: Sizes.radiusFor(target.height)
    // island.color / island.opacity (percent) for the body, island.borderWidth / island.borderColor
    // for the outline (0 px: none).
    // island.color may be a gradient (up to four colours, left to right).
    readonly property var fills: Colors.stops(Settings.island.color, "#000000")
    readonly property real fillAlpha: (Settings.island.opacity !== undefined ? Settings.island.opacity : 100) / 100
    function shade(t) { const c = Colors.sample(fills, t); return Qt.rgba(c.r, c.g, c.b, fillAlpha) }
    color: shade(0)
    gradient: fills.length > 1 ? fillGradient : null
    Gradient {
        id: fillGradient
        orientation: Gradient.Horizontal
        GradientStop { position: 0; color: pill.shade(0) }
        GradientStop { position: 1 / 3; color: pill.shade(1 / 3) }
        GradientStop { position: 2 / 3; color: pill.shade(2 / 3) }
        GradientStop { position: 1; color: pill.shade(1) }
    }
    border.width: Settings.island.borderWidth !== undefined ? Settings.island.borderWidth : 1
    border.color: Colors.pick(Settings.island.borderColor, Qt.rgba(1, 1, 1, 0.06))
    clip: true

    Behavior on width { SpringAnimation { spring: pill.springK; damping: pill.springD; velocity: pill.springV; epsilon: 0.25 } }
    Behavior on height { SpringAnimation { spring: pill.springK; damping: pill.springD; velocity: pill.springV; epsilon: 0.25 } }
    Behavior on radius { SpringAnimation { spring: pill.springK; damping: pill.springD; velocity: pill.springV; epsilon: 0.25 } }
}
