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
