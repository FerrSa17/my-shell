pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// The task list behind the Tasks surface: [{id, text, done}] in data/todo.json, newest first among
// the open ones; completed tasks sink below them.
Singleton {
    id: root
    property var tasks: []
    readonly property int open: tasks.filter(t => !t.done).length
    readonly property int done: tasks.length - open

    function add(text) {
        const t = String(text || "").trim()
        if (!t) return
        set([{ id: Date.now() + "-" + Math.floor(Math.random() * 1e4), text: t, done: false }].concat(tasks))
    }
    function toggle(id) { set(tasks.map(t => t.id === id ? Object.assign({}, t, { done: !t.done }) : t)) }
    function edit(id, text) {
        const v = String(text || "").trim()
        if (!v) { remove(id); return }
        set(tasks.map(t => t.id === id ? Object.assign({}, t, { text: v }) : t))
    }
    function remove(id) { set(tasks.filter(t => t.id !== id)) }
    function clearDone() { set(tasks.filter(t => !t.done)) }
    function set(list) {
        // Stable: open tasks keep their order above the completed ones.
        tasks = list.filter(t => !t.done).concat(list.filter(t => t.done))
        file.setText(JSON.stringify(tasks, null, 2) + "\n")
    }

    FileView {
        id: file
        path: Paths.data + "/todo.json"
        printErrors: false
        atomicWrites: true
        onLoaded: { try { const l = JSON.parse(text()); root.tasks = Array.isArray(l) ? l : [] } catch (e) { root.tasks = [] } }
    }
}
