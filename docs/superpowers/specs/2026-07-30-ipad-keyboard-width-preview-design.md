# iPad Keyboard Width and Truthful Preview Design

Date: 2026-07-30
Status: Approved design, pending written-spec review

## Objective

Make NumPad use the iPad's horizontal space by default, give users five horizontal numpad widths, simplify iPad QWERTY layout choices, and replace duplicated or misleading live previews with one truthful keyboard preview anchored where the real keyboard appears.

This work must not change keyboard height. The existing vertical sizing behavior, height presets, row heights, keyboard-extension height constraints, kiosk entitlement, and floating-keyboard height behavior remain unchanged.

## Scope

### Included

- Five iPad-only horizontal numpad width choices.
- Full-width numpad as the default.
- Two user-facing iPad QWERTY layouts:
  - Standard QWERTY with a visible number row.
  - Full keyboard with the active NumPad layout attached on the left or right.
- A left/right numpad-side choice for the full keyboard layout.
- One permanent, bottom-anchored iPad preview that reflects edits immediately.
- Removal or relabeling of duplicated and misleading "Live Preview" surfaces.
- Preference migration, shared geometry, accessibility, analytics, and tests.

### Excluded

- Any change to vertical keyboard size or height-selection behavior.
- A combined QWERTY-plus-numpad layout on iPhone.
- Changes to kiosk pricing or entitlement.
- Glide typing.
- New keyboard packs, themes, or key behaviors.
- Making the companion preview accept key input.

## Product Behavior

### Numpad Width

The iPad Size & Feel screen contains a "Numpad width" control with five choices:

| User-facing choice | Content width |
| --- | ---: |
| Compact | 60% |
| Comfortable | 70% |
| Medium | 80% |
| Wide | 90% |
| Full | 100% |

The control uses five visual width samples and exposes the percentage in its accessibility value. "Full" is selected for new installations.

Widths below 100% are centered horizontally. Width resolution uses the keyboard's actual available bounds rather than the physical screen width, so Stage Manager, Split View, Slide Over, and rotation remain correct.

When the iPad keyboard is floating or its available width is below the existing narrow-layout threshold, the numpad fills the available width. The stored preference is not overwritten; the selected width returns when sufficient space is available.

The five choices affect horizontal content width only. They must not:

- Change the input view's height constraint.
- Change the selected `KeyboardHeightPreset`.
- Change row count, row height, vertical spacing, or vertical content insets.
- Change kiosk-height entitlement or fallback behavior.
- Change floating-keyboard height behavior.

### Preference Migration

A new versioned `NumpadWidthSize` preference becomes the width source of truth.

Existing explicit full-width users migrate to 100%. Existing automatic, centered, left, and right preferences migrate deterministically to Compact (60%), the closest supported choice to the old 560-point cap on the primary full-size iPad layouts. The result is centered because normal user-facing left/right numpad placement is retired.

Migration runs once and never overwrites a subsequently selected width. Keyboard profiles are decoded compatibly. Old placement fields remain readable for backward compatibility but are not shown in the simplified interface.

### iPad QWERTY Layouts

The Letters screen exposes exactly two primary iPad layout choices:

1. **Standard** — full available width, with a number row always visible above the letter rows.
2. **Full keyboard** — Standard QWERTY plus the active NumPad layout in a side region.

When Full keyboard is selected, a second control appears:

- Numpad on left
- Numpad on right

The side numpad uses the active pack and current numpad settings, including number order, theme, grid, rounded corners, and custom-key configuration. It is not a hard-coded generic keypad.

The QWERTY and numpad regions share the existing keyboard height. The full-keyboard layout divides only horizontal space. Neither region may request additional height, change row height policy, or alter the input view's existing vertical constraint.

The user-facing iPad choices replace centered, split, and compact QWERTY choices. Legacy stored values decode as Standard. iPhone retains its current compact keyboard and page-switching behavior.

## Shared Layout Contract

The extension and companion app use shared, pure layout inputs and results rather than maintaining independent width calculations.

The shared contract accepts:

- Available bounds.
- Device idiom and horizontal size class.
- Floating-keyboard status.
- Numpad width size.
- iPad QWERTY layout.
- Full-keyboard numpad side.
- Active keyboard page and active pack.

It returns:

- The resolved numpad content frame.
- The resolved QWERTY frame.
- The optional side-numpad frame.
- The effective narrow/floating fallback.

The layout contract must preserve the input bounds' height in every returned frame. Tests assert that changing width settings never changes frame height.

The keyboard extension applies the returned horizontal frames through leading and trailing constraints before layout. Existing height code remains the sole owner of vertical size.

## Preview Architecture

### Permanent Dock

The iPad Studio workspace keeps one permanent preview dock as a structural sibling below the editable content. It is pinned to the safe-area bottom and never placed inside a scroll view.

The dock spans the same resolved horizontal width as the selected numpad setting. For Standard and Full QWERTY layouts, it spans the available width because those layouts are full-width iPad compositions.

The preview is non-interactive and uses shared keyboard row definitions and the shared horizontal layout contract. It reflects:

- Active page or current editing context.
- Active numpad pack and custom keys.
- Standard versus Full QWERTY.
- Full-keyboard numpad side.
- Number-row visibility.
- Numpad width.
- Theme, grid, rounded corners, and number order.
- Existing height preset, without modifying it.

### Context and Refresh

The dock shows the page relevant to the current editor:

- Numpad width, height, pack, appearance, and key editors show the numpad.
- Letters and QWERTY behavior editors show QWERTY.
- The main Keyboard screen shows the last-used keyboard page.

Every settings write posts the existing settings-sync notification and an app-local refresh signal. The workspace updates the existing dock instance immediately; it does not recreate the navigation stack or require the user to return to the main screen.

### Duplicate Preview Cleanup

Remove embedded "LIVE PREVIEW" blocks from:

- Main Keyboard screen.
- Appearance.
- Choose Keys.
- Size & Feel.
- Letters.
- The iPad navigation rail/canvas.
- Any other iPad editor that duplicates the permanent dock.

On iPad, Theme selection uses the permanent dock as its live result and has no embedded preview.

Saved-setup thumbnails and onboarding demonstrations remain because they serve different purposes. They are labeled "Setup preview" and "Example" respectively, never "Live Preview." The "Try it" text field remains because it launches the installed keyboard and is the only interactive validation surface.

On iPhone, where a permanent dock would consume too much editing space, the main Keyboard screen retains one accurate preview. Detail screens do not claim that decorative examples are live.

## Settings UI

### Size & Feel

Add an iPad-only "Numpad width" section above key height. It contains a five-choice visual control with:

- A miniature horizontal width sample.
- A short label.
- Selected state.
- Percentage accessibility value.

Width selection writes immediately and refreshes the permanent dock and keyboard extension.

### Letters

Add an iPad-only "iPad layout" section:

- Standard.
- Full keyboard.

Selecting Full keyboard reveals the numpad-side selector. The selector is hidden for Standard but its stored left/right choice is retained.

## Accessibility

- Each width choice has a distinct label, selected trait, and percentage value.
- Standard and Full keyboard choices explain the visible number row and side numpad.
- The numpad-side selector announces left or right.
- The permanent dock is exposed as one image-like preview with a truthful summary of active layout, pack, width, height preset, and theme.
- Removing duplicate previews must not remove settings labels or navigation landmarks.
- Dynamic Type must not cause the width control to clip or change keyboard height.

## Analytics

Record contentless settings events:

- `numpad_width_changed` with the selected size identifier.
- `ipad_qwerty_layout_changed` with `standard` or `full`.
- `ipad_full_keyboard_numpad_side_changed` with `left` or `right`.

Do not record dimensions, typed content, clipboard content, or custom-key text.

## Testing

### Unit Tests

- New-install width defaults to Full.
- All five width sizes resolve to the correct fraction of available width.
- Partial widths remain centered.
- Floating and narrow contexts resolve to available full width without overwriting the stored choice.
- Changing the width size never changes the returned height.
- Standard QWERTY uses full width and includes the number row.
- Full keyboard produces non-overlapping QWERTY and numpad frames.
- Left and right side choices mirror correctly.
- Full keyboard preserves the original bounds height for both regions.
- Legacy preferences and profiles migrate or decode safely.
- Preview and extension receive identical frames for identical inputs.

### UI Tests

- Five width choices appear on iPad and not iPhone.
- Full is selected on a fresh iPad installation.
- Selecting each width updates the bottom dock immediately.
- Width changes do not alter the dock or keyboard height.
- Letters offers only Standard and Full keyboard.
- Full keyboard reveals the side selector.
- Left/right selection visibly moves the numpad.
- Standard and Full keyboard both show the number row.
- The permanent dock remains bottom-pinned through navigation, rotation, and Split View sizing.
- No duplicate "LIVE PREVIEW" blocks remain on iPad editors.
- Saved setups and onboarding use non-live labels.

### Device Verification

- Build both app and extension from `NumPad.xcworkspace`.
- Verify on the QA 13-inch iPad simulator in portrait and landscape.
- Compare extension and dock screenshots for all five numpad widths.
- Compare Standard, Full-left, and Full-right QWERTY layouts.
- Exercise regular, tall, and kiosk heights before and after width changes and confirm vertical size is unchanged.
- Verify narrow Split View and floating-keyboard fallbacks.
- Smoke-test the iPhone build to confirm its layout and vertical behavior are unchanged.

## Acceptance Criteria

The work is accepted when:

1. A fresh iPad installation presents a full-width numpad.
2. Users can choose five horizontal numpad widths and see the dock update immediately.
3. Width changes do not alter keyboard height, row height, or height presets.
4. iPad QWERTY offers Standard and Full keyboard only, with a visible number row in both.
5. Full keyboard supports the active numpad on either side.
6. The real keyboard and permanent bottom preview use the same layout and content definitions.
7. Misleading duplicate live previews are removed or relabeled.
8. iPhone behavior remains unchanged.
