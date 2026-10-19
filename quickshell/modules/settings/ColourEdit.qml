import QtQuick
import qs.config

// A colour setting for the settings panel: swatches (the first, "default", stores the word), then up
// to four colour stops (more than one makes a gradient), and for the selected stop a hex field and
// Red/Green/Blue sliders (double click a value to type it). Stored as "#rrggbb", or "#a,#b,#c,#d" for a
// gradient. `panel` is the SettingsPanel (its cfgValue reads the setting); sliders commit on release.
Column {
    id: cp
    required property Item panel
    property string key; property string title
    property color defColor: Colors.islandPrimary
    // Extra swatches [{ v: stored value, c: colour shown }]; the standard set when empty.
    property var choices: []
    property int sel: 0

    readonly property var raw: panel.cfgValue(key)
    readonly property var list: Colors.stops(raw, defColor)
    readonly property int idx: Math.min(sel, list.length - 1)
    readonly property color cur: list[idx]
    readonly property var swatches: [{ v: "default", c: defColor }].concat(choices.length ? choices
        : ["#ffffff", "#0a84ff", "#30d158", "#ff9f0a", "#ff375f", "#bf5af2", "#64d2ff"].map(h => ({ v: h, c: h })))
    width: parent ? parent.width : 0; spacing: 0

    function two(v) { return Math.round(v * 255).toString(16).padStart(2, "0") }
    function hex(c) { return "#" + two(c.r) + two(c.g) + two(c.b) }
    function store(l) { Settings.set(key, l.map(hex).join(",")) }
    function withStop(i, c) { const l = list.slice(); l[i] = c; return l }
    function commitHex(t) {
        t = t.trim(); if (t[0] !== "#") t = "#" + t
        if (/^#[0-9a-f]{3}$/i.test(t)) t = "#" + t[1] + t[1] + t[2] + t[2] + t[3] + t[3]
        if (/^#[0-9a-f]{6}$/i.test(t)) store(withStop(idx, Qt.color(t)))
    }
    function setChannel(i, v) {
        const c = [cur.r, cur.g, cur.b].map(x => Math.round(x * 255)); c[i] = v
        store(withStop(idx, Qt.rgba(c[0] / 255, c[1] / 255, c[2] / 255, 1)))
    }
    function addStop() { if (list.length < 4) { sel = list.length; store(list.concat([cur])) } }
    function removeStop() {
        if (list.length < 2) return
        const l = list.slice(); l.splice(idx, 1)
        sel = Math.max(0, idx - 1); store(l)
    }

    component Lbl: Text {
        color: Colors.islandFg; font.family: Theme.fontUi; font.pixelSize: 12
        verticalAlignment: Text.AlignVCenter; width: 120
    }

    // Swatches.
    Item {
        width: parent.width; height: 34
        Lbl { text: cp.title; height: parent.height }
        Row {
            x: 124; spacing: 8; anchors.verticalCenter: parent.verticalCenter
            Repeater {
                model: cp.swatches
                delegate: Rectangle {
                    required property var modelData
                    readonly property bool on: modelData.v === "default" ? (!cp.raw || cp.raw === "default") : String(cp.raw).toLowerCase() === modelData.v
                    width: 22; height: 22; radius: 11; color: modelData.c
                    border.width: on ? 2 : 1; border.color: on ? Colors.islandFg : Qt.rgba(1, 1, 1, 0.18)
                    Rectangle { visible: parent.on; anchors.centerIn: parent; width: 6; height: 6; radius: 3
                        color: Qt.color(parent.modelData.c).hslLightness > 0.6 ? "#000000" : "#ffffff" }
                    MouseArea {
                        anchors.fill: parent; anchors.margins: -3; cursorShape: Qt.PointingHandCursor
                        Accessible.role: Accessible.RadioButton; Accessible.name: cp.title + " " + parent.modelData.v; Accessible.checked: parent.on
                        onClicked: { cp.sel = 0; Settings.set(cp.key, parent.modelData.v) }
                    }
                }
            }
        }
    }

    // The colour stops: pick one to edit, add up to four, remove the selected one.
    Item {
        width: parent.width; height: 34
        Lbl { text: "Stops"; height: parent.height; color: Colors.islandFgVar }
        Row {
            x: 124; spacing: 8; anchors.verticalCenter: parent.verticalCenter
            Repeater {
                model: cp.list
                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    readonly property bool on: index === cp.idx
                    width: 22; height: 22; radius: 11; color: modelData
                    border.width: on ? 2 : 1; border.color: on ? Colors.islandFg : Qt.rgba(1, 1, 1, 0.18)
                    MouseArea {
                        anchors.fill: parent; anchors.margins: -3; cursorShape: Qt.PointingHandCursor
                        Accessible.role: Accessible.RadioButton; Accessible.name: cp.title + " stop " + (parent.index + 1); Accessible.checked: parent.on
                        onClicked: cp.sel = parent.index
                    }
                }
            }
            Rectangle {
                visible: cp.list.length < 4; width: 22; height: 22; radius: 11; color: Colors.islandSurface
                Text { anchors.centerIn: parent; text: "add"; color: Colors.islandFg; font.family: Theme.fontIcon; font.pixelSize: 16 }
                MouseArea { anchors.fill: parent; anchors.margins: -3; cursorShape: Qt.PointingHandCursor; onClicked: cp.addStop()
                    Accessible.role: Accessible.Button; Accessible.name: "Add colour stop" }
            }
            Rectangle {
                visible: cp.list.length > 1; width: 22; height: 22; radius: 11; color: Colors.islandSurface
                Text { anchors.centerIn: parent; text: "remove"; color: Colors.islandFg; font.family: Theme.fontIcon; font.pixelSize: 16 }
                MouseArea { anchors.fill: parent; anchors.margins: -3; cursorShape: Qt.PointingHandCursor; onClicked: cp.removeStop()
                    Accessible.role: Accessible.Button; Accessible.name: "Remove colour stop" }
            }
            // The result, left to right.
            Rectangle {
                visible: cp.list.length > 1; width: 64; height: 16; radius: 8; anchors.verticalCenter: parent.verticalCenter
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: Colors.sample(cp.list, 0) }
                    GradientStop { position: 1 / 3; color: Colors.sample(cp.list, 1 / 3) }
                    GradientStop { position: 2 / 3; color: Colors.sample(cp.list, 2 / 3) }
                    GradientStop { position: 1; color: Colors.sample(cp.list, 1) }
                }
            }
        }
    }

    // Hex field of the selected stop.
    Item {
        width: parent.width; height: 32
        Lbl { text: "Hex"; height: parent.height; color: Colors.islandFgVar }
        Rectangle { x: 124; anchors.verticalCenter: parent.verticalCenter; width: 22; height: 22; radius: 11; color: cp.cur
            border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.18) }
        Rectangle {
            x: 154; anchors.verticalCenter: parent.verticalCenter; width: 96; height: 26; radius: 13
            color: Colors.islandSurface; border.width: hexIn.activeFocus ? 1 : 0; border.color: Colors.islandPrimary
            TextInput {
                id: hexIn
                anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12
                verticalAlignment: TextInput.AlignVCenter; selectByMouse: true; maximumLength: 7
                color: Colors.islandFg; selectionColor: Colors.islandPrimary
                font.family: Theme.fontUi; font.pixelSize: 12
                text: cp.hex(cp.cur)
                Accessible.role: Accessible.EditableText; Accessible.name: cp.title + " hex"
                onEditingFinished: { cp.commitHex(text); text = Qt.binding(() => cp.hex(cp.cur)) }
            }
        }
    }

    // Red, green, blue of the selected stop.
    Repeater {
        model: ["Red", "Green", "Blue"]
        delegate: Item {
            id: ch
            required property string modelData
            required property int index
            readonly property int value: Math.round([cp.cur.r, cp.cur.g, cp.cur.b][index] * 255)
            property int live: -1
            readonly property int shown: live >= 0 ? live : value
            width: cp.width; height: 26
            function at(mx) { return Math.round(Math.max(0, Math.min(1, mx / ctrack.width)) * 255) }
            Lbl { text: ch.modelData; height: parent.height; color: Colors.islandFgVar }
            Rectangle {
                id: ctrack
                x: 124; y: 11; width: parent.width - 124 - 40; height: 4; radius: 2; color: Colors.islandSurfaceHighest
                Rectangle { width: ch.shown / 255 * parent.width; height: 4; radius: 2; color: Colors.islandPrimary }
                Rectangle { x: ch.shown / 255 * parent.width - 7; y: -5; width: 14; height: 14; radius: 7; color: Colors.islandPrimary }
            }
            Text {
                x: parent.width - 36; width: 36; height: parent.height; horizontalAlignment: Text.AlignRight; verticalAlignment: Text.AlignVCenter
                text: ch.shown; color: Colors.islandFgVar; font.family: Theme.fontUi; font.pixelSize: 12; font.features: { "tnum": 1 }
            }
            NumField { id: numEdit; x: parent.width - 60; y: 1; value: ch.value; from: 0; to: 255
                onApplied: v => cp.setChannel(ch.index, v) }
            MouseArea { x: parent.width - 40; width: 40; height: parent.height; cursorShape: Qt.IBeamCursor; onDoubleClicked: numEdit.open() }
            MouseArea {
                x: 124; width: ctrack.width; height: parent.height; cursorShape: Qt.PointingHandCursor
                Accessible.role: Accessible.Slider; Accessible.name: cp.title + " " + ch.modelData; Accessible.description: String(ch.shown)
                onPressed: m => ch.live = ch.at(m.x)
                onPositionChanged: m => { if (pressed) ch.live = ch.at(m.x) }
                onReleased: m => { const v = ch.at(m.x); ch.live = -1; cp.setChannel(ch.index, v) }
                onDoubleClicked: numEdit.open()
            }
        }
    }
}
