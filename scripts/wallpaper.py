import sys, os
import random

wallpaper = []

for line in os.popen("ls ~/Wallpaper/"):
    wallpaper.append(line.strip())

wallpaper_item = random.choice(wallpaper)

style = ["awww img --transition-type grow --transition-duration 0.6 --transition-fps 60 --transition-step 90", "awww img --transition-type wipe --transition-angle 45 --transition-duration 0.6 --transition-fps 165"]

style_item = random.choice(style)

os.system(f"{style_item} $HOME/Wallpaper/{wallpaper_item}")
os.system(f'notify-send "Wallpaper Switching" "Applying wallpaper: {wallpaper_item}"')
