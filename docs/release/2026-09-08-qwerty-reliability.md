# QWERTY reliability implementation — 8 September 2026

Base: `feat/2.1` at `2e76f61d052fa1527bc7ccb6a3784107c484fd6d`.
The newer numeric release branch lacks this QWERTY implementation, so this change targets
the QWERTY branch. It does not change App Store prices or entitlements.

## Changes

- Counter increments update an in-memory bag. A utility queue persists coalesced batches,
  with the cross-process file lock retained. Disk work never holds the input thread's
  in-memory lock. A lifecycle flush is asynchronous. At termination the last small batch
  may be lost; counters do not justify stalling text entry.
- Autocorrect evaluation and suggestion visibility use independent policy decisions.
  A hidden bar can still receive cached results for enabled autocorrect. Evaluated clean
  words can be learned with autocorrect off. Unevaluated words are not learned at boundaries.
- Explicit system text replacements use a cheap lexicon lookup at a boundary, independent
  of the spelling toggle and checker-cache readiness. Host opt-outs and literal fields win.
- URL/email/numeric fields, Programmer mode, and common technical tokens preserve literal
  input. Smart-quotes and spelling opt-outs are respected. Normal keys and alternates
  share punctuation rules, and selected text is never deleted to clean up a preceding space.
- Every visible suggestion is bound to an in-memory document/context/policy snapshot.
  Cursor changes invalidate it, and taps revalidate it before editing. Word-prefix
  replacement is suppressed when a suffix remains after the caret.
- Explicit dictionary additions and literal-chip acceptance remain protected through
  decay and eviction. Old data decodes without fabricating which old words were explicit.
  At capacity, existing explicit entries are preserved and a new entry can be refused.

## Regression coverage

Added behavioral cases for all correction/suggestion combinations, host opt-outs,
technical fields/tokens, document/caret/selection changes, ASCII punctuation, dictionary
decay/migration/capacity, batched writes, concurrent input during blocked persistence,
and failed-batch recovery. The workflow builds the real app and extension and runs the
focused unit suites plus the existing QWERTY realistic-typing UI suite on an iOS 26 simulator.

Local verification: `git diff --check`, workflow parsing, and source review. This Linux
workspace has no Xcode; an iOS build/test result must come from the macOS workflow.
An unexecuted or skipped suite is not a passing result.

## Release limitations

Autocorrect remains default-off. The existing production-evaluator quality gate remains
unchanged and its retained result is a failure; this patch is not evidence of improved
correction precision or superiority to other keyboards. Re-run the explicit gate documented
in `2026-07-23-autocorrect-confidence-gate.md` before changing that default.

Full Access-off persistence routing and whole-word touch-training alignment remain separate
work. Device profiling must verify tail latency and memory. In particular, exercise selection
callbacks and immediate correction undo in actual hosts, including the system callback timing
after the extension's own edits. Preserve the existing written-FTO gate for glide.

## Comparative typing acceptance

Test current NumPad, this branch, the system keyboard, and Gboard on the same devices and
matched English tasks. Record versions and settings. Counterbalance keyboard order, give
practice time, and include both clean transcription and spontaneous composition. Use
synthetic or participant-approved research text, never production keyboard-text analytics.

Measure task time including repair, final error rate, repair actions per 100 characters,
wrong automatic replacements, correction undo success, p95/p99 input timing, and user choice.
Compare ordinary English separately from mixed numeric workflows; numeric wins cannot hide
a regression in everyday typing.

A proposed differentiation target is at least 10% faster corrected entry or 25% fewer repair
actions than each reference keyboard, with no meaningful increase in final errors, and a
majority preference after familiarization. These are targets, not results. Start with 8–12
people to find failures, then size a confirmatory study from observed variance. Retain
denominators and uncertainty. A simulator corpus test cannot establish this product claim.
