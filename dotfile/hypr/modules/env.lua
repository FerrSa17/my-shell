-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------
-- toolkit backend

hl.env("GDK_BACKEND", "wayland,x11,*")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("SDL_VIDEODRIVER", "wayland")
hl.env("CLUTTER_BACKEND", "wayland")

-- XDG

hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")

-- Qt

hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "1.25")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("QT_QPA_PLATFORMTHEME", "gtk3")
hl.env("QT_LOGGING_RULES", "qt.qpa.services.warning=false;qt.qpa.wayland.textinput.warning=false;qt.svg.warning=false")
hl.env("CANBERRA_DISABLE", "1")
hl.env("CANBERRA_DRIVER", "null")
