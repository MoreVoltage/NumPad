# NumPad — Marketing Video Assets

Storyboard & creative brief: `commercial-storyboard.md`.

## The commercial (current) — `build_commercial.py`

Fully **rendered motion graphics** — no app settings screen anywhere. Every frame is drawn:
animated app UI in **real contexts** (Notes, a checkout, a spreadsheet), the tax/tip and
clipboard overlays in action, pack/theme variety, kinetic typography, drifting keycaps, light
sweeps, spring pop-ins and fast cuts. Designed to grab attention even silently / as a poster.

```bash
python3 build_commercial.py plan      # scene timeline
python3 build_commercial.py strip     # 1 contact sheet to judge the look (fast)
# render all frames (parallel) then encode:
python3 - <<'PY'
import sys,os; sys.path.insert(0,'.'); import build_commercial as bc
from multiprocessing import Pool
bc.CF.mkdir(parents=True,exist_ok=True); nf=int(bc.TOTAL*bc.FPS)
one=lambda f:(bc.render(f/bc.FPS).convert("RGB").save(bc.CF/f"f_{f:05d}.png"),f)[1]
Pool(os.cpu_count()).map(one,range(nf))
PY
python3 build_commercial.py encode    # frames + audio -> out/*.mp4 + poster
```

### Deliverables (`out/`)
| File | Spec | Use |
|---|---|---|
| `commercial-master-portrait.mp4` | ~33s, 1080×1920 | Paid social, landing page, press kit |
| `app-store-preview-iphone.mp4` | ~27s, 1080×1920 (≤30s) | App Store Connect Media Manager — **stage, don't submit** |
| `social-15s.mp4`, `social-6s.mp4` | 1080×1920 | Paid social / bumper |
| `poster-iphone.png` | 1080×1920 | Preview poster (the tax/tip "$97.20" pop) |

Audio: original royalty-free bed + SFX from `build_audio.py` (`audio/`). Cards/hook helpers in
`build_cards.py` are still used by the legacy pipeline; the commercial draws its own UI.

### To finish
- **Voiceover** (voiceover + text was chosen; no TTS in this environment): record the read
  (script in `commercial-storyboard.md` §4) and mix:
  `ffmpeg -i commercial-master-portrait.mp4 -i vo.wav -filter_complex "[0:a][1:a]amix=inputs=2:normalize=0[a]" -map 0:v -map "[a]" -c:v copy master_vo.mp4`
- **App Review note:** this preview is rendered (not a screen recording). It faithfully depicts the
  real UI; if App Review prefers captured footage, swap in real device/Simulator recordings using the
  same scene timing. The commercial master/cut-downs have no such restriction.

## Legacy — `build_video.py`
The earlier capture-based edit (used the app's settings captures `v1–v6.mov`). **Deprecated** — kept
for reference only; do not ship (it shows settings screens).

## Simulator capture (MOR-161) — `out/sim-preview-live-math-pack-swap.mp4`

18.9s **Simulator screen recording** (not the rendered commercial), 1320×2868 H.264 30fps.
Sequence: NumPad keyboard (Math pack) in the debug typing surface (`-debugRoute typing`) →
type `1200*0.0825` so the live-math chip appears (`= 96` → `= 98.4` → `= 99` as digits land) →
long-press the pack-switch key → pick **Finance** → currency row. Recorded from Shots-6.9 with
`xcrun simctl io … recordVideo --codec=h264`; the shipped file was driven by a local Maestro
flow (tap-by-coordinate — the keyboard extension reports element bounds in its own local
coordinate space, so text selectors mis-tap), then trimmed to the action window and retimed
a uniform 1.25× to land inside the 15–20s App Store preview limit.

Re-capture (XCUI harness path — same shot, handshake-gated recording):

```bash
# Shots-6.9 (E4A85493-77E0-4454-93D9-AECFB2CE3C01) booted; NumPad keyboard enabled FOR REAL
# (run NumPadUITests/E2EMatrixTests/test01_enableKeyboardInSettings — a hand-written
#  AppleKeyboards plist entry shows the row in Settings but keyboard services ignore it),
# and the Simulator app either closed or with "Connect Hardware Keyboard" OFF for this
# device — with a hardware keyboard attached iOS suppresses the on-screen keyboard entirely.
./capture_sim_preview_live_math_pack_swap.sh
```

**Do not upload this file to App Store Connect until James authorizes.** Do not submit.

## Notes
- `out/cframes/`, `out/_*.png`, `segs/` are intermediates (see `.gitignore`).
- All previews are **staged only** — never submitted to App Store review.
