pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// The chosen theme and wallpaper (data/state.json). A theme only recolours the shell (its fixed
// palette in themes/<name>/colors.json); the wallpaper is any image, set through awww.
Singleton {
    id: root
    property string theme: "harbor"
    property string wallpaper: ""
    readonly property string mode: Colors.mode
    property bool loaded: false

    // A theme switch brings its own wallpaper (themes/<name>/wallpaper.png) along with the colours.
    function setTheme(name) {
        if (!name || name === theme) return
        theme = name
        setWallpaper(Paths.themes + "/" + name + "/wallpaper.png", "")
    }
    // from: the global "X,Y" the circle reveal grows from ("" = the focused monitor's island).
    function setWallpaper(path, from) {
        if (!path) return
        wallpaper = path
        save()
        apply(from || "")
    }
    function apply(from) {
        const reduced = Settings.island.reducedMotion === true
        const args = reduced ? ["--transition-type", "simple", "--transition-step", "255"]
            : ["--transition-type", "grow", "--transition-duration", "0.9", "--transition-fps", "60", "--transition-bezier", ".16,1,.3,1"]
                .concat(from ? ["--transition-pos", from] : [])
        // At login awww-daemon may still be starting: give it up to 5 s.
        Quickshell.execDetached(["sh", "-c", 'for i in $(seq 50); do awww query >/dev/null 2>&1 && break; sleep 0.1; done; w=$1; shift; exec awww img "$w" "$@"',
            "sh", root.wallpaper].concat(args))
    }
    function save() { file.setText(JSON.stringify({ theme: root.theme, wallpaper: root.wallpaper }, null, 2) + "\n") }

    FileView {
        id: file
        path: Paths.data + "/state.json"
        printErrors: false
        atomicWrites: true
        onLoaded: {
            try {
                const s = JSON.parse(file.text())
                root.theme = s.theme || "harbor"
                root.wallpaper = s.wallpaper || ""
            } catch (e) { console.warn("state.json parse failed: " + e) }
            root.loaded = true
        }
        onLoadFailed: root.loaded = true
    }
}
