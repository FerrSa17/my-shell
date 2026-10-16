import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import qs.config
import qs.config as Cfg
import Quickshell
import qs.services as Svc

// The settings panel: the GUI over the Settings singleton, shown in SettingsWindow. A page rail on
// the left (Island, Behaviour, Modules, Dock, Notifications, Lock, Theme and wallpapers). Sliders
// preview while dragging (`preview` overrides) and write Cfg.Settings.set only on release.
FocusScope {
    id: root
    readonly property size size: Sizes.settings
    property string page: "island"
    property var preview: ({})
    // A one-line problem the host reports (another notification daemon owns the bus name).
    property string warning: ""
    signal openWallpapers()
    signal closeRequested()
    focus: true
    Keys.onEscapePressed: closeRequested()

    // The pages; `keys` are what the search matches besides the label (the rows' titles, lower case).
    readonly property var pages: [
        { id: "island", label: "Island", glyph: "pill", keys: "mode top gap reserve background colour color opacity border shadow animation spring smooth speed fold delay" },
        { id: "events", label: "Events", glyph: "bolt", keys: "music equalizer volume notifications timer screen recording microphone" },
        { id: "player", label: "Player", glyph: "music_note", keys: "cover progress bar time track media" },
        { id: "behaviour", label: "Behaviour", glyph: "touch_app", keys: "live activities clock click scroll reset" },
        { id: "modules", label: "Modules", glyph: "widgets", keys: "surfaces tiles control center sections" },
        { id: "dock", label: "Dock", glyph: "dock_to_bottom", keys: "position auto-hide autohide delay icon size spacing margin radius opacity border shadow magnify names dots divider window count pinned" },
        { id: "notifications", label: "Notifications", glyph: "notifications", keys: "do not disturb quiet hours schedule pill sound auto-remove apps mute clear" },
        { id: "control", label: "Control center", glyph: "tune", keys: "date format" },
        { id: "theme", label: "Theme", glyph: "palette", keys: "accent contrast wallpapers colour color" },
        { id: "lock", label: "Lock", glyph: "lock", keys: "clock date name reveal status lock screen" }]
    // Settings search: the pages whose label or rows match; the first match opens.
    property string search: ""
    readonly property var shownPages: {
        const q = search.trim().toLowerCase()
        return q === "" ? pages : pages.filter(p => (p.label + " " + p.keys).toLowerCase().indexOf(q) >= 0)
    }
    onShownPagesChanged: if (shownPages.length && !shownPages.some(p => p.id === page)) page = shownPages[0].id

    // Keys are island.* by default; "motion.revealMs" style dotted keys address another section.
    function cfgPath(key) { return key.indexOf(".") >= 0 ? key : "island." + key }
    function cfgValue(key) { return cfgPath(key).split(".").reduce((o, k) => o === undefined || o === null ? undefined : o[k], Cfg.Settings.data) }
    function value(key) { return preview[key] !== undefined ? preview[key] : cfgValue(key) }
    function setPreview(key, v) { const p = Object.assign({}, preview); p[key] = v; preview = p }
    function commit(key, v) {
        Cfg.Settings.set(cfgPath(key), v)
        const p = Object.assign({}, preview); delete p[key]; preview = p
    }

    function setLock(k, v) { Cfg.Settings.set("lock." + k, v) }

    component Label: Text {
        color: Colors.islandFg; font.family: Theme.fontUi; font.pixelSize: 12
        verticalAlignment: Text.AlignVCenter
    }
    component Chip: Rectangle {
        id: chip
        property string text; property bool on: false
        property string accName: ""
        signal clicked()
        implicitWidth: lbl.implicitWidth + 24; implicitHeight: 26; radius: 13
        color: on ? Colors.islandPrimary : (ma.containsMouse ? Colors.islandSurfaceHigh : Colors.islandSurface)
        Text {
            id: lbl; anchors.centerIn: parent; text: chip.text
            color: chip.on ? Colors.islandOnPrimary : Colors.islandFg
            font.family: Theme.fontUi; font.pixelSize: 12; font.weight: Font.Medium
        }
        MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: chip.clicked()
            Accessible.role: Accessible.Button; Accessible.name: chip.accName || chip.text; Accessible.checked: chip.on }
    }
    component Switch: Rectangle {
        id: sw
        property bool on: false
        property string name: ""
        property string navRole: "switch"
        readonly property string rowTitle: parent && parent.parent && parent.parent.title !== undefined ? parent.parent.title : ""
        signal toggled(bool v)
        implicitWidth: 38; implicitHeight: 22; radius: 11
        color: on ? Colors.islandPrimary : Colors.islandSurfaceHighest
        Rectangle {
            width: 16; height: 16; radius: 8; y: 3; x: sw.on ? 19 : 3
            color: sw.on ? Colors.islandOnPrimary : Colors.islandFgVar
            Behavior on x { NumberAnimation { duration: Theme.durationShort } }
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: sw.toggled(!sw.on)
            Accessible.role: Accessible.CheckBox; Accessible.name: sw.name || sw.rowTitle; Accessible.checked: sw.on }
    }
    component Row2: Item {
        property string title
        default property alias content: slot.data
        Layout.fillWidth: true; Layout.preferredHeight: parent && parent.rowH ? parent.rowH : 30
        Label { text: parent.title; width: 120; height: parent.height; color: Colors.islandFg }
        Item { id: slot; x: 124; width: parent.width - 124; height: parent.height }
    }
    component Slide: Item {
        id: sl
        property string key; property real from: 0; property real to: 100; property string unit: "px"; property real step: 1
        readonly property string rowTitle: parent && parent.parent && parent.parent.title !== undefined ? parent.parent.title : ""
        readonly property real cur: { const v = key ? root.value(key) : from; return v === undefined ? from : v }
        height: 30; anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        Rectangle { id: track; x: 0; y: 13; width: parent.width - 54; height: 4; radius: 2; color: Colors.islandSurfaceHighest
            Rectangle { width: Math.max(0, Math.min(1, (sl.cur - sl.from) / (sl.to - sl.from))) * parent.width; height: 4; radius: 2; color: Colors.islandPrimary }
            Rectangle { x: Math.max(0, Math.min(1, (sl.cur - sl.from) / (sl.to - sl.from))) * parent.width - 7; y: -5; width: 14; height: 14; radius: 7; color: Colors.islandPrimary }
        }
        Label { x: parent.width - 48; width: 48; height: parent.height; horizontalAlignment: Text.AlignRight
            text: Math.round(sl.cur) + " " + sl.unit; color: Colors.islandFgVar; font.features: { "tnum": 1 } }
        function at(mx) { return Math.round(sl.from + Math.max(0, Math.min(1, mx / track.width)) * (sl.to - sl.from)) }
        MouseArea {
            anchors.fill: parent; anchors.rightMargin: 54; cursorShape: Qt.PointingHandCursor
            onPressed: m => root.setPreview(sl.key, sl.at(m.x))
            onPositionChanged: m => { if (pressed) root.setPreview(sl.key, sl.at(m.x)) }
            onReleased: m => root.commit(sl.key, sl.at(m.x))
            Accessible.role: Accessible.Slider; Accessible.name: sl.rowTitle; Accessible.description: Math.round(sl.cur) + " " + sl.unit
            // Keyboard (the island's navigator calls this on Left/Right): n steps, committed at once.
            function stepAdjust(n) { root.commit(sl.key, Math.max(sl.from, Math.min(sl.to, Math.round(sl.cur) + n * sl.step))) }
        }
    }
    // A dropdown in the shell's look: a rounded field with a chevron that turns, and a black popup
    // with a hairline and rounded rows (the current option checked). It opens below the field, or above
    // it when the panel has no room left below (the last rows of a page); while open its row is raised
    // over the others so the list is never covered.
    // One row per setting, the common kinds: a switch (`def` is its value while unset), a slider, a
    // choice of chips, a palette of colour swatches, and a 30-minute time stepper.
    component SwitchRow: Item {
        id: sr
        property string key; property bool def: true
        property string title
        width: parent ? parent.width : 0; height: 34
        Label { text: sr.title; width: 120; height: parent.height; color: Colors.islandFg }
        Switch { x: 124; anchors.verticalCenter: parent.verticalCenter; name: sr.title
            on: sr.def ? root.cfgValue(sr.key) !== false : root.cfgValue(sr.key) === true
            onToggled: v => Cfg.Settings.set(sr.key, v) }
    }
    component SlideRow: Item {
        id: slr
        property string key; property real from: 0; property real to: 100; property real step: 1; property string unit: "px"
        property string title
        width: parent ? parent.width : 0; height: 34
        Label { text: slr.title; width: 120; height: parent.height; color: Colors.islandFg }
        Slide { x: 124; width: parent.width - 124; key: slr.key; from: slr.from; to: slr.to; step: slr.step; unit: slr.unit }
    }
    component ChipsRow: Item {
        id: cr
        property string key; property var options: []; property var labels: ({})
        property string title
        width: parent ? parent.width : 0; height: 34
        Label { text: cr.title; width: 120; height: parent.height; color: Colors.islandFg }
        Row { x: 124; spacing: 6; anchors.verticalCenter: parent.verticalCenter
            Repeater { model: cr.options
                delegate: Chip { required property string modelData; text: cr.labels[modelData] || modelData
                    on: String(root.cfgValue(cr.key) === undefined ? cr.options[0] : root.cfgValue(cr.key)) === modelData
                    onClicked: Cfg.Settings.set(cr.key, modelData) } } }
    }
    component ColourRow: Item {
        id: swr
        property string key; property var options: []   // [{ v: stored value, c: colour shown }]
        readonly property string cur: { const v = root.cfgValue(key); return v === undefined || v === null ? String(options.length ? options[0].v : "") : String(v) }
        property string title
        width: parent ? parent.width : 0; height: 34
        Label { text: swr.title; width: 120; height: parent.height; color: Colors.islandFg }
        Row { x: 124; spacing: 8; anchors.verticalCenter: parent.verticalCenter
            Repeater { model: swr.options
                delegate: Rectangle {
                    required property var modelData
                    readonly property bool on: swr.cur === String(modelData.v)
                    width: 22; height: 22; radius: 11; color: modelData.c
                    border.width: on ? 2 : 1; border.color: on ? Colors.islandFg : Qt.rgba(1, 1, 1, 0.18)
                    Rectangle { visible: parent.on; anchors.centerIn: parent; width: 6; height: 6; radius: 3
                        color: Qt.color(parent.modelData.c).hslLightness > 0.6 ? "#000000" : "#ffffff" }
                    MouseArea { anchors.fill: parent; anchors.margins: -3; cursorShape: Qt.PointingHandCursor
                        Accessible.role: Accessible.RadioButton; Accessible.name: swr.title + " " + parent.modelData.v; Accessible.checked: parent.on
                        onClicked: Cfg.Settings.set(swr.key, parent.modelData.v) }
                } } }
    }
    component TimeStep: Rectangle {
        id: ts
        property string key; property string fallback: "00:00"
        readonly property string cur: { const v = root.cfgValue(key); return typeof v === "string" && /^\d{1,2}:\d{2}$/.test(v) ? v : fallback }
        function shift(d) {
            const p = cur.split(":"), m = ((+p[0] * 60 + +p[1] + d * 30) % 1440 + 1440) % 1440
            Cfg.Settings.set(key, String(Math.floor(m / 60)).padStart(2, "0") + ":" + String(m % 60).padStart(2, "0"))
        }
        width: tsRow.implicitWidth + 8; height: 28; radius: 14; color: Colors.islandSurface
        Row {
            id: tsRow; anchors.centerIn: parent; spacing: 2
            Text { text: "chevron_left"; color: Colors.islandFgVar; font.family: Theme.fontIcon; font.pixelSize: 18; anchors.verticalCenter: parent.verticalCenter
                MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: ts.shift(-1); Accessible.role: Accessible.Button; Accessible.name: "Earlier" } }
            Label { height: 28; text: ts.cur; font.weight: Font.Medium; font.features: { "tnum": 1 } }
            Text { text: "chevron_right"; color: Colors.islandFgVar; font.family: Theme.fontIcon; font.pixelSize: 18; anchors.verticalCenter: parent.verticalCenter
                MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: ts.shift(1); Accessible.role: Accessible.Button; Accessible.name: "Later" } }
        }
    }

    component Drop: Item {
        id: dd
        property string key; property var options: []
        // Shown text per option value (the value itself when absent).
        property var labels: ({})
        signal chosen()
        readonly property string cur: String(root.cfgValue(key))
        readonly property string rowTitle: parent && parent.parent && parent.parent.title !== undefined ? parent.parent.title : ""
        property bool open: false
        property bool upward: false
        readonly property Item hostRow: parent && parent.parent ? parent.parent : null
        onOpenChanged: if (open) upward = dd.mapToItem(root, 0, dd.height).y + 8 + popup.height > root.height - 12
        // While open, its row sits above every other (the Binding restores the row's own z after).
        Binding { target: dd.hostRow; property: "z"; value: 100; when: dd.open && dd.hostRow !== null }
        height: 28; width: 160; anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        Rectangle {
            anchors.fill: parent; radius: 14
            color: fieldHit.containsMouse || dd.open ? Colors.islandSurfaceHigh : Colors.islandSurface
            border.width: 1; border.color: dd.open ? Colors.alpha(Colors.islandPrimary, 0.6) : Qt.rgba(1, 1, 1, 0.06)
            Behavior on color { ColorAnimation { duration: Theme.durationShort } }
            Label { x: 14; width: parent.width - 40; height: parent.height; text: dd.labels[dd.cur] || dd.cur; elide: Text.ElideRight; font.weight: Font.Medium }
            Text { anchors.right: parent.right; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter
                text: "expand_more"; color: Colors.islandFgVar; font.family: Theme.fontIcon; font.pixelSize: 18
                rotation: dd.open ? 180 : 0
                Behavior on rotation { NumberAnimation { duration: Theme.durationShort; easing.type: Easing.OutCubic } } }
            MouseArea { id: fieldHit; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: dd.open = !dd.open
                Accessible.role: Accessible.ComboBox; Accessible.name: dd.rowTitle; Accessible.description: dd.cur }
        }
        // A soft shadow under the list (a blurred copy of its shape).
        RectangularShadow {
            anchors.fill: popup; z: 9; radius: popup.radius; blur: 24; spread: 2
            offset: Qt.vector2d(0, dd.upward ? -4 : 6); color: Qt.rgba(0, 0, 0, 0.6)
            opacity: popup.opacity; visible: popup.visible
        }
        Rectangle {
            id: popup
            y: dd.upward ? -height - 8 : dd.height + 8; z: 10; width: Math.max(dd.width, 180)
            height: list.implicitHeight + 12; radius: 16
            color: "#0b0b0b"
            border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.09)
            visible: opacity > 0
            opacity: dd.open ? 1 : 0
            // Grows out of the field: scaled from the edge next to it, and slides the last few pixels.
            transformOrigin: dd.upward ? Item.Bottom : Item.Top
            scale: dd.open ? 1 : 0.92
            transform: Translate { y: dd.open ? 0 : (dd.upward ? 6 : -6); Behavior on y { NumberAnimation { duration: Theme.durationNormal; easing.type: Easing.OutCubic } } }
            Behavior on opacity { NumberAnimation { duration: Theme.durationShort } }
            Behavior on scale { NumberAnimation { duration: Theme.durationNormal; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }

            // One highlight that glides to the row under the pointer (or rests on the current one).
            Rectangle {
                id: glide
                readonly property int at: list.hovered >= 0 ? list.hovered : dd.options.indexOf(dd.cur)
                x: 6; width: parent.width - 12; height: 30; radius: 10
                y: 6 + Math.max(0, at) * 30
                visible: at >= 0
                color: list.hovered >= 0 ? Colors.islandSurfaceHigh : Colors.alpha(Colors.islandPrimary, 0.12)
                Behavior on y { NumberAnimation { duration: Theme.durationShort; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: Theme.durationShort } }
            }
            Column {
                id: list
                property int hovered: -1
                x: 6; y: 6; width: parent.width - 12
                Repeater {
                    model: dd.options
                    delegate: Item {
                        required property string modelData
                        required property int index
                        readonly property bool current: modelData === dd.cur
                        width: list.width; height: 30
                        // The current option: a filled dot in the primary; the others an empty ring.
                        Rectangle {
                            x: 10; anchors.verticalCenter: parent.verticalCenter
                            width: 8; height: 8; radius: 4
                            color: parent.current ? Colors.islandPrimary : "transparent"
                            border.width: parent.current ? 0 : 1.5; border.color: Colors.alpha(Colors.islandFg, 0.35)
                        }
                        Label { x: 28; height: parent.height; text: dd.labels[parent.modelData] || parent.modelData
                            color: parent.current ? Colors.islandPrimary : Colors.islandFg
                            font.weight: parent.current ? Font.DemiBold : Font.Normal }
                        MouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onContainsMouseChanged: list.hovered = containsMouse ? index : (list.hovered === index ? -1 : list.hovered)
                            Accessible.role: Accessible.MenuItem; Accessible.name: parent.modelData
                            onClicked: { Cfg.Settings.set(root.cfgPath(dd.key), parent.modelData); dd.open = false; dd.chosen() } }
                    }
                }
            }
        }
    }

    // --- Modules page: the composer (Composer singleton over settings `layout`) ---
    // A row: switch, label, then (control center tiles) a 1x1/2x1 size toggle, then up/down. The row
    // buttons are MouseAreas with a navRole, so the island's keyboard navigator reaches them and
    // Alt/Shift + Up/Down on any of them moves the row (reorder / controlFor below).
    component RowButton: MouseArea {
        id: rb
        property string glyph; property string text; property string navRole; property string label
        implicitWidth: text !== "" ? 40 : 26; implicitHeight: 22
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        hoverEnabled: true
        Accessible.role: Accessible.Button; Accessible.name: rb.label
        Rectangle {
            anchors.fill: parent; radius: 7
            color: rb.containsMouse && rb.enabled ? Colors.islandSurfaceHighest : Colors.islandSurfaceHigh
            opacity: rb.enabled ? 1 : 0.35
            Text { anchors.centerIn: parent; visible: rb.glyph !== ""; text: rb.glyph; color: Colors.islandFg
                font.family: Theme.fontIcon; font.pixelSize: 18 }
            Text { anchors.centerIn: parent; visible: rb.text !== ""; text: rb.text; color: Colors.islandFg
                font.family: Theme.fontUi; font.pixelSize: 11; font.weight: Font.Medium; font.features: { "tnum": 1 } }
        }
    }
    component LayoutRow: Item {
        id: lr
        property string layoutSection   // "cc"
        property var entry: ({})
        property int pos: 0
        property int count: 1
        readonly property string label: Cfg.Composer.label(entry.id)
        objectName: "layoutRow_" + layoutSection + "_" + entry.id
        width: parent ? parent.width : 0; height: root.composerRowH
        Switch { x: 0; anchors.verticalCenter: parent.verticalCenter; on: !!lr.entry.enabled
            name: lr.label + (lr.layoutSection === "cc" ? " tile" : " chip") + ", shown"
            onToggled: v => Cfg.Composer.setEnabled(lr.layoutSection, lr.entry.id, v) }
        Label { x: 48; height: parent.height; width: parent.width - 48 - btns.width - 8; text: lr.label; elide: Text.ElideRight
            color: lr.entry.enabled ? Colors.islandFg : Colors.islandFgVar }
        Row {
            id: btns
            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; spacing: 4
            RowButton { visible: lr.layoutSection === "cc"; navRole: "size"; objectName: "layoutBtn_" + lr.layoutSection + "_" + lr.entry.id + "_size"; text: lr.entry.size || "1x1"
                label: lr.label + " size, " + (lr.entry.size || "1x1") + ". Toggle 1x1 or 2x1"
                onClicked: Cfg.Composer.setSize(lr.entry.id, lr.entry.size === "2x1" ? "1x1" : "2x1") }
            RowButton { navRole: "up"; objectName: "layoutBtn_" + lr.layoutSection + "_" + lr.entry.id + "_up"; glyph: "keyboard_arrow_up"; enabled: lr.pos > 0; label: "Move " + lr.label + " up"
                onClicked: Cfg.Composer.move(lr.layoutSection, lr.entry.id, -1) }
            RowButton { navRole: "down"; objectName: "layoutBtn_" + lr.layoutSection + "_" + lr.entry.id + "_down"; glyph: "keyboard_arrow_down"; enabled: lr.pos < lr.count - 1; label: "Move " + lr.label + " down"
                onClicked: Cfg.Composer.move(lr.layoutSection, lr.entry.id, 1) }
        }
    }
    function walkItems(it, f) { if (!it) return null; const r = f(it); if (r) return r
        for (let i = 0; i < it.children.length; i++) { const x = walkItems(it.children[i], f); if (x) return x } return null }
    // Island navigator hooks: the row key for the focused control ("" when not on a composer row),
    // after moving that row by dir; and the control for a key once the list has rebuilt.
    function reorder(control, dir) {
        let role = "", it = control
        while (it && it !== root) {
            if (role === "" && typeof it.navRole === "string") role = it.navRole
            if (typeof it.layoutSection === "string" && it.entry) {
                Cfg.Composer.move(it.layoutSection, it.entry.id, dir)
                return it.layoutSection + "|" + it.entry.id + "|" + (role || "switch")
            }
            it = it.parent
        }
        return ""
    }
    function controlFor(key) {
        const k = String(key).split("|")
        const row = walkItems(root, it => it.objectName === "layoutRow_" + k[0] + "_" + k[1] ? it : null)
        const host = row ? walkItems(row, it => it.navRole === k[2] ? it : null) : null
        return host ? walkItems(host, it => it.acceptedButtons !== undefined && it.pressAndHoldInterval !== undefined ? it : null) : null
    }
    property string modulesSection: "surfaces"
    // Ten rows plus the section tabs and the bottom row share the page height (28 px at most).
    property real composerRowH: 24
    readonly property var modulesSections: [
        { id: "surfaces", label: "Surfaces" },
        { id: "cc", label: "Control center" }]

    // Page rail: the search field and the pages it matches.
    Rectangle {
        id: searchBox
        x: 12; y: 14; width: 120; height: 30; radius: 15
        color: Colors.islandSurface
        border.width: searchInput.activeFocus ? 1 : 0; border.color: Colors.alpha(Colors.islandPrimary, 0.6)
        Text { id: searchGlyph; x: 8; anchors.verticalCenter: parent.verticalCenter; text: "search"; color: Colors.islandFgVar
            font.family: Theme.fontIcon; font.pixelSize: 16 }
        TextInput {
            id: searchInput
            anchors { left: searchGlyph.right; leftMargin: 6; right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
            color: Colors.islandFg; font.family: Theme.fontUi; font.pixelSize: 12; clip: true
            selectionColor: Colors.islandPrimary; selectedTextColor: Colors.islandOnPrimary
            onTextEdited: root.search = text
            Keys.onEscapePressed: event => { if (text !== "") { text = ""; root.search = ""; event.accepted = true } else event.accepted = false }
            Accessible.role: Accessible.EditableText; Accessible.name: "Search settings"
            Text { anchors.fill: parent; verticalAlignment: Text.AlignVCenter; visible: !searchInput.text; text: "Search"
                color: Colors.islandFgVar; font: searchInput.font }
        }
    }
    Column {
        x: 12; y: 52; width: 120; spacing: 2
        Repeater {
            model: root.shownPages
            delegate: Rectangle {
                required property var modelData
                width: 120; height: 32; radius: 10
                color: root.page === modelData.id ? Colors.islandSurfaceHigh : "transparent"
                Text { x: 8; anchors.verticalCenter: parent.verticalCenter; text: modelData.glyph
                    color: root.page === modelData.id ? Colors.islandPrimary : Colors.islandFgVar; font.family: Theme.fontIcon; font.pixelSize: 18 }
                Label { x: 34; height: parent.height; text: modelData.label; font.weight: root.page === modelData.id ? Font.DemiBold : Font.Normal }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.page = modelData.id
                    Accessible.role: Accessible.PageTab; Accessible.name: modelData.label }
            }
        }
    }

    Flickable {
        x: 148; y: 14; width: parent.width - 160; height: parent.height - 28 - (root.warning !== "" ? 24 : 0)
        clip: true; contentWidth: width; boundsBehavior: Flickable.StopAtBounds
        // The page shown decides the scroll height (the others are hidden).
        contentHeight: Math.max(height, [islandPage, eventsPage, playerPage, behaviourPage, modulesPage, lockPage, dockPage, notificationsPage, controlPage, themePage].reduce((h, pg) => pg.visible ? (pg.implicitHeight || pg.height) : h, 0))

        // Island: placement, look and motion
        Column {
            id: islandPage
            visible: root.page === "island"; width: parent.width; spacing: 2
            ChipsRow { title: "Mode"; key: "island.mode"; options: ["reserve", "overlay", "autohide"] }
            SlideRow { title: "Top gap"; key: "island.topGap"; from: 0; to: 24; step: 1; unit: "px" }
            SlideRow { title: "Reserve"; key: "island.reserve"; from: 0; to: 80; step: 1; unit: "px" }
            Label { height: 30; text: "Look"; font.weight: Font.DemiBold; color: Colors.islandFgVar }
            ColourRow { title: "Background"; key: "island.color"; options: [{ v: "default", c: "#000000" }, { v: "#14161a", c: "#14161a" }, { v: "#0f1b2d", c: "#0f1b2d" }, { v: "#1d1326", c: "#1d1326" }, { v: "#1f1410", c: "#1f1410" }, { v: "surface", c: Colors.islandSurface }] }
            SlideRow { title: "Opacity"; key: "island.opacity"; from: 40; to: 100; step: 1; unit: "%" }
            SlideRow { title: "Border width"; key: "island.borderWidth"; from: 0; to: 3; step: 1; unit: "px" }
            ColourRow { title: "Border colour"; key: "island.borderColor"; options: [{ v: "default", c: Qt.rgba(1, 1, 1, 0.15) }, { v: "#66ffffff", c: "#66ffffff" }, { v: "accent", c: Colors.islandPrimary }] }
            SwitchRow { title: "Shadow"; key: "island.shadow"; def: false }
            Label { height: 30; text: "Motion"; font.weight: Font.DemiBold; color: Colors.islandFgVar }
            ChipsRow { title: "Animation"; key: "motion.type"; options: ["spring", "smooth"]; labels: ({ spring: "Spring", smooth: "Smooth" }) }
            SlideRow { title: "Animation speed"; key: "motion.speed"; from: 50; to: 200; step: 10; unit: "%" }
            SlideRow { title: "Fold delay"; key: "island.osdHoldMs"; from: 500; to: 4000; step: 100; unit: "ms" }
        }

        // Events: what shows on the pill
        Column {
            id: eventsPage
            visible: root.page === "events"; width: parent.width; spacing: 2
            Label { height: 30; text: "What the pill shows"; font.weight: Font.DemiBold; color: Colors.islandFgVar }
            SwitchRow { title: "Music"; key: "island.compactMedia" }
            SwitchRow { title: "Equalizer"; key: "island.equalizer" }
            SwitchRow { title: "Volume"; key: "island.volumeOsd" }
            SwitchRow { title: "Notifications"; key: "island.notifToasts" }
            SwitchRow { title: "Timer"; key: "island.timerActivity" }
            SwitchRow { title: "Screen recording"; key: "island.recIndicator" }
            SwitchRow { title: "Microphone"; key: "island.micIndicator" }
        }

        // Player: the media surface
        Column {
            id: playerPage
            visible: root.page === "player"; width: parent.width; spacing: 2
            Label { height: 30; text: "Player (middle click on the pill)"; font.weight: Font.DemiBold; color: Colors.islandFgVar }
            SwitchRow { title: "Cover"; key: "player.showArt" }
            SwitchRow { title: "Progress bar"; key: "player.showProgress" }
            SwitchRow { title: "Time"; key: "player.showTime" }
            SwitchRow { title: "Open on a new track"; key: "island.nowPlayingOsd" }
        }

        ColumnLayout {
            id: behaviourPage
            visible: root.page === "behaviour"; width: parent.width; spacing: 0
            readonly property real rowH: 32
            Row2 { title: "Live activities"; Switch { anchors.verticalCenter: parent.verticalCenter; on: !!Cfg.Settings.island.liveActivities; onToggled: v => Cfg.Settings.set("island.liveActivities", v) } }
            Row2 { title: "Clock"; z: 6; Drop { key: "clock"; options: ["24", "12"] } }
            Row2 { title: "Left click"; z: 4; Drop { key: "clickLeft"; options: ["cc", "media", "calendar", "todo", "timer", "none"] } }
            Row2 { title: "Right click"; z: 3; Drop { key: "clickRight"; options: ["cc", "media", "calendar", "todo", "timer", "none"] } }
            Row2 { title: "Middle click"; z: 2; Drop { key: "clickMiddle"; options: ["cc", "media", "calendar", "todo", "timer", "none"] } }
            Row2 { title: "Scroll"; z: 1; Drop { key: "scroll"; options: ["volume", "none"] } }
            // Two clicks within 3 s: drops every override in settings.json, the defaults apply again.
            Row2 { title: "Reset settings"
                Chip { id: resetAll; anchors.verticalCenter: parent.verticalCenter; property bool armed: false
                    text: armed ? "Click again to reset" : "Reset all"; on: armed
                    onClicked: { if (armed) { Cfg.Settings.write({}); armed = false } else { armed = true; resetDisarm.restart() } }
                    Timer { id: resetDisarm; interval: 3000; onTriggered: resetAll.armed = false } } }
        }

        // Modules: the surfaces on/off (modules.*) and the composer for the control center (Composer). Changes apply live and persist; Reset layout drops
        // the user's layout so the defaults apply again.
        Column {
            id: modulesPage
            objectName: "modulesPage"
            visible: root.page === "modules"; width: parent.width; spacing: 6
            Binding { target: root; property: "composerRowH"; value: 28 }
            Row {
                spacing: 6
                Repeater {
                    model: root.modulesSections
                    delegate: Chip { required property var modelData; text: modelData.label; on: root.modulesSection === modelData.id
                        onClicked: root.modulesSection = modelData.id }
                }
            }
            Column {
                visible: root.modulesSection === "surfaces"; width: parent.width
                Repeater {
                    model: ["media", "calendar", "launcher", "wallpapers", "todo", "timer", "clipboard", "dock"]
                    delegate: Row2 {
                        required property string modelData
                        width: parent.width; height: 34
                        title: modelData.charAt(0).toUpperCase() + modelData.slice(1)
                        Switch { anchors.verticalCenter: parent.verticalCenter; on: Cfg.Settings.modules[modelData] !== false
                            onToggled: v => Cfg.Settings.set("modules." + modelData, v) }
                    }
                }
            }
            Column {
                visible: root.modulesSection === "cc"; width: parent.width
                Repeater {
                    model: Cfg.Composer.tiles
                    delegate: LayoutRow { required property var modelData; required property int index
                        layoutSection: "cc"; entry: modelData; pos: index; count: Cfg.Composer.tiles.length }
                }
            }
            // Bottom row: the control center's section switches (on that section) and Reset layout.
            Item {
                width: parent.width; height: 26; visible: root.modulesSection !== "surfaces"
                Row {
                    spacing: 6; visible: root.modulesSection === "cc"
                    Repeater {
                        model: Cfg.Composer.sectionKeys
                        delegate: Chip { required property string modelData; objectName: "ccSection_" + modelData
                            text: Cfg.Composer.sectionLabels[modelData]; on: Cfg.Composer.section(modelData)
                            accName: "Control center " + Cfg.Composer.label(modelData).toLowerCase() + (on ? ", shown" : ", hidden")
                            onClicked: Cfg.Composer.setSection(modelData, !on) }
                    }
                }
                Chip { objectName: "resetLayout"; anchors.right: parent.right; text: "Reset layout"; onClicked: Cfg.Composer.reset() }
            }
        }

        // Lock: settings lock.*, read by the lock screen each time it starts.
        ColumnLayout {
            id: lockPage
            visible: root.page === "lock"; width: parent.width; spacing: 0
            readonly property real rowH: 32
            Row2 { title: "Clock"; z: 1; Drop { key: "lock.clock"; options: ["quiet", "bold", "stacked"] } }
            Row2 { title: "Date"; Switch { anchors.verticalCenter: parent.verticalCenter; on: root.cfgValue("lock.date") !== false; onToggled: v => root.setLock("date", v) } }
            Row2 { title: "Name"; Switch { anchors.verticalCenter: parent.verticalCenter; on: root.cfgValue("lock.name") !== false; onToggled: v => root.setLock("name", v) } }
            Row2 { title: "Reveal on key"; Switch { anchors.verticalCenter: parent.verticalCenter; on: root.cfgValue("lock.reveal") !== false; onToggled: v => root.setLock("reveal", v) } }
            Row2 { title: "Status line"; Switch { anchors.verticalCenter: parent.verticalCenter; on: root.cfgValue("lock.status") !== false; onToggled: v => root.setLock("status", v) } }
        }

        // Dock: settings dock.* and the pinned apps
        Column {
            id: dockPage
            visible: root.page === "dock"; width: parent.width; spacing: 2
            ChipsRow { title: "Position"; key: "dock.position"; options: ["bottom", "left", "right", "top"] }
            SwitchRow { title: "Auto-hide"; key: "dock.autohide"; def: false }
            SlideRow { title: "Show delay"; key: "dock.showDelay"; from: 0; to: 1000; step: 50; unit: "ms" }
            SlideRow { title: "Hide delay"; key: "dock.hideDelay"; from: 0; to: 2000; step: 50; unit: "ms" }
            Label { height: 30; text: "Look"; font.weight: Font.DemiBold; color: Colors.islandFgVar }
            SlideRow { title: "Icon size"; key: "dock.iconSize"; from: 32; to: 64; step: 1; unit: "px" }
            SlideRow { title: "Spacing"; key: "dock.spacing"; from: 0; to: 20; step: 1; unit: "px" }
            SlideRow { title: "Edge margin"; key: "dock.margin"; from: 0; to: 32; step: 1; unit: "px" }
            SlideRow { title: "Radius"; key: "dock.radius"; from: 0; to: 28; step: 1; unit: "px" }
            SlideRow { title: "Opacity"; key: "dock.opacity"; from: 40; to: 100; step: 1; unit: "%" }
            SwitchRow { title: "Border"; key: "dock.border" }
            SwitchRow { title: "Shadow"; key: "dock.shadow"; def: false }
            Label { height: 30; text: "Icons"; font.weight: Font.DemiBold; color: Colors.islandFgVar }
            SwitchRow { title: "Magnify on hover"; key: "dock.magnify" }
            SlideRow { title: "Magnify strength"; key: "dock.zoom"; from: 100; to: 150; step: 2; unit: "%" }
            SwitchRow { title: "App names"; key: "dock.labels" }
            SwitchRow { title: "Running dots"; key: "dock.indicators" }
            ColourRow { title: "Dot colour"; key: "dock.dotColor"; options: [{ v: "default", c: Colors.islandFg }, { v: "accent", c: Colors.islandPrimary }, { v: "#30d158", c: "#30d158" }, { v: "#0a84ff", c: "#0a84ff" }, { v: "#ff9f0a", c: "#ff9f0a" }] }
            SwitchRow { title: "Divider"; key: "dock.separator" }
            SwitchRow { title: "Window count"; key: "dock.windowCount" }
            Label { height: 30; text: "Pinned apps"; font.weight: Font.DemiBold }
            Repeater {
                model: Svc.Dock.pinned
                delegate: Item {
                    required property string modelData
                    required property int index
                    readonly property var entry: DesktopEntries.byId(modelData)
                    width: parent.width; height: 30
                    Label { x: 0; height: parent.height; width: parent.width - 100; elide: Text.ElideRight
                        text: parent.entry ? parent.entry.name : parent.modelData }
                    Row {
                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; spacing: 4
                        RowButton { glyph: "chevron_left"; label: "Move left"; enabled: index > 0; onClicked: Svc.Dock.movePinned(modelData, -1) }
                        RowButton { glyph: "chevron_right"; label: "Move right"; enabled: index < Svc.Dock.pinned.length - 1; onClicked: Svc.Dock.movePinned(modelData, 1) }
                        RowButton { glyph: "close"; label: "Unpin"; onClicked: Svc.Dock.setPinned(modelData, false) }
                    }
                }
            }
            Label { width: parent.width; height: 36; wrapMode: Text.WordWrap; color: Colors.islandFgVar; font.pixelSize: 11
                text: "Pin a running app with a right click on its icon in the dock (Keep in dock)." }
        }

        // Notifications: quiet hours, sound, auto-removal, muted apps
        Column {
            id: notificationsPage
            visible: root.page === "notifications"; width: parent.width; spacing: 2
            Row2 { width: parent.width; height: 34; title: "Do not disturb"
                Switch { anchors.verticalCenter: parent.verticalCenter; on: Svc.Notifs.dnd; onToggled: v => Svc.Notifs.dnd = v } }
            SwitchRow { title: "Quiet hours"; key: "notifications.dndSchedule"; def: false }
            Row2 { width: parent.width; height: 34; title: "From – to"
                Row { anchors.verticalCenter: parent.verticalCenter; spacing: 10
                    TimeStep { key: "notifications.dndFrom"; fallback: "23:00" }
                    Label { height: 28; text: "–"; color: Colors.islandFgVar }
                    TimeStep { key: "notifications.dndTo"; fallback: "08:00" } } }
            SwitchRow { title: "Show in the pill"; key: "island.notifToasts" }
            SlideRow { title: "Shown for"; key: "island.notifHoldMs"; from: 2000; to: 15000; step: 500; unit: "ms" }
            SwitchRow { title: "Sound"; key: "notifications.sound"; def: false }
            Row2 { width: parent.width; height: 34; title: "Auto-remove"; z: 3; Drop { key: "notifications.maxAgeMin"; options: ["0", "30", "60", "180", "1440"]; labels: ({ "0": "Never", "30": "After 30 min", "60": "After 1 hour", "180": "After 3 hours", "1440": "After a day" }) } }
            Row2 { width: parent.width; height: 34; title: "In the list"
                Row { spacing: 10; anchors.verticalCenter: parent.verticalCenter
                    Label { height: 26; text: Svc.Notifs.list.length + (Svc.Notifs.list.length === 1 ? " notification" : " notifications"); color: Colors.islandFgVar }
                    Chip { text: "Clear all"; onClicked: Svc.Notifs.clearAll() } } }
            Label { height: 30; text: "Apps (off: their notifications are dropped)"; font.weight: Font.DemiBold; color: Colors.islandFgVar }
            Repeater {
                model: Svc.Notifs.apps.concat(Svc.Notifs.muted.filter(a => Svc.Notifs.apps.indexOf(a) < 0))
                delegate: Row2 {
                    required property string modelData
                    width: parent.width; height: 34; title: modelData
                    Switch { anchors.verticalCenter: parent.verticalCenter; on: Svc.Notifs.muted.indexOf(parent.parent.modelData) < 0
                        onToggled: v => Svc.Notifs.setMuted(parent.parent.modelData, !v) }
                }
            }
            Label { visible: Svc.Notifs.apps.length === 0 && Svc.Notifs.muted.length === 0; width: parent.width; height: 30
                color: Colors.islandFgVar; font.pixelSize: 11; text: "Apps appear here once they send a notification." }
        }

        // Control center: the date format
        Column {
            id: controlPage
            visible: root.page === "control"; width: parent.width; spacing: 2
            Row2 { width: parent.width; height: 34; title: "Date format"; z: 5; Drop { key: "island.dateFormat"; options: ["d MMMM yyyy", "dddd, d MMMM", "dd.MM.yyyy", "MMMM d, yyyy", "yyyy-MM-dd"] } }
        }

        // Theme: palette, accent, contrast and wallpapers
        Column {
            id: themePage
            visible: root.page === "theme"; width: parent.width; spacing: 2
            Label { height: 24; text: "Theme"; font.weight: Font.DemiBold; color: Colors.islandFgVar }
            ThemeStrip { width: parent.width; height: 72 }
            Item { width: 1; height: 6 }
            ColourRow { title: "Accent"; key: "colors.accent"; options: [{ v: "", c: Colors.dark.primary || Colors.primary }, { v: "#0a84ff", c: "#0a84ff" }, { v: "#30d158", c: "#30d158" }, { v: "#ff9f0a", c: "#ff9f0a" }, { v: "#ff375f", c: "#ff375f" }, { v: "#bf5af2", c: "#bf5af2" }, { v: "#64d2ff", c: "#64d2ff" }] }
            ChipsRow { title: "Contrast"; key: "colors.contrast"; options: ["normal", "high"]; labels: ({ normal: "Normal", high: "High" }) }
            Label { height: 30; text: "Wallpapers"; font.weight: Font.DemiBold; color: Colors.islandFgVar }
            Row { spacing: 8
                Chip { text: "Choose"; onClicked: root.openWallpapers() }
                Chip { text: "Random from the theme"; onClicked: Svc.Ipc.randomWallpaper() } }
            Label { width: parent.width; height: 36; wrapMode: Text.WordWrap; color: Colors.islandFgVar; font.pixelSize: 11
                text: "Your own wallpapers go in " + Paths.wallpapers + "; each theme brings nine of its own." }
        }
    }

    // Warning line along the bottom of every page.
    Row {
        objectName: "settingsWarning"
        visible: root.warning !== ""
        x: 148; y: parent.height - 30; height: 20; spacing: 6
        Text { anchors.verticalCenter: parent.verticalCenter; text: "warning"; color: Colors.islandError; font.family: Theme.fontIcon; font.pixelSize: 16 }
        Label { height: parent.height; width: root.width - 148 - 34; text: root.warning; color: Colors.islandError; elide: Text.ElideRight }
    }
}
