-----------------------
---- LOOK AND FEEL ----
-----------------------
hl.config({
    general = {
        gaps_in = 6,
        gaps_out = 12,

        border_size = 0,

        col = {
            active_border = "rgba(ffffff10)",
            inactive_border = "rgba(00000000)"
        },

        resize_on_border = false,
        allow_tearing = false
    },

    decoration = {
        rounding = 20,

        active_opacity = 0.92,
        inactive_opacity = 0.85,

        shadow = {
            enabled = true,
            range = 25, 
            render_power = 4,
            color = "rgba(00000040)",
        },

        blur = {
            enabled = true,
            size = 12,
            passes = 4,
            vibrancy = 0.1696,
            ignore_opacity = true,
            new_optimizations = true,
            special = false,
            popups = true,
            xray = false
        }
    }
})

