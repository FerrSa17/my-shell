---------------------
---- KEYBINDINGS ----
---------------------
-- Set programs that you use
local terminal = "foot"
local browser = "firefox"
local ide = "zeditor"

local mainMod = "SUPER"
local closeWindowBind = hl.bind(mainMod .. " + Q", hl.dsp.window.close())

hl.bind(mainMod .. " + V", hl.dsp.window.float({
    action = "toggle"
}))
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit"))

-- Quickshell (~/.config/quickshell): `qs ipc call shell <function>`
hl.bind(mainMod .. " + BACKSPACE", hl.dsp.exec_cmd("qs ipc call shell toggleControlCenter"))
hl.bind(mainMod .. " + SPACE", hl.dsp.exec_cmd("qs ipc call shell toggleLauncher"))
hl.bind(mainMod .. " + C", hl.dsp.exec_cmd("qs ipc call shell wallpaperRandom"))
hl.bind(mainMod .. " + W", hl.dsp.exec_cmd("qs ipc call shell toggleWallpapers"))
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("qs ipc call shell minimize"))
hl.bind(mainMod .. " + F", hl.dsp.exec_cmd("qs ipc call shell toggleTodo"))
hl.bind(mainMod .. " + S", hl.dsp.exec_cmd("qs ipc call shell toggleTimer"))
hl.bind(mainMod .. " + SHIFT + V", hl.dsp.exec_cmd("qs ipc call shell toggleClipboard"))

hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd("hyprshot -m region -o ~/Pictures"))

hl.bind(mainMod .. " + RETURN", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + SHIFT + RETURN", hl.dsp.exec_cmd(browser))
hl.bind(mainMod .. " + Z", hl.dsp.exec_cmd(ide))
hl.bind(mainMod .. " + T", hl.dsp.exec_cmd("Telegram"))
hl.bind(mainMod .. " + O", hl.dsp.exec_cmd("obsidian"))
hl.bind(mainMod .. " + D", hl.dsp.exec_cmd("discord"))

-- Move window with SUPER + SHIFT + arrows
hl.bind(mainMod .. " + SHIFT + left", hl.dsp.window.move({
    direction = "left"
}))
hl.bind(mainMod .. " + SHIFT + right", hl.dsp.window.move({
    direction = "right"
}))
hl.bind(mainMod .. " + SHIFT + up", hl.dsp.window.move({
    direction = "up"
}))
hl.bind(mainMod .. " + SHIFT + down", hl.dsp.window.move({
    direction = "down"
}))

-- Move focus with mainMod + arrow keys
hl.bind(mainMod .. " + left", hl.dsp.focus({
    direction = "left"
}))
hl.bind(mainMod .. " + right", hl.dsp.focus({
    direction = "right"
}))
hl.bind(mainMod .. " + up", hl.dsp.focus({
    direction = "up"
}))
hl.bind(mainMod .. " + down", hl.dsp.focus({
    direction = "down"
}))

-- Switch workspaces with mainMod + [0-9]
-- Move active window to a workspace with mainMod + SHIFT + [0-9]
for i = 1, 9 do
    local key = i
    hl.bind(mainMod .. " + " .. key, hl.dsp.focus({
        workspace = i
    }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({
        workspace = i
    }))
end

-- Voxtype
hl.bind("F9", hl.dsp.exec_cmd("voxtype record start"))
hl.bind("F9", hl.dsp.exec_cmd("voxtype record stop"), {
    release = true
})

-- Scroll through existing workspaces with mainMod + scroll
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({
    workspace = "e+1"
}))
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({
    workspace = "e-1"
}))

-- Move/resize windows with mainMod + LMB/RMB and dragging
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), {
    mouse = true
})
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), {
    mouse = true
})

-- Laptop multimedia keys for volume and LCD brightness
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), {
    locked = true,
    repeating = true
})
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), {
    locked = true,
    repeating = true
})
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), {
    locked = true,
    repeating = true
})

