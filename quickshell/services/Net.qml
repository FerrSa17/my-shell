pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Networking
import Quickshell.Io

// The wired connection: whether the cable is up, its interface and IPv4 address, live traffic
// (bytes/s) and the VPN tunnels that are up (tun / wireguard links, e.g. happ-xray).
Singleton {
    id: root
    property bool connected: false
    property string iface: ""
    property string ip: ""
    property real rxRate: 0
    property real txRate: 0
    property var vpns: []
    readonly property bool vpn: vpns.length > 0
    // The lock screen's network glyph.
    readonly property string icon: !connected ? "link_off" : vpn ? "vpn_lock" : "lan"

    function rate(b) {
        return b >= 1048576 ? (b / 1048576).toFixed(b >= 10485760 ? 0 : 1) + " MB/s"
            : b >= 1024 ? Math.round(b / 1024) + " KB/s" : Math.round(b) + " B/s"
    }

    function refresh() {
        let up = false, name = ""
        const devs = Networking.devices ? Networking.devices.values : []
        for (const d of devs) if (d.connected && d.type === DeviceType.Wired) { up = true; name = d.name; break }
        root.connected = up
        if (name) root.iface = name
    }
    Component.onCompleted: refresh()
    Connections { target: Networking.devices; function onValuesChanged() { root.refresh() } }
    Timer { interval: 3000; running: true; repeat: true; onTriggered: root.refresh() }

    // Traffic, address and tunnels every 2 s: /proc/net/dev counters, the tunnel links, then "ip <addr>".
    property var lastBytes: null
    property real lastAt: 0
    Process {
        id: traffic
        command: ["sh", "-c", 'cat /proc/net/dev; ip -o link show type tun 2>/dev/null; ip -o link show type wireguard 2>/dev/null; ' +
            '[ -n "$1" ] && ip -4 -o addr show dev "$1" 2>/dev/null | awk \'{print "ip " $4}\'', "sh", root.iface]
        stdout: StdioCollector {
            onStreamFinished: {
                const now = Date.now(), v = [], lines = text.split("\n")
                let addr = "", bytes = null
                for (const l of lines) {
                    const m = /^\s*([^:\s]+):\s+(\d+)(?:\s+\d+){7}\s+(\d+)/.exec(l)
                    if (m && m[1] === root.iface) bytes = { rx: +m[2], tx: +m[3] }
                    const t = /^\d+:\s+([^:@]+)[:@]/.exec(l)
                    if (t) v.push(t[1])
                    if (l.startsWith("ip ")) addr = l.slice(3).split("/")[0]
                }
                if (bytes && root.lastBytes && now > root.lastAt) {
                    const dt = (now - root.lastAt) / 1000
                    root.rxRate = Math.max(0, (bytes.rx - root.lastBytes.rx) / dt)
                    root.txRate = Math.max(0, (bytes.tx - root.lastBytes.tx) / dt)
                }
                root.lastBytes = bytes; root.lastAt = now
                root.ip = addr
                if (JSON.stringify(v) !== JSON.stringify(root.vpns)) root.vpns = v
            }
        }
    }
    Timer { interval: 2000; running: true; repeat: true; triggeredOnStart: true; onTriggered: traffic.running = true }
}
