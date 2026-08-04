# Glide legal gate — correction of record (2026-08-04)

**The gate:** Glide typing is gated on a **written freedom-to-operate opinion** covering the
Cerence keyboard patent family and the Cerence v. Apple litigation posture, clearing this
repo's SHARK2-style decoder (`QwertyGlideDecoder`). **There is no clearance date. Do not
enable glide on a date.**

## What this corrects

Comments and plan docs in this repo previously cited a single patent — US 7,706,616 — and its
expiry (2026-12-21) as the reason glide ships dark, which downstream summaries compressed into
"glide unblocks on 2026-12-21." That inference is wrong:

- US 7,706,616 is **not** the patent Cerence is asserting against Apple's slide-to-type.
- The asserted, active patent is **US 7,750,891** (motion-parameter selective input, Tegic
  lineage), which runs to 2028-03-20 — and family continuations can extend coverage further.
  That date is stated here only to show why no single expiry clears the family; it is **not**
  a replacement ship date.
- Whether any of the family reads on this repo's specific mechanism is a question for
  counsel, not engineers. A mechanism gap may clear glide **earlier** than any expiry; a
  continuation may keep it blocked **later**. Only the written FTO opinion decides.

## Rules

1. No comment, doc, or plan states a date as the glide gate. The gate sentence is:
   *"Gated on a written FTO opinion covering the Cerence keyboard patent family, not on any
   single expiry. Do not enable on a date."*
2. The dark posture (local ff* flag OFF by default, forced off in App Store builds by
   `effective()`, AND'd with the Remote Config kill switch) stays exactly as is until the
   opinion is in hand. Removing this file's referenced comments does not ship glide.
3. Historical plan docs that cite the 2026-12-21 expiry carry a correction banner pointing
   here; their inline dates are historical record, not gates.

Provenance: team workspace research note `NUMPAD_GLIDE_PATENT_GATE_2026_08_04.md`
(Google Patents legal-status pull, 2026-08-04; asserted-patent list from Cerence v. Apple
complaint coverage, not a full docket review — another reason this is counsel's call).
