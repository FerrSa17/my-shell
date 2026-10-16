pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Screen-recorder watch: `active` and `kind` (one of `names`, or ""). Polls pgrep every 2 s while
// `enabled`; the rest pill shows a red indicator while `active`.
Singleton {
    id: root
    property bool enabled: true
    property bool active: false
    property string kind: ""
    readonly property var names: ["wf-recorder", "wl-screenrec", "obs", "gpu-screen-recorder", "kooha"]

    function poll() { if (enabled && !proc.running) proc.running = true }
    onEnabledChanged: { if (enabled) poll(); else { active = false; kind = "" } }

    Process {
        id: proc
        command: ["pgrep", "-x", "-l", root.names.join("|")]
        stdout: StdioCollector {
            onStreamFinished: {
                // pgrep -l prints "<pid> <name>"; the first known name wins.
                const found = text.split("\n").map(l => l.trim().split(/\s+/)[1]).filter(n => root.names.indexOf(n) >= 0)
                root.kind = found.length ? found[0] : ""
                root.active = found.length > 0
            }
        }
    }
    Timer { interval: 2000; running: root.enabled; repeat: true; triggeredOnStart: true; onTriggered: root.poll() }
}
