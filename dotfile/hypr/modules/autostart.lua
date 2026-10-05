-------------------
---- AUTOSTART ----
-------------------
hl.on("hyprland.start", function()
    hl.exec_cmd("hyprlock")
    hl.exec_cmd("sleep 0.3 && awww-daemon")
    hl.exec_cmd("sleep 0.3 && waybar")
    hl.exec_cmd("sleep 0.3 && swaync")
    hl.exec_cmd("sleep 0.3 && vicinae server")
    hl.exec_cmd("hyprpm reload")
    hl.exec_cmd("hyprctl setcursor 'MacTahoe Cursors' 18")
end)
