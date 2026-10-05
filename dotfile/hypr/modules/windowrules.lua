--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------
hl.layer_rule({
    match = {
        namespace = "selection"
    },
    no_anim = true
})

hl.layer_rule({
    match = {
        namespace = "waybar"
    },
    blur = true,
    ignore_alpha = 0.5
})

hl.layer_rule({
    match = {
        namespace = "swaync-notification-window"
    },
    blur = true,
    ignore_alpha = 0.5
})

hl.layer_rule({
    match = {
        namespace = "swaync-control-center"
    },
    blur = true,
    ignore_alpha = 0.5
})
