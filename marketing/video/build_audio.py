#!/usr/bin/env python3
"""Generate an original, license-safe music bed + sound design for the NumPad spot.

Everything here is synthesized from scratch (numpy) so it is royalty-free and safe to
ship. Swap music_bed.wav for a licensed/RF track later if desired — the video build
reads these files by name.

Outputs (marketing/video/audio/):
  music_bed.wav         ~48s, 120 BPM, sparse intro -> drop at 8s -> resolve/fade
  sfx_tap.wav           key tap click
  sfx_confirm.wav       satisfying two-note confirm
  sfx_whoosh.wav        transition whoosh
  sfx_error.wav         the hook's "wrong input" buzz
"""
from __future__ import annotations
import wave, struct
from pathlib import Path
import numpy as np

SR = 44100
OUT = Path(__file__).resolve().parent / "audio"
OUT.mkdir(parents=True, exist_ok=True)


def write_wav(name: str, audio: np.ndarray):
    """audio: float32 [-1,1], shape (n,) mono or (n,2) stereo."""
    if audio.ndim == 1:
        audio = np.stack([audio, audio], axis=1)
    audio = np.clip(audio, -1, 1)
    data = (audio * 32767).astype(np.int16)
    with wave.open(str(OUT / name), "w") as w:
        w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(data.tobytes())
    print(f"  wrote audio/{name}  {len(audio)/SR:.2f}s")


def adsr(n, a=0.005, d=0.05, s=0.7, r=0.1):
    a_n, d_n, r_n = int(a*SR), int(d*SR), int(r*SR)
    s_n = max(0, n - a_n - d_n - r_n)
    env = np.concatenate([
        np.linspace(0, 1, a_n, endpoint=False),
        np.linspace(1, s, d_n, endpoint=False),
        np.full(s_n, s),
        np.linspace(s, 0, r_n),
    ])
    return env[:n] if len(env) >= n else np.pad(env, (0, n-len(env)))


def tone(freq, dur, kind="sine", env=None, gain=0.5):
    n = int(dur*SR)
    t = np.arange(n)/SR
    ph = 2*np.pi*freq*t
    if kind == "sine": x = np.sin(ph)
    elif kind == "tri": x = 2/np.pi*np.arcsin(np.sin(ph))
    elif kind == "saw": x = 2*(t*freq - np.floor(0.5 + t*freq))
    elif kind == "square": x = np.sign(np.sin(ph))
    else: x = np.sin(ph)
    if env is None: env = adsr(n)
    return (x*env*gain).astype(np.float32)


def lowpass(x, cutoff):
    # simple one-pole lowpass
    rc = 1.0/(2*np.pi*cutoff); alpha = (1/SR)/(rc + 1/SR)
    y = np.zeros_like(x); acc = 0.0
    for i in range(len(x)):
        acc += alpha*(x[i]-acc); y[i] = acc
    return y


def kick(dur=0.28):
    n = int(dur*SR); t = np.arange(n)/SR
    f = 110*np.exp(-t*30) + 42
    env = np.exp(-t*7)
    return (np.sin(2*np.pi*np.cumsum(f)/SR)*env*0.9).astype(np.float32)


def hat(dur=0.05):
    n = int(dur*SR)
    x = np.random.uniform(-1, 1, n)*np.exp(-np.arange(n)/SR*90)
    return (x*0.25).astype(np.float32)


def place(buf, snd, at):
    i = int(at*SR); j = min(len(buf), i+len(snd))
    buf[i:j] += snd[:j-i]


def build_music():
    bpm = 120; beat = 60/bpm; total = 48.0
    n = int(total*SR); L = np.zeros(n, np.float32); R = np.zeros(n, np.float32)
    # Am - F - C - G, two beats each (one bar = 4 beats -> 2 chords)
    roots = {"Am": 220.0, "F": 174.61, "C": 261.63, "G": 196.0}
    prog = ["Am", "F", "C", "G"]
    chord_notes = {"Am": [220.0, 261.63, 329.63], "F": [174.61, 220.0, 261.63],
                   "C": [261.63, 329.63, 392.0], "G": [196.0, 246.94, 392.0]}
    nbeats = int(total/beat)
    drop = 8.0  # energy lift
    for b in range(nbeats):
        tt = b*beat
        chord = prog[(b//2) % len(prog)]
        # bass every beat (lowpassed saw, sub octave)
        bass = lowpass(tone(roots[chord]/2, beat*0.95, "saw", adsr(int(beat*0.95*SR), 0.005, 0.08, 0.6, 0.08), 0.5), 320)
        place(L, bass, tt); place(R, bass, tt)
        if tt >= drop:
            place(L, kick(), tt); place(R, kick(), tt)
            place(L, hat(), tt+beat/2); place(R, hat(), tt+beat/2)
            # arpeggio eighth notes (pluck), higher octave, panned
            notes = chord_notes[chord]
            for k in range(2):
                f = notes[(b*2+k) % len(notes)]*2
                pl = tone(f, beat/2*0.9, "tri", adsr(int(beat/2*0.9*SR), 0.003, 0.06, 0.3, 0.08), 0.28)
                place(L if k % 2 == 0 else R, pl*1.0, tt+k*beat/2)
                place(R if k % 2 == 0 else L, pl*0.6, tt+k*beat/2)
        else:
            # sparse intro: soft tick + pad swell
            if b % 2 == 0:
                place(L, hat()*0.5, tt); place(R, hat()*0.5, tt)
            pad = tone(roots[chord], beat*0.95, "tri", adsr(int(beat*0.95*SR), 0.05, 0.2, 0.5, 0.2), 0.12)
            place(L, pad, tt); place(R, pad, tt)
    out = np.stack([L, R], axis=1)
    # master: gentle soft-clip + global fades
    out = np.tanh(out*1.2)*0.9
    fi = int(0.05*SR); out[:fi] *= np.linspace(0, 1, fi)[:, None]
    fo = int(2.5*SR); out[-fo:] *= np.linspace(1, 0, fo)[:, None]
    write_wav("music_bed.wav", out)


def build_sfx():
    # tap: bright click
    tap = tone(1250, 0.05, "sine", np.exp(-np.arange(int(0.05*SR))/SR*60), 0.5)
    write_wav("sfx_tap.wav", tap)
    # confirm: C6 -> E6 quick arpeggio
    c = tone(1046.5, 0.12, "tri", adsr(int(0.12*SR), 0.005, 0.05, 0.4, 0.05), 0.4)
    e = tone(1318.5, 0.18, "tri", adsr(int(0.18*SR), 0.005, 0.05, 0.4, 0.08), 0.4)
    confirm = np.concatenate([c, e])
    write_wav("sfx_confirm.wav", confirm)
    # whoosh: noise through rising bandpass (approx: noise * rising sine am + lowpass sweep)
    n = int(0.32*SR); t = np.arange(n)/SR
    noise = np.random.uniform(-1, 1, n)
    env = np.sin(np.pi*t/t[-1])**2
    sweep = lowpass(noise, 800) * (0.3+0.7*t/t[-1])
    whoosh = (sweep*env*0.5).astype(np.float32)
    write_wav("sfx_whoosh.wav", whoosh)
    # error: low square buzz, two pulses
    buzz = tone(120, 0.16, "square", adsr(int(0.16*SR), 0.005, 0.04, 0.7, 0.05), 0.32)
    gap = np.zeros(int(0.05*SR), np.float32)
    err = np.concatenate([buzz, gap, buzz])
    write_wav("sfx_error.wav", err)


if __name__ == "__main__":
    np.random.seed(7)
    build_music()
    build_sfx()
