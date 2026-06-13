#!/usr/bin/env python3
"""Tap helper for iPhone 17 Pro Max simulator marketing capture.
Device screen origin on macOS desktop = (683, 128) points; sim is 3x (1320x2868 px).
Usage:
  _tap.py tap   <img_x> <img_y>            # tap at a screenshot-pixel coordinate
  _tap.py taps  <img_x> <img_y>...         # tap several points in sequence
  _tap.py hold  <img_x> <img_y> <seconds>  # press and hold (long-press)
  _tap.py drag  <x1> <y1> <x2> <y2>        # drag from->to (image px)
All coordinates are SCREENSHOT PIXELS (from a 1320x2868 PNG).
"""
import sys, subprocess, time

OX, OY, SCALE = 712, 114, 3.0

def to_screen(ix, iy):
    return round(OX + ix / SCALE), round(OY + iy / SCALE)

def activate():
    subprocess.run(["osascript", "-e", 'tell application "Simulator" to activate'],
                   capture_output=True)
    time.sleep(0.25)

def main():
    cmd = sys.argv[1]
    activate()
    if cmd == "tap":
        x, y = to_screen(float(sys.argv[2]), float(sys.argv[3]))
        subprocess.run(["cliclick", f"m:{x},{y}", "w:80", f"c:{x},{y}"], capture_output=True)
    elif cmd == "taps":
        coords = sys.argv[2:]
        for i in range(0, len(coords), 2):
            x, y = to_screen(float(coords[i]), float(coords[i+1]))
            subprocess.run(["cliclick", f"m:{x},{y}", "w:60", f"c:{x},{y}"], capture_output=True)
            time.sleep(0.5)
    elif cmd == "hold":
        x, y = to_screen(float(sys.argv[2]), float(sys.argv[3]))
        secs = float(sys.argv[4])
        ms = int(secs * 1000)
        # cliclick: move, down, wait, up
        subprocess.run(["cliclick", f"m:{x},{y}", "dd:.", f"w:{ms}", "du:."], capture_output=True)
    elif cmd == "drag":
        x1, y1 = to_screen(float(sys.argv[2]), float(sys.argv[3]))
        x2, y2 = to_screen(float(sys.argv[4]), float(sys.argv[5]))
        subprocess.run(["cliclick", f"m:{x1},{y1}", "dd:.", f"m:{x2},{y2}", "du:."], capture_output=True)
    print("ok", cmd, *(to_screen(float(sys.argv[2]), float(sys.argv[3])) if len(sys.argv) > 3 else ("",)))

if __name__ == "__main__":
    main()
