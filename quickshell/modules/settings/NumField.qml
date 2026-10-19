import QtQuick
import qs.config

// A small number entry that opens over a slider's value (double click): type, Enter or click away to
// apply, Escape to cancel. The number is clamped to from..to.
Rectangle {
    id: nf
    property int value: 0; property int from: 0; property int to: 100
    signal applied(int v)
    function open() { visible = true; input.text = String(value); input.forceActiveFocus(); input.selectAll() }
    function finish(commit) {
        if (!visible) return
        visible = false
        const n = parseInt(input.text)
        if (commit && isFinite(n)) applied(Math.max(from, Math.min(to, n)))
    }
    visible: false
    width: 58; height: 24; radius: 12; z: 50
    color: Colors.islandSurfaceHigh; border.width: 1; border.color: Colors.islandPrimary
    TextInput {
        id: input
        anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8
        horizontalAlignment: TextInput.AlignHCenter; verticalAlignment: TextInput.AlignVCenter
        selectByMouse: true; maximumLength: 5
        validator: RegularExpressionValidator { regularExpression: /[0-9]*/ }
        color: Colors.islandFg; selectionColor: Colors.islandPrimary
        font.family: Theme.fontUi; font.pixelSize: 12; font.features: { "tnum": 1 }
        Accessible.role: Accessible.EditableText; Accessible.name: "Value"
        onAccepted: nf.finish(true)
        Keys.onEscapePressed: event => { nf.finish(false); event.accepted = true }
        onActiveFocusChanged: if (!activeFocus) nf.finish(true)
    }
}
