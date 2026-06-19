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

## Notes
- `out/cframes/`, `out/_*.png`, `segs/` are intermediates (see `.gitignore`).
- All previews are **staged only** — never submitted to App Store review.
