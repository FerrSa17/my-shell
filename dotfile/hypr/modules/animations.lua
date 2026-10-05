--------------------
---- ANIMATIONS ----
--------------------
hl.config({
    animations = {
        enabled = true
    }
})

hl.curve("macSpring", { type = "spring", mass = 1.1, stiffness = 110, dampening = 24 })      
hl.curve("macWorkspace", { type = "spring", mass = 1.0, stiffness = 120, dampening = 25 })  
hl.curve("macFade", { type = "bezier", points = { {0.23, 1}, {0.32, 1} } })                
hl.curve("liner", { type = "bezier", points = { {1, 1}, {1, 1} } })

hl.animation({ leaf = "windows", enabled = true, speed = 3.2, spring = "macSpring" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 3.0, spring = "macSpring", style = "popin 93%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 2.8, spring = "macSpring", style = "popin 95%" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 3.2, spring = "macSpring" })

hl.animation({ leaf = "border", enabled = true, speed = 1, bezier = "liner" })
hl.animation({ leaf = "borderangle", enabled = true, speed = 30, bezier = "liner", style = "loop" })

hl.animation({ leaf = "layers", enabled = true, speed = 3.2, spring = "macSpring", style = "popin 93%" })
hl.animation({ leaf = "layersIn", enabled = true, speed = 3.0, spring = "macSpring", style = "popin 93%" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 2.8, spring = "macSpring", style = "popin 95%" })

hl.animation({ leaf = "workspaces", enabled = true, speed = 3.6, spring = "macWorkspace", style = "slide" })

hl.animation({ leaf = "fadeIn", enabled = true, speed = 2.8, bezier = "macFade" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = 2.8, bezier = "macFade" })
hl.animation({ leaf = "fade", enabled = true, speed = 2.8, bezier = "macFade" })
