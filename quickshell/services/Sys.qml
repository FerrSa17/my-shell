pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// System load for the control center: processor, memory and the root disk, in percent. One short
// shell command every 2 s while `active` (the control center sets it while it is open). The
// network speed is Net's.
Singleton {
    id: root
    property bool active: false
    property real cpu: 0
    property real mem: 0
    property real disk: 0
    property var lastCpu: null

    Process {
        id: proc
        command: ["sh", "-c", "head -1 /proc/stat; grep -E '^(MemTotal|MemAvailable):' /proc/meminfo; df -P / | awk 'NR==2 { print \"disk \" $5 }'"]
        stdout: StdioCollector {
            onStreamFinished: {
                let total = 0, avail = 0
                for (const l of text.split("\n")) {
                    if (l.startsWith("cpu ")) {
                        const v = l.trim().split(/\s+/).slice(1).map(Number)
                        const all = v.reduce((a, b) => a + b, 0), idle = v[3] + (v[4] || 0)
                        if (root.lastCpu && all > root.lastCpu.all) root.cpu = 1 - (idle - root.lastCpu.idle) / (all - root.lastCpu.all)
                        root.lastCpu = { all: all, idle: idle }
                    } else if (l.startsWith("MemTotal:")) total = parseInt(l.split(/\s+/)[1])
                    else if (l.startsWith("MemAvailable:")) avail = parseInt(l.split(/\s+/)[1])
                    else if (l.startsWith("disk ")) root.disk = parseInt(l.slice(5)) / 100
                }
                if (total > 0) root.mem = 1 - avail / total
            }
        }
    }
    Timer { interval: 2000; running: root.active; repeat: true; triggeredOnStart: true; onTriggered: if (!proc.running) proc.running = true }
}
