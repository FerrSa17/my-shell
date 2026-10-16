#!/usr/bin/env python3
# Live spectrum of what the speakers play: five bands, one line per 32 ms on stdout, each value 0..1
# ("0.12 0.40 0.77 0.31 0.05"), bass to treble. Captures the default sink's monitor with parec, takes
# 256-sample windows at 16 kHz (one per 32 ms) and measures three frequencies per band with a
# Hann-windowed DFT (no numpy needed). The monitor is taken before the master volume, so the sink's
# volume (and mute) is read twice a second and half its attenuation is applied: a quiet speaker setting
# means smaller bars, and muting empties them.
# Attack is instant, release is gradual, like a real equaliser. Exits when its stdout closes or on
# SIGTERM, taking parec with it.
import math, re, signal, struct, subprocess, sys, time
from operator import mul

RATE, N, HOP = 16000, 256, 512      # a 16 ms window, measured every 32 ms (the rest is skipped)
BANDS = [(60, 100, 160), (250, 350, 500), (800, 1100, 1500), (2200, 3000, 4200), (5200, 6400, 7600)]
FLOOR_DB, CEIL_DB = -66.0, -20.0   # what maps to an empty bar and to a full one
VOLUME_WEIGHT = 0.5                # how much of the master volume's attenuation (in dB) the bars show
RELEASE = 0.78                     # how much of the last value a bar keeps each frame

win = [0.5 - 0.5 * math.cos(2 * math.pi * i / (N - 1)) for i in range(N)]
tables = [[([w * math.cos(2 * math.pi * f * i / RATE) for i, w in enumerate(win)],
            [w * math.sin(2 * math.pi * f * i / RATE) for i, w in enumerate(win)]) for f in band] for band in BANDS]

proc = subprocess.Popen(["parec", "-d", "@DEFAULT_MONITOR@", "--format=s16le", f"--rate={RATE}", "--channels=1", "--latency-msec=30"],
                        stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
def stop(*_):
    proc.terminate(); sys.exit(0)
signal.signal(signal.SIGTERM, stop)

def sink_gain_db():
    """The default sink's volume in dB (0 = full), or None while it is muted."""
    try:
        muted = subprocess.run(["pactl", "get-sink-mute", "@DEFAULT_SINK@"], capture_output=True, text=True, timeout=1).stdout
        if "yes" in muted:
            return None
        vol = subprocess.run(["pactl", "get-sink-volume", "@DEFAULT_SINK@"], capture_output=True, text=True, timeout=1).stdout
        m = re.search(r"(-?\d+(?:\.\d+)?) dB", vol)
        return min(0.0, float(m.group(1))) if m else 0.0
    except (OSError, subprocess.SubprocessError):
        return 0.0

level = [0.0] * len(BANDS)
gain_db, gain_at = 0.0, 0.0
try:
    while True:
        raw = proc.stdout.read(HOP * 2)
        if len(raw) < HOP * 2:
            break
        raw = raw[-N * 2:]
        if time.monotonic() - gain_at > 0.5:
            gain_db, gain_at = sink_gain_db(), time.monotonic()
        x = list(map(float, struct.unpack("<%dh" % N, raw)))
        for b, freqs in enumerate(tables):
            best = 0.0
            for cos_t, sin_t in freqs:
                real = sum(map(mul, x, cos_t))
                imag = sum(map(mul, x, sin_t))
                best = max(best, math.hypot(real, imag))
            amp = 4.0 * best / N                       # the sine's amplitude (full scale = 32768)
            db = 20.0 * math.log10(amp / 32768.0) if amp > 0 else -120.0
            v = 0.0 if gain_db is None else min(1.0, max(0.0, (db + VOLUME_WEIGHT * gain_db - FLOOR_DB) / (CEIL_DB - FLOOR_DB)))
            level[b] = max(v, level[b] * RELEASE)
        sys.stdout.write(" ".join("%.2f" % v for v in level) + "\n")
        sys.stdout.flush()
except (BrokenPipeError, KeyboardInterrupt):
    pass
finally:
    proc.terminate()
