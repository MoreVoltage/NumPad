#!/bin/bash
# MOR-161 — record a 15–20s simulator App Store preview:
#   keyboard in a text field → type 1200*0.0825 (live math chip) → swap pack to Finance.
#
# Requires: Shots-6.9 booted, this worktree built into /tmp/numpad-mor-161-dd,
# NumPad keyboard already enabled (NumPadUITests/E2EMatrixTests/test01_enableKeyboardInSettings —
# a defaults-written AppleKeyboards entry shows the row in Settings but keyboard services ignore
# it, so the enable must go through the Settings UI), and no hardware keyboard attached to the
# sim (quit Simulator.app or turn off "Connect Hardware Keyboard" for this device — otherwise
# iOS never raises the on-screen keyboard and the switch loop times out).
# Does NOT upload to App Store Connect.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
UDID="${UDID:-E4A85493-77E0-4454-93D9-AECFB2CE3C01}"
DD="${DD:-/tmp/numpad-mor-161-dd}"
OUT_DIR="$ROOT/marketing/video/out"
RAW="/tmp/mor161-raw.mp4"
OUT="$OUT_DIR/sim-preview-live-math-pack-swap.mp4"

mkdir -p "$OUT_DIR"
rm -f "$RAW" "$OUT"

echo "clearing handshake files on simulator"
xcrun simctl spawn "$UDID" /bin/rm -f /tmp/mor161-ready /tmp/mor161-go /tmp/mor161-done || true

echo "starting XCUI preview sequence"
LOG="/tmp/mor161-xcodebuild.log"
xcodebuild test \
  -workspace "$ROOT/NumPad.xcworkspace" \
  -scheme NumPad \
  -destination "platform=iOS Simulator,id=$UDID" \
  -derivedDataPath "$DD" \
  -configuration Debug \
  -only-testing:NumPadUITests/ScreenshotCaptureTests/testMOR161_liveMathPackSwapPreview \
  >"$LOG" 2>&1 &
XCODE_PID=$!

echo "waiting for /tmp/mor161-ready (pid $XCODE_PID)"
READY=0
for _ in $(seq 1 180); do
  if xcrun simctl spawn "$UDID" /bin/cat /tmp/mor161-ready >/dev/null 2>&1; then
    READY=1
    break
  fi
  if ! kill -0 "$XCODE_PID" 2>/dev/null; then
    echo "xcodebuild exited before handshake ready" >&2
    tail -80 "$LOG" >&2
    exit 1
  fi
  sleep 0.4
done
if [[ "$READY" != 1 ]]; then
  echo "timed out waiting for mor161-ready" >&2
  tail -80 "$LOG" >&2
  exit 1
fi

echo "recording $RAW"
xcrun simctl io "$UDID" recordVideo --codec=h264 --force "$RAW" &
REC_PID=$!
sleep 0.8
xcrun simctl spawn "$UDID" /bin/sh -c 'echo go > /tmp/mor161-go'
echo "posted go"

DONE=0
for _ in $(seq 1 90); do
  if xcrun simctl spawn "$UDID" /bin/cat /tmp/mor161-done >/dev/null 2>&1; then
    DONE=1
    break
  fi
  if ! kill -0 "$XCODE_PID" 2>/dev/null; then
    break
  fi
  sleep 0.3
done
sleep 0.4
echo "stopping recorder (done=$DONE)"
kill -INT "$REC_PID" 2>/dev/null || true
wait "$REC_PID" 2>/dev/null || true
wait "$XCODE_PID" || true

if [[ ! -s "$RAW" ]]; then
  echo "raw recording missing: $RAW" >&2
  tail -80 "$LOG" >&2
  exit 1
fi

# Keep 6.9" native (1320x2868) when that's what the sim captured; otherwise scale to
# 1080x1920 (store-legal iPhone preview). Cap at 20s, floor at 15s by padding the last frame.
python3 - "$RAW" "$OUT" <<'PY'
import json, subprocess, sys
raw, out = sys.argv[1], sys.argv[2]
probe = subprocess.check_output([
    "ffprobe", "-v", "error", "-select_streams", "v:0",
    "-show_entries", "stream=width,height,duration:format=duration",
    "-of", "json", raw,
], text=True)
info = json.loads(probe)
stream = info["streams"][0]
w, h = int(stream["width"]), int(stream["height"])
dur = float(stream.get("duration") or info["format"]["duration"])
print(f"raw {w}x{h} {dur:.2f}s")
# Prefer native 6.9" (1320x2868). 1080x1920 is the documented fallback.
if (w, h) == (1320, 2868):
    scale = []
else:
    scale = ["-vf", "scale=1080:1920:force_original_aspect_ratio=decrease,pad=1080:1920:(ow-iw)/2:(oh-ih)/2"]
# Trim to 15–20s. If shorter than 15s, tpad the last frame.
args = ["ffmpeg", "-y"]
# If the take ran long, keep the LAST 20s (chip + pack swap), not the first 20s of typing.
if dur > 20.05:
    args += ["-ss", f"{dur - 20:.3f}"]
args += ["-i", raw, "-t", "20"]
filt = []
if scale:
    filt.append(scale[1])
if dur < 14.95:
    pad = 15.05 - dur
    tpad = f"tpad=stop_mode=clone:stop_duration={pad:.3f}"
    filt.append(tpad)
if filt:
    args += ["-vf", ",".join(filt)]
args += [
    "-c:v", "libx264", "-pix_fmt", "yuv420p", "-profile:v", "high",
    "-level", "4.0", "-movflags", "+faststart", "-an", out,
]
print("encode", " ".join(args))
subprocess.check_call(args)
probe2 = subprocess.check_output([
    "ffprobe", "-v", "error", "-select_streams", "v:0",
    "-show_entries", "stream=width,height,duration:format=duration",
    "-of", "json", out,
], text=True)
info2 = json.loads(probe2)
s = info2["streams"][0]
print(f"out {s['width']}x{s['height']} {float(s.get('duration') or info2['format']['duration']):.2f}s -> {out}")
PY

echo "wrote $OUT"
echo "do not upload until James authorizes"
