import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services

// Now-playing equaliser for the rest pill, like the iPhone's: five bars that grow up and down from
// the centre line with the sound itself. scripts/spectrum.py listens to what the speakers play and
// reports five bands, bass to treble, about thirty times a second; each bar follows its band at once
// and falls back gradually. The bars follow the master volume too (quiet speakers, small bars) and
// rest as dots on pause, silence or mute. They take the album art's colour (ColorQuantizer), else the
// primary.
Item {
    id: root
    property bool playing: Media.playing
    readonly property int bars: 5
    readonly property int barWidth: 3
    readonly property int gap: 2
    readonly property int maxHeight: 16
    readonly property int minHeight: 3
    // The latest band levels, 0..1 each.
    property var levels: [0, 0, 0, 0, 0]
    implicitWidth: bars * barWidth + (bars - 1) * gap; implicitHeight: maxHeight
    width: implicitWidth; height: implicitHeight

    // The analyser runs only while music plays and the bars are on screen.
    Process {
        id: spectrum
        running: root.playing && root.visible
        command: ["python3", "-I", Paths.root + "/scripts/spectrum.py"]
        stdout: SplitParser {
            onRead: line => {
                const v = line.trim().split(" ").map(Number)
                if (v.length === root.bars && v.every(x => isFinite(x))) root.levels = v
            }
        }
        onRunningChanged: if (!running) root.levels = [0, 0, 0, 0, 0]
    }

    // ColorQuantizer cannot read inline (data:) covers, such as Firefox's; those keep the primary.
    ColorQuantizer { id: quant; source: Media.artUrl.startsWith("data:") ? "" : Media.artUrl; depth: 2; rescaleSize: 32 }
    readonly property color tint: {
        const c = quant.colors && quant.colors.length ? quant.colors[0] : null
        if (!c) return Colors.darkPrimary
        // Lift dark covers so the bars read on the black pill.
        return c.hslLightness < 0.55 ? Qt.hsla(c.hslHue, Math.max(c.hslSaturation, 0.35), 0.62, 1) : c
    }

    Repeater {
        model: root.bars
        delegate: Rectangle {
            required property int index
            x: index * (root.barWidth + root.gap)
            width: root.barWidth; radius: width / 2
            height: root.minHeight + (root.levels[index] || 0) * (root.maxHeight - root.minHeight)
            anchors.verticalCenter: parent.verticalCenter
            color: root.tint
            // A little smoothing between frames; the release itself comes from the analyser.
            Behavior on height { NumberAnimation { duration: 60; easing.type: Easing.OutQuad } }
            Behavior on color { ColorAnimation { duration: Theme.durationNormal } }
        }
    }
}
