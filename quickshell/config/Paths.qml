pragma Singleton
import QtQuick
import Quickshell

// Where the shell keeps its files. Everything lives next to shell.qml: the fixed theme palettes in
// themes/, the user's settings and state in data/. Wallpapers come from ~/Pictures/Wallpapers.
Singleton {
    readonly property string root: Quickshell.shellDir
    readonly property string themes: root + "/themes"
    readonly property string data: root + "/data"
    readonly property string wallpapers: Quickshell.env("HOME") + "/Pictures/Wallpapers"
    readonly property string lock: root + "/lock.qml"
    // The lock runs as its own process, so restarting the shell can never unlock the session.
    readonly property var lockCmd: ["sh", "-c", 'pgrep -x hyprlock >/dev/null || pgrep -f "qs -n -p $1" >/dev/null || exec qs -n -p "$1" >/dev/null 2>&1', "sh", lock]
}
