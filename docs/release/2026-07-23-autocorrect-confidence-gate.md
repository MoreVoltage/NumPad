# QWERTY Autocorrect Confidence Gate Sweep
Date: 2026-07-23
Corpus: typos_wiki_en (4266 pairs)
Policy: typedLength≥3, editDistance==1, checkerIndex==0, rank≤5000, runner-up margin≥5

| Metric | Value | Gate | Pass |
|---|---|---|---|
| Auto-apply precision | 0.8265 | ≥ 0.95 | false |
| Auto-apply coverage | 0.8401 | ≥ 0.35 | true |
| Candidate top-3 | 0.9126 | ≥ 0.917 | false |
| Decision p95 (ms) | 0.047 | < 16.0 | true |
| Auto-apply count | 3584 | | |
| Auto-apply correct | 2962 | | |

Gate outcome: FAIL — keep suggestions; autocorrect remains default-OFF

Autocorrect UserPrefs default remains false. Thresholds were not lowered.