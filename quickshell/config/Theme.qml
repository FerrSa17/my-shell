pragma Singleton
import QtQuick
import Quickshell

Singleton {
    // macOS type: SF Pro Text below 20 px, SF Pro Display from 20 px up.
    readonly property string fontUi: "SF Pro Text"
    readonly property string fontDisplay: "SF Pro Display"
    readonly property string fontMono: "JetBrainsMono Nerd Font"
    readonly property string fontIcon: "Material Symbols Rounded"
    readonly property int textIsland: 13
    readonly property int textLauncher: 14
    readonly property int textControl: 13
    readonly property int topMargin: 6
    readonly property int durationShort: 120
    readonly property int durationNormal: 220
    readonly property int osdHoldMs: 1100
    readonly property int notificationHoldMs: 5000
}
