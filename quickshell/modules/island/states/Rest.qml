import QtQuick
import qs.config
import qs.services
import "../rest"

// The island at rest, three groups around the clock:
//   left:  the activity circle (timer, album art; collapses when empty) and this
//          monitor's workspaces;
//   right: the keyboard layout, the volume ring, the now-playing waveform while a player plays and
//          the microphone and screen-recording indicators and a lock while a VPN is up.
// The groups sit at the pill's ends and the clock between them with `spread` of air either side; the
// pill is that row on the 8 px grid. The anchors never change (switching them at runtime left both
// edges anchored for a frame and the rows overlapped).
// While music plays the pill turns into the iPhone's compact activity: only the album art at the left
// end and the waveform at the right; under the pointer it is the usual pill again.
StateBase {
    id: rest
    name: "rest"; priority: 0
    readonly property int pad: 14
    readonly property int gap: 10
    readonly property bool activityOn: activity.shown
    readonly property bool waveOn: Media.player !== null && Media.playing && Settings.island.liveActivities !== false
    // Under the pointer the usual pill comes back while music plays; a short grace on leaving keeps
    // the edge crossing (the pill resizes under the pointer) from flickering.
    property bool peek: false
    HoverHandler { onHoveredChanged: { if (hovered) { peekOff.stop(); rest.peek = true } else peekOff.restart() } }
    Timer { id: peekOff; interval: 250; onTriggered: rest.peek = false }
    // island.compactMedia false keeps the usual pill while music plays; island.equalizer hides the bars.
    readonly property bool mediaHere: waveOn && activity.mode === "media" && Settings.island.compactMedia !== false
    readonly property bool nowPlaying: mediaHere && !peek
    readonly property int playingGap: 88
    readonly property int spread: 28
    size: Qt.size(Sizes.snap(nowPlaying ? pad * 2 + left.implicitWidth + right.implicitWidth + playingGap
        : pad * 2 + left.implicitWidth + right.implicitWidth + spread * 2 + clock.width), 36)

    Row {
        id: left
        anchors.left: parent.left; anchors.leftMargin: rest.pad
        anchors.verticalCenter: parent.verticalCenter
        spacing: rest.gap
        ActivityCircle {
            id: activity; objectName: "activityCircle"
            visible: rest.activityOn && !(rest.mediaHere && rest.peek); anchors.verticalCenter: parent.verticalCenter
            beating: rest.waveOn
            // Media at rest: a click on the circle opens the media surface (middle click anywhere does too).
            MouseArea {
                anchors.fill: parent; anchors.margins: -5
                enabled: activity.mode === "media"
                Accessible.role: Accessible.Button; Accessible.name: "Now playing. Open media"
                onClicked: if (rest.island) rest.island.openSurface("mediaSurface")
            }
        }
        Workspaces { visible: !rest.nowPlaying; anchors.verticalCenter: parent.verticalCenter; screenName: rest.island ? rest.island.screenName : "" }
    }
    // `spread` of air on both sides of the clock: it sits between the groups, not on the pill's centre,
    // so a narrow right side leaves no empty tail.
    Clock { id: clock; x: rest.pad + left.implicitWidth + rest.spread; anchors.verticalCenter: parent.verticalCenter; visible: !rest.nowPlaying }
    Row {
        id: right
        anchors.right: parent.right; anchors.rightMargin: rest.pad
        anchors.verticalCenter: parent.verticalCenter
        spacing: rest.gap
        KbLayout { visible: !rest.nowPlaying && Hypr.kbShort !== ""; anchors.verticalCenter: parent.verticalCenter }
        VolumeGauge { visible: !rest.nowPlaying; anchors.verticalCenter: parent.verticalCenter }
        Equalizer {
            id: wave; objectName: "equalizer"
            visible: rest.waveOn && !rest.peek && Settings.island.equalizer !== false; anchors.verticalCenter: parent.verticalCenter
            MouseArea {
                anchors.fill: parent; anchors.margins: -5
                Accessible.role: Accessible.Button; Accessible.name: "Now playing. Open media"
                onClicked: if (rest.island) rest.island.openSurface("mediaSurface")
            }
        }
        // Privacy (microphone, screen recording) shows even while music plays.
        Indicators { anchors.verticalCenter: parent.verticalCenter }
        // Last, at the right end: a lock while a VPN tunnel is up (Net.vpns: tun / wireguard links such as happ-xray).
        Text {
            objectName: "vpn"
            visible: !rest.nowPlaying && Net.vpn; anchors.verticalCenter: parent.verticalCenter
            text: "vpn_lock"; color: Colors.alpha(Colors.darkOnSurface, 0.85)
            font.family: Theme.fontIcon; font.pixelSize: 16
        }
    }
}
