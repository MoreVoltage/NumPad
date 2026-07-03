# NumPad B2B Validation Brief (internal, pre-discovery)

Status: **2026-07-03, pre-discovery** — no product decision made. This brief exists to run discovery
conversations with interested companies and use their answers to decide which candidate product
(or both, or neither) is worth building out.

Trigger: inbound interest from companies wanting to use NumPad-style numeric input for iPad kiosk
data-entry stations. Two structurally different B2B products could serve that need; they have
almost opposite constraints, so the right one depends entirely on the customer's environment.

---

## The two candidates

### Product A — Keyboard extension + managed deployment ("kiosk model")

What we already have. NumPad ships as a system-wide custom keyboard extension
(`com.morevoltage.NumPad.Keyboard`, app group `group.morevoltage.numpad.container`) that any app on
the device can use once it's enabled in Settings. For B2B, the "product" is really the
**deployment playbook**: enable-keyboard → optional Full Access → configure → lock into
SAM/ASAM/Guided Access, plus the managed-app path via Apple Business Manager to survive Managed
Open In restrictions. See `docs/kiosk/NumPad-for-Kiosks.md` for the full customer-facing version
of this.

- **Works today** — no new engineering required, only documentation/support process.
- Works inside **any** app on the device, including third-party/off-the-shelf kiosk and POS
  software the customer doesn't control the source of.
- Requires the manual Settings step (no MDM payload can pre-enable it) — a one-time,
  per-device provisioning cost, and a support burden if IT gets it wrong.
- Full Access (clipboard/haptics/sound) is optional but, if wanted, is another manual per-device
  toggle done pre-lock.
- Exposed to keyboard-specific platform friction: Managed Open In can block it inside managed
  apps unless NumPad itself is deployed as a managed app via ABM; Intune App Protection Policies
  can force built-in keyboards for corporate accounts regardless of what NumPad does; a connected
  Bluetooth HID scanner suppresses it entirely. None of these are things we can fix from inside
  NumPad — they're customer-environment problems we can only document around.
- Guided Access, SAM, ASAM, and assessment mode do **not** block it (Apple, WWDC17 session 716) —
  this is a real advantage over the perception that "locked-down iPad = no third-party keyboard,"
  but it's a fact we have to actively educate prospects on, not a differentiator competitors lack.
- Monetization shape: consumer-style purchase (App Store / Apple Business Manager volume
  purchase), one-time or per-device, not naturally recurring.

### Product B — NumPad SDK ("in-app inputView" licensing model)

Not built. A licensed component the customer's own developers embed directly as a custom
`UIInputView` / input accessory inside their own app — the model used by **Fleksy** and
**KeyboardKit Pro**, typically priced in **$50–500/mo** tiers (by MAU, seat, or app count).

- **Not built today** — would require a new SDK product: packaging, licensing/entitlement
  server, docs, support for external developers, and an API surface distinct from the current
  extension's internals.
- No system keyboard extension involved, so: **no** "enable in Settings" step for end users, **no**
  Full Access concept at all (it's just a view the host app already has full access to), and it is
  **immune** to every MDM keyboard-extension restriction above (Managed Open In, Intune App
  Protection, Guided Access's Software Keyboards toggle, hardware-keyboard suppression) because
  none of those policies target in-app views — only system keyboard extensions.
- The tradeoff is the mirror image of Product A: it **only works inside the one app that
  integrates it**. A customer running a third-party POS/EMR/ERP they don't control the source of
  gets nothing from this product — they'd need Product A instead, or convince their app vendor to
  integrate the SDK.
- Monetization shape: naturally recurring (subscription/tiered SaaS licensing), matching the
  Fleksy/KeyboardKit Pro comps — better long-term revenue profile *if* there's a real market of
  companies who both own their app's source and want this badly enough to pay monthly.

### At a glance

| Dimension | Product A: Keyboard extension + managed deployment | Product B: NumPad SDK (in-app inputView) |
|---|---|---|
| Built today? | Yes | No — net-new SDK product |
| Requires customer to own the app's source | No | Yes |
| Works across multiple apps on one device | Yes | No — only the integrating app |
| End-user Settings step required | Yes (enable keyboard; optional Full Access) | No |
| Full Access / clipboard access needed | Optional, gated | N/A — not applicable |
| Blocked by Managed Open In | Possible, unless deployed as managed app via ABM | No |
| Blocked by Intune App Protection | Possible, for corporate accounts | No |
| Blocked by Guided Access Software Keyboards toggle | Yes (affects all on-screen keyboards) | No |
| Suppressed by hardware/Bluetooth scanner | Yes | No |
| Pricing model precedent | App Store / ABM volume purchase, one-time-ish | Fleksy / KeyboardKit Pro: $50–500/mo tiers |
| Revenue shape | One-time / low-recurring | Recurring SaaS |

---

## Discovery questionnaire

Use this with any inbound company before scoping either product. Goal: place them on the decision
framework below in under 15 minutes.

1. **Do you own and control the source code of the app your operators will type numbers into** —
   or is it a third-party/off-the-shelf app (POS, EMR, ERP, etc.) you can't modify?
2. **How many devices/seats are you deploying**, and is that number fixed or growing — a handful of
   kiosks, or a fleet across many locations?
3. **What MDM are you on** (Jamf, Intune, Mosyle, SOTI, Workspace ONE, none), and do you currently
   use Managed Open In restrictions or App Protection Policies that touch keyboards?
4. **Are the devices (and NumPad, if applicable) enrolled as managed via Apple Business Manager**,
   or are they unmanaged/personally-owned/BYOD?
5. **Do you need clipboard history, haptics, or sound** on the numeric input, or is silent
   number-only entry sufficient?
6. **Do the devices need to work fully offline / air-gapped**, or is there always network
   connectivity available (for licensing checks, updates, sync)?
7. **Do operators need this numeric input inside more than one app on the same device**, or is it
   scoped to a single app you control?
8. **What's your budget model preference** — a one-time per-device purchase (App Store / ABM
   volume licensing), or are you open to an ongoing per-seat/per-month SaaS-style license?

---

## Decision framework

- **Q1 = "we don't own the app's source"** → Product A is the *only* option; Product B is
  structurally impossible (nothing to embed an SDK into). Route straight to the kiosk deployment
  guide.
- **Q7 = "yes, multiple apps on one device"** → Product A, regardless of other answers — Product B
  by definition can't follow the operator across apps.
- **Q3/Q4 surfaces active Managed Open In or Intune App Protection blocking, and Q1 = "we own the
  app"** → flag Product B as the clean way to sidestep the MDM fight entirely; note Product A's
  fix (deploy NumPad as a managed app via ABM) as the alternative if they'd rather stay with the
  extension model.
- **Q2 = low volume (tens of devices), Q8 = prefers one-time cost** → Product A; ABM volume
  purchase economics beat a recurring SDK license at that scale.
- **Q1 = "we own the app," Q2 = high/growing volume, Q8 = open to recurring pricing** → strongest
  signal to scope Product B; matches the Fleksy/KeyboardKit Pro precedent of per-app,
  per-tier monthly licensing sold to companies embedding keyboard tech into their own product.
- **Q5 = needs clipboard/haptics/sound** → only relevant to Product A (Full Access is an
  extension-only concept); note this as a point in Product A's favor if other answers are mixed.
- **Q6 = fully offline/air-gapped** → both are technically feasible; flag for follow-up on how
  Product B's licensing/entitlement check would need to work offline (grace period, on-device
  cache) since that's undesigned.

## Open questions for next steps

- We have zero committed Product B customers yet — the SDK doesn't exist. Do not scope engineering
  work until at least one discovery call lands clearly on the Product B side of the framework
  above with a stated budget.
- If a prospect straddles both (owns their app *and* wants fleet-wide multi-app coverage), that's a
  signal to sell Product A now and revisit Product B as a later upsell, not a reason to build both
  at once.
- No pricing has been set for either product; the $50–500/mo figure is a competitor reference
  point (Fleksy, KeyboardKit Pro), not a NumPad quote.
