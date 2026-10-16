//@ pragma DefaultEnv QS_NO_RELOAD_POPUP=1
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import qs.config
import qs.config as Cfg // State: QtQuick has a State type
import qs.services
import "lock" as Lock

// The lock screen: Paths.lockCmd runs this file as its own process (qs -p), so restarting the
// shell cannot unlock. One lock/Screen.qml per output; the password goes through PAM ("login"),
// the fingerprint through a second PAM context running lock/pam/fprint in parallel when fprintd
// is installed. If this process dies the compositor keeps the session locked (ext-session-lock).
ShellRoot {
    id: root
    property string message: ""
    property string password: ""
    property int failures: 0
    signal failed(string reason)
    signal succeeded

    function submit(pw) {
        password = pw;
        if (!pam.start()) failed("Authentication unavailable");
    }
    function fail() { failed("Wrong password (" + (++failures) + ")"); }
    function unlock() {
        fprint.abort();
        succeeded();
        unlockTimer.start();
    }
    // the success motion, then release the outputs and leave
    Timer { id: unlockTimer; interval: 300; onTriggered: { lock.locked = false; Qt.quit(); } }

    PamContext {
        id: pam
        config: "login"
        onResponseRequiredChanged: if (responseRequired) { respond(root.password); root.password = ""; }
        onCompleted: result => result === PamResult.Success ? root.unlock() : root.fail()
        onError: root.fail()
    }
    PamContext {
        id: fprint
        configDirectory: Paths.root + "/lock/pam"
        config: "fprint"
        onPamMessage: root.message = message
        // a miss ends pam_fprintd's tries: start again; no reader or no enrolled finger: stay quiet
        onCompleted: result => {
            if (result === PamResult.Success) root.unlock();
            else if (result === PamResult.Failed || result === PamResult.MaxTries) { root.message = "Fingerprint not recognised, try again"; retry.restart(); }
            else root.message = "";
        }
        onError: root.message = ""
    }
    Timer { id: retry; interval: 1500; onTriggered: fprint.start() }
    Process {
        running: true
        command: ["sh", "-c", "command -v fprintd-verify"]
        onExited: code => { if (code === 0) fprint.start(); }
    }

    WlSessionLock {
        id: lock
        locked: true
        // another lock already holds the session (or the compositor refused): nothing to do here
        onLockedChanged: if (!locked) Qt.quit()

        WlSessionLockSurface {
            id: surface
            color: "black"
            Lock.Screen {
                id: screen
                anchors.fill: parent
                userName: Quickshell.env("USER") || ""
                background: "file://" + (Cfg.State.wallpaper || Paths.themes + "/" + Cfg.State.theme + "/wallpaper.png")
                glyphs: [Net.icon]
                message: root.message
                colors: Colors
                options: Cfg.Settings.data.lock || ({})
                clock12: String(Cfg.Settings.island.clock) === "12"
                fontName: Theme.fontDisplay
                onSubmit: password => root.submit(password)
            }
            Connections {
                target: root
                function onFailed(reason) { screen.fail(reason); }
                function onSucceeded() { screen.succeed(); }
            }
        }
    }
}
