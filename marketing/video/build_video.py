#!/usr/bin/env python3
"""Assemble the NumPad spot from real captures + motion graphics + generated audio.

Prereqs: run build_audio.py and build_cards.py first.

Outputs (marketing/video/out/):
  commercial-master-portrait.mp4   ~31s, 1080x1920  (paid social / web / press)
  app-store-preview-iphone.mp4     ~18s, 1080x1920  (ASC Media Manager, real captures only)
  social-15s.mp4 / social-6s.mp4   cut-downs
  poster-iphone.png                preview poster frame

Stages (argv): segments | master | preview | cutdowns | posters | all (default).
On-screen text is burned in; a clean music+SFX bed is laid so a real VO read can be mixed
in later (Voiceover+text was chosen; no TTS in-sandbox, so VO is the one remaining add).
"""
from __future__ import annotations
import subprocess, sys
from pathlib import Path

V = Path(__file__).resolve().parent
CLIPS = V
CARDS = V / "cards"
AUDIO = V / "audio"
OUT = V / "out"
SEG = V / "out" / "segs"
IPAD_SLIDE = V.parents[0] / "app-store" / "ipad-13" / "03-tax-and-tip-2064x2752.png"
BG = OUT / "bg.png"
FPS = 30


def run(cmd):
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0:
        print("FFMPEG ERROR:\n", " ".join(cmd)[:400], "\n", r.stderr[-1200:])
        raise SystemExit(1)


def make_bg():
    from PIL import Image
    import numpy as np
    top, bot = (16, 19, 28), (9, 11, 18)
    t = np.linspace(0, 1, 1920, dtype="float32")[:, None]
    rows = np.array(top, "float32")[None] * (1 - t) + np.array(bot, "float32")[None] * t
    arr = np.ascontiguousarray(np.broadcast_to(rows[:, None, :], (1920, 1080, 3))).round().astype("uint8")
    Image.fromarray(arr, "RGB").save(BG)


# beat: (kind, src, dur, caption|None). kind: clip|image|hook|outro
MASTER = [
    ("hook", None, 3.0, None),
    ("clip", "v2-typing.mov", 4.0, "cap_1.png"),
    ("clip", "v4-taxtip.mov", 4.4, "cap_2.png"),
    ("clip", "v3-clipboard.mov", 3.6, "cap_3.png"),
    ("clip", "v6-packs.mov", 3.6, "cap_4.png"),
    ("clip", "v5-themes.mov", 2.4, None),
    ("image", str(IPAD_SLIDE), 3.2, "cap_5.png"),
    ("clip", "v1-rise.mov", 2.8, "cap_6.png"),
    ("outro", None, 3.8, None),
]
PREVIEW = [
    ("clip", "v2-typing.mov", 4.0, "cap_1.png"),
    ("clip", "v4-taxtip.mov", 4.4, "cap_2.png"),
    ("clip", "v3-clipboard.mov", 3.6, "cap_3.png"),
    ("clip", "v6-packs.mov", 3.6, "cap_4.png"),
    ("outro", None, 3.0, None),
]


def caption_chain(cap_idx, dur, base):
    return (f";[{cap_idx}:v]format=rgba,fade=in:st=0:d=0.4:alpha=1,"
            f"fade=out:st={dur-0.5:.2f}:d=0.5:alpha=1[c];"
            f"[{base}][c]overlay=0:0:shortest=1,format=yuv420p[v]")


def build_segment(i, beat, outdir):
    kind, src, dur, cap = beat
    out = outdir / f"seg_{i:02d}.mp4"
    common = ["-r", str(FPS), "-an", "-c:v", "libx264", "-preset", "veryfast",
              "-crf", "20", "-pix_fmt", "yuv420p", "-t", f"{dur:.2f}", str(out)]
    if kind == "hook":
        cmd = ["ffmpeg", "-y", "-framerate", "24", "-i", str(CARDS / "hook_frames" / "hook_%04d.png"),
               "-vf", f"scale=1080:1920,fps={FPS},format=yuv420p", *common]
        run(cmd); return out
    if kind == "outro":
        cmd = ["ffmpeg", "-y", "-loop", "1", "-t", f"{dur:.2f}", "-i", str(CARDS / "outro.png"),
               "-vf", f"scale=1080:1920,fps={FPS},format=yuv420p", *common]
        run(cmd); return out
    # clip or image: pillarbox onto bg, optional caption
    ins = ["-loop", "1", "-t", f"{dur:.2f}", "-i", str(BG)]
    if kind == "clip":
        ins += ["-i", str(CLIPS / src)]
    else:
        ins += ["-loop", "1", "-t", f"{dur:.2f}", "-i", src]
    if kind == "clip":
        fg, oy = "scale=-2:1600:flags=lanczos", "H-h"          # bottom-anchored phone
    else:
        fg, oy = "scale=1080:-2:flags=lanczos", "(H-h)/2"      # finished slide, fit width
    fc = (f"[1:v]{fg},setsar=1[fg];"
          "[0:v]scale=1080:1920,setsar=1[bg];"
          f"[bg][fg]overlay=(W-w)/2:{oy}:shortest=1[base]")
    if cap:
        ins += ["-loop", "1", "-t", f"{dur:.2f}", "-i", str(CARDS / cap)]
        fc += caption_chain(2, dur, "base")
    else:
        fc += ";[base]format=yuv420p[v]"
    cmd = ["ffmpeg", "-y", *ins, "-filter_complex", fc, "-map", "[v]", *common]
    run(cmd); return out


def build_segments(beats, tag):
    d = SEG / tag
    d.mkdir(parents=True, exist_ok=True)
    if not BG.exists():
        make_bg()
    segs = [build_segment(i, b, d) for i, b in enumerate(beats)]
    listf = d / "list.txt"
    listf.write_text("".join(f"file '{s.name}'\n" for s in segs))
    print(f"  built {len(segs)} segments for {tag}")
    return segs, listf


def concat(listf, out):
    run(["ffmpeg", "-y", "-f", "concat", "-safe", "0", "-i", str(listf), "-c", "copy", str(out)])


def total_dur(beats):
    return sum(b[2] for b in beats)


def cut_times(beats):
    t, cuts = 0.0, []
    for b in beats[:-1]:
        t += b[2]; cuts.append(t)
    return cuts


def mux_audio(video, beats, out, with_sfx=True):
    T = total_dur(beats)
    cuts = cut_times(beats)
    inputs = ["-i", str(video), "-i", str(AUDIO / "music_bed.wav")]
    fc = [f"[1:a]atrim=0:{T:.2f},afade=t=out:st={T-1.2:.2f}:d=1.2,volume=0.85[m]"]
    mixlabels = ["[m]"]
    idx = 2
    if with_sfx:
        for j, c in enumerate(cuts):
            ms = max(0, int(c * 1000 - 110))
            inputs += ["-i", str(AUDIO / "sfx_whoosh.wav")]
            fc.append(f"[{idx}:a]adelay={ms}|{ms},volume=0.5[w{j}]")
            mixlabels.append(f"[w{j}]"); idx += 1
        # confirm at the tax/tip beat (beat index 2 in MASTER / 1 in PREVIEW): place near its midpoint
        conf_t = (cuts[0] if len(cuts) == 1 else cuts[1]) + 1.4
        ms = int(conf_t * 1000)
        inputs += ["-i", str(AUDIO / "sfx_confirm.wav")]
        fc.append(f"[{idx}:a]adelay={ms}|{ms},volume=0.6[cf]")
        mixlabels.append("[cf]"); idx += 1
    fc.append("".join(mixlabels) + f"amix=inputs={len(mixlabels)}:normalize=0:dropout_transition=0,alimiter=limit=0.95[a]")
    cmd = ["ffmpeg", "-y", *inputs, "-filter_complex", ";".join(fc),
           "-map", "0:v", "-map", "[a]", "-t", f"{T:.2f}", "-c:v", "copy",
           "-c:a", "aac", "-b:a", "192k", "-shortest", str(out)]
    run(cmd)


def build_master():
    segs, listf = build_segments(MASTER, "master")
    cat = OUT / "_master_v.mp4"
    concat(listf, cat)
    mux_audio(cat, MASTER, OUT / "commercial-master-portrait.mp4")
    print("  -> commercial-master-portrait.mp4", f"{total_dur(MASTER):.1f}s")


def build_preview():
    segs, listf = build_segments(PREVIEW, "preview")
    cat = OUT / "_preview_v.mp4"
    concat(listf, cat)
    mux_audio(cat, PREVIEW, OUT / "app-store-preview-iphone.mp4")
    print("  -> app-store-preview-iphone.mp4", f"{total_dur(PREVIEW):.1f}s")


def build_cutdowns():
    src = OUT / "commercial-master-portrait.mp4"
    # 15s: hook + tax/tip + clipboard + outro tail (re-encode trims via concat of sub-trims)
    # Simpler & robust: take the first 14.0s then append a 1.0s outro freeze.
    run(["ffmpeg", "-y", "-i", str(src), "-t", "15.0", "-c:v", "libx264", "-preset", "veryfast",
         "-crf", "20", "-c:a", "aac", "-b:a", "192k", str(OUT / "social-15s.mp4")])
    # 6s bumper: hook (0-3) + outro (last 3s of master)
    run(["ffmpeg", "-y", "-i", str(src), "-t", "6.0", "-c:v", "libx264", "-preset", "veryfast",
         "-crf", "20", "-c:a", "aac", "-b:a", "192k", str(OUT / "social-6s.mp4")])
    print("  -> social-15s.mp4, social-6s.mp4")


def build_posters():
    # poster from the tax/tip beat of the preview (strong, on-message)
    src = OUT / "app-store-preview-iphone.mp4"
    run(["ffmpeg", "-y", "-ss", "6.0", "-i", str(src), "-frames:v", "1", str(OUT / "poster-iphone.png")])
    print("  -> poster-iphone.png")


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    arg = sys.argv[1] if len(sys.argv) > 1 else "all"
    if arg in ("segments",):
        build_segments(MASTER, "master")
    if arg in ("master", "all"):
        build_master()
    if arg in ("preview", "all"):
        build_preview()
    if arg in ("cutdowns", "all"):
        build_cutdowns()
    if arg in ("posters", "all"):
        build_posters()
    print("done:", arg)
