pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Timer activity (named Countdown: a singleton called Timer would shadow QtQuick's Timer in this module).
// start(seconds, label) / pause() / resume() / stop(); `remaining` in whole seconds, `total` the length
// it was started with. State lives in data/timer.json as {endsAt (epoch ms) | left (s, paused), total,
// label}, so a shell restart keeps the countdown. At zero it rings and posts a notification.
Singleton {
    id: root
    property bool running: false
    property bool paused: false
    property int remaining: 0
    property int total: 0
    property string label: ""
    property real endsAt: 0
    readonly property bool active: running || paused
    signal finished(string label)

    readonly property string file: Paths.data + "/timer.json"

    function start(seconds, lbl) {
        if (!(seconds > 0)) return
        label = lbl || ""
        total = seconds
        endsAt = Date.now() + seconds * 1000
        paused = false; running = true
        tick(); save()
    }
    function pause() {
        if (!running) return
        tick(); running = false; paused = true; save()
    }
    function resume() {
        if (!paused) return
        endsAt = Date.now() + remaining * 1000
        paused = false; running = true; save()
    }
    function stop() { running = false; paused = false; remaining = 0; total = 0; endsAt = 0; label = ""; save() }
    function tick() {
        if (!running) return
        const left = Math.ceil((endsAt - Date.now()) / 1000)
        if (left <= 0) { const l = label; stop(); finished(l) } else remaining = left
    }
    function save() {
        store.setText(JSON.stringify(running ? { endsAt: endsAt, total: total, label: label }
            : paused ? { left: remaining, total: total, label: label } : {}))
    }
    function load(text) {
        try {
            const d = JSON.parse(text)
            label = d.label || ""; total = d.total || 0
            if (d.left > 0) { remaining = d.left; paused = true }
            else if (d.endsAt && d.endsAt > Date.now()) { endsAt = d.endsAt; running = true; tick() }
            else if (d.endsAt) stop()
        } catch (e) {}
    }
    onFinished: l => Quickshell.execDetached(["sh", "-c",
        'notify-send -a Timer -i alarm-symbolic "${1:-Timer}" "Time is up"; pw-play /usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga 2>/dev/null',
        "sh", l])

    FileView {
        id: store
        path: root.file
        printErrors: false
        atomicWrites: true
        onLoaded: root.load(text())
    }
    Timer { interval: 500; running: root.running; repeat: true; onTriggered: root.tick() }
}
