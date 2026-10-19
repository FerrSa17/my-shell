pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Levels for the wave: cava reports 48 bars, 0..1 each, 60 times a second, for what the speakers play
// (wave.source "sound", any app) or for the default microphone ("mic"). One analyser serves every
// screen; it runs only while wave.enabled and restarts when the source changes.
Singleton {
    id: root
    readonly property bool enabled: Settings.wave.enabled === true
    // top, bottom, left, right: a strip along a screen edge; pill: a ring around the island.
    readonly property string position: ["top", "left", "right", "pill"].indexOf(Settings.wave.position) >= 0 ? Settings.wave.position : "bottom"
    readonly property string source: Settings.wave.source === "mic" ? "mic" : "sound"
    function isHex(v) { return typeof v === "string" && /^#([0-9a-f]{6}|[0-9a-f]{3})$/i.test(v) }
    // The wave's colours: the shell's accent, or wave.color (one "#rrggbb", or up to four joined by
    // commas for a gradient). The outline follows the wave unless wave.borderColor holds a colour;
    // wave.border false hides it.
    readonly property var stops: Colors.stops(Settings.wave.color, Colors.islandPrimary)
    readonly property var borderStops: !Settings.wave.borderColor || Settings.wave.borderColor === "default" ? stops : Colors.stops(Settings.wave.borderColor, stops[0])
    readonly property color tint: stops[0]
    readonly property color borderTint: borderStops[0]
    readonly property bool borderOn: Settings.wave.border !== false
    // A canvas fill/stroke style for a list of stops, running (x0,y0) to (x1,y1).
    function style(ctx, list, x0, y0, x1, y1) {
        if (list.length < 2) return Qt.rgba(list[0].r, list[0].g, list[0].b, 1)
        const g = ctx.createLinearGradient(x0, y0, x1, y1)
        list.forEach((c, i) => g.addColorStop(i / (list.length - 1), Qt.rgba(c.r, c.g, c.b, 1)))
        return g
    }
    // wave.opacity, 1..100 %, as 0..1.
    readonly property real alpha: Math.max(1, Math.min(100, Settings.wave.opacity !== undefined ? Settings.wave.opacity : 90)) / 100
    // wave.smooth, 0..100: how slowly the line follows the sound (the share of the way each frame
    // covers falls from 0.6 to 0.08) and how much neighbouring bars blend (one pass, two from 40).
    readonly property real smooth: Math.max(0, Math.min(100, Settings.wave.smooth !== undefined ? Settings.wave.smooth : 70))
    readonly property real follow: 0.6 - 0.52 * smooth / 100
    readonly property int blendPasses: smooth >= 40 ? 2 : 1
    // wave.height, px: how far the wave can rise from its edge (around the pill, scaled down).
    readonly property int thick: Math.max(60, Math.min(800, Settings.wave.height !== undefined ? Settings.wave.height : 260))
    // wave.base, px: how high the line rests while nothing plays (0: out of sight until it rises).
    readonly property int base: Math.max(0, Math.min(thick - 20, Settings.wave.base !== undefined ? Settings.wave.base : 0))
    readonly property int bars: 48
    property var levels: new Array(bars).fill(0)

    function apply() {
        if (proc.running) proc.running = false      // onExited starts it again with the new source
        else if (enabled) proc.running = true
    }
    onEnabledChanged: apply()
    onSourceChanged: apply()
    Component.onCompleted: apply()

    Process {
        id: proc
        // The mic's name goes into a copy of the config; exec so that stopping the shell stops cava.
        command: ["sh", "-c", 'f="${XDG_RUNTIME_DIR:-/tmp}/qs-wave.cava"; if [ "$2" = mic ]; then s=$(pactl get-default-source); else s=auto; fi; '
            + 'sed "s|^source = .*|source = $s|" "$1" > "$f"; exec cava -p "$f"', "sh", Paths.root + "/scripts/wave.cava", root.source]
        stdout: SplitParser {
            onRead: line => {
                const v = line.split(";").filter(x => x !== "").map(x => Math.min(1, Number(x) / 1000))
                if (v.length !== root.bars || !v.every(x => isFinite(x))) return
                // Neighbours blend (a smooth curve), and each frame only moves part of the way (no jitter).
                let t = v
                for (let k = 0; k < root.blendPasses; k++)
                    t = t.map((x, i) => (t[Math.max(0, i - 1)] + 2 * x + t[Math.min(t.length - 1, i + 1)]) / 4)
                const prev = root.levels
                root.levels = t.map((x, i) => prev[i] + (x - prev[i]) * root.follow)
            }
        }
        onExited: { root.levels = new Array(root.bars).fill(0); restart.start() }
    }
    // A short pause, so a missing cava does not respin.
    Timer { id: restart; interval: 400; onTriggered: if (root.enabled && !proc.running) proc.running = true }
}
