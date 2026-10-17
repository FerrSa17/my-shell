-------------------
---- AUTOSTART ----
-------------------
hl.on("hyprland.start", function()
    hl.exec_cmd("qs -n -p " .. os.getenv("HOME") .. "/.config/quickshell/lock.qml")
    hl.exec_cmd("qs")
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
    hl.exec_cmd("awww-daemon")
    hl.exec_cmd("hyprpm reload")
    hl.exec_cmd("hyprctl setcursor 'macOS' 24")
end)
