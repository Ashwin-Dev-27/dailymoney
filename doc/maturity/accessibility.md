# DailyMoney Accessibility

> **Beta draft - not legally reviewed.** This document records the accessibility
> behaviour implemented in DailyMoney 1.3.1+8 and the checks that have **not**
> been performed. It is not a claim of WCAG 2.2, EN 301 549, the Android
> accessibility guidelines or any other standard.

- **Version:** 1.1
- **Last updated:** 30 October 2026
- **App version described:** 1.3.1+8 (`com.dailymoney.app`)

## 1. Scope and status

The app is an Android-only Flutter application. This document covers:

- screen-reader semantics;
- keyboard and switch access;
- text scaling and reflow;
- reduced motion;
- colour and contrast;
- touch target size;
- onboarding and tutorial accessibility.

**No assistive-technology session has been run on a physical device for this
build.** The automated widget tests exercise layout at phone width, but they do
not run TalkBack, Switch Access or Android's font-size and display-size settings.
Those checks are mandatory before a public release.

## 2. Implemented behaviour

### 2.1 Screen readers

| Area | Behaviour | Evidence |
|---|---|---|
| Standard controls | Material widgets expose their role, label, value and enabled state. | Framework defaults; widget tests build the real widgets |
| Icon-only buttons | Use `tooltip:` so the control has an accessible name (for example "Add transaction", "Money assistant", "Actions"). | `lib/app.dart`, screen tooltips |
| Tutorial overlay | Announces "Tutorial step N of 10. Title. Body" as a live region and "Tutorial complete..." on the final card. | `lib/widgets/tutorial_overlay.dart` |
| Tutorial background | `BlockSemantics` prevents the dimmed shell behind the tour from remaining in the semantics tree. | `lib/app.dart` |
| Status messages | Material snackbars announce through the framework's live region. | Framework default |
| Legal documents | Rendered as selectable text with a copy action and a read checkbox on the hub. | `lib/screens/legal_document_screen.dart`, `legal_hub_screen.dart` |
| Charts | No custom semantics summary has been added to the chart widgets. | Known gap, Section 4 |

The tutorial's live-region label duplicates the visible title and body. This is
intentional: the tooltip card is a custom overlay, and the label guarantees the
step is announced when it changes.

### 2.2 Keyboard and switch access

- The tutorial takes focus when it opens.
- `ArrowRight` advances, `ArrowLeft` goes back, and `Escape` skips the tour.
- Back/Next/Skip are ordinary buttons and are reachable in focus order.
- The welcome screen uses standard checkboxes and buttons.
- The app does not define a custom global focus order. It relies on Flutter's
  reading order, which follows the widget tree.

Keyboard support is primarily relevant to Chromebooks, desktop-mode Android and
switch-access devices. It has not been tested with a physical keyboard.

### 2.3 Text scaling and reflow

- The app does not clamp `TextScaler` or text scale factor. Android font-size
  settings therefore apply to text.
- Welcome, legal, consent, support and data-controls screens use scrollable
  layouts so content is not clipped when it grows.
- The restore confirmation is a scrollable dialog with a standard checkbox; the
  record counts are plain text in a two-column list.
- The tutorial card is scrollable inside a maximum height of 62% of the screen
  and uses a 16 dp margin.
- The tutorial width is capped at 360 dp and falls back to the available width
  on small screens.
- The app has no fixed-height text containers in the new onboarding, legal and
  support screens.
- Existing dense screens (Home cards, reports) have not been re-audited at
  200% text size.

**Not tested:** Android display size, font size 200%, bold text, and the largest
accessibility font setting.

### 2.4 Reduced motion

- The tutorial checks `MediaQuery.disableAnimations` (Android "Remove
  animations").
- When reduced motion is on, the spotlight pulse is static, the pointing hand
  does not bob, and step transitions use a 120 ms fade instead of the longer
  animation.
- No other screen adds decorative looping animation.
- The app does not override the system animation setting.

**Not tested:** the reduced-motion path on a physical device.

### 2.5 Colour and contrast

- The app supports system, light and dark themes. The choice is in
  **Settings > Appearance**.
- Status is not conveyed by colour alone in the new screens: labels such as
  "On", "Off", "Unavailable", "Allowed" and explicit warning text accompany the
  colour.
- The theme uses an Inter font family and custom colour tokens.
- **No contrast measurement has been recorded.** The colour pairs have not been
  checked against WCAG 2.2 AA (4.5:1 for normal text, 3:1 for large text and
  non-text indicators).

**Not tested:** colour correction modes, high-contrast text, grayscale, and
dark-theme contrast.

### 2.6 Touch targets

- Most controls use Material defaults (48 x 48 dp minimum).
- The tutorial's Back, Next and Skip buttons set a minimum height of 40 dp. This
  is **below the 48 dp guideline** and is a known gap.
- The tutorial's action button ("Open the entry sheet") uses the default
  outlined-button height.
- Icon buttons use Material `IconButton` sizing unless a screen overrides it.

### 2.7 Responsive layout

- `test/narrow_layout_test.dart` builds the app at 1080 x 2400 px with a device
  pixel ratio of 2.75 (393 dp wide), opens Home, Reports, Upcoming, Insights,
  Activity and Settings, and fails on any Flutter overflow error.
- `test/reports_narrow_test.dart` checks the densest report rows at the same
  width.
- The new welcome, legal and support screens are scrollable and width-capped.
- The tests cover one phone width only. Tablets, foldables, landscape, split
  screen and RTL layouts are not covered.

### 2.8 Onboarding and tutorial

- The tour is optional and skippable from the first step.
- It can be replayed from **Settings > Help & support > Replay guided tour**.
- It uses the real controls and does not create a transaction.
- Each step has a text description; a missing target shows a plain-language
  fallback instead of an empty spotlight.
- Progress is persisted, so leaving the app does not lose the step.
- The tour never requests a permission.
- The tour does not auto-advance, so the user controls the pace.

## 3. Automated evidence

| Check | Result | Evidence |
|---|---|---|
| Full app lays out at 393 dp without overflow | Passes | `test/narrow_layout_test.dart` |
| Reports lay out at 393 dp without overflow | Passes | `test/reports_narrow_test.dart` |
| Tour can be skipped without creating records | Passes | `test/onboarding_legal_test.dart` |
| Tour completion returns to the app | Passes | Same file |
| Welcome controls are reachable and disabled until acceptance | Passes | Same file |
| Analyser clean | Passes | `doc/maturity/analyze-output.txt` |
| Screen-reader traversal | **Not run** | No device session |
| 200% text size | **Not run** | No device session |
| Contrast measurement | **Not run** | No measurement recorded |
| Physical keyboard / switch access | **Not run** | No device session |

Automated layout tests are not accessibility tests. They catch overflow, not
missing labels, focus traps or incomprehensible announcements.

## 4. Known gaps

1. **No TalkBack device pass.** The live-region wording and `BlockSemantics`
   change are implemented but unverified with a screen reader.
2. **Charts have no text alternative.** Category and trend charts expose
   fl_chart's default semantics at most. A concise summary should be added.
3. **Tutorial action buttons are 40 dp high.** Raise them to 48 dp, or verify
   that the effective hit area is larger.
4. **No large-text test.** Dense screens may overflow or clip at 200% text.
5. **No contrast audit.** Theme tokens have not been measured against WCAG.
6. **No RTL or localisation.** The app is English-only and has not been checked
   in a right-to-left locale.
7. **No accessibility-specific regression test.** The new widget tests cover
   flow, not semantics.
8. **Snackbar-only confirmations.** Some results are only announced visually;
   Material normally announces snackbars, but this has not been verified with
   TalkBack.
9. **No haptic or sound alternative.** The app does not use haptics for
   confirmation or error states.
10. **The tour does not trap keyboard focus.** `BlockSemantics` hides background
    semantics, but Tab focus can still move to the shell behind the overlay. A
    `FocusScope`/`FocusTraversalGroup` review is required.
11. **New restore and PIN-cooldown UI is not in the manual audit yet.** The
    restore counts/checkbox dialog and the lockout countdown have not been
    checked with TalkBack or 200% text.

## 5. Manual audit plan before public release

### Devices and settings

1. Android 13+ phone with TalkBack.
2. Android 10-12 phone with TalkBack and Switch Access.
3. Font size at maximum and display size at maximum.
4. "Remove animations" enabled.
5. Dark theme, light theme and high-contrast text.
6. A physical keyboard or Chromebook, if supported.

### Flows to test

1. First run: read the welcome screen, reach both checkboxes, open each policy,
   accept, start the tour.
2. Tour: hear each step, use Back/Next/Skip, complete the tour, replay it.
3. Add a transaction with TalkBack: every field has a label, errors are
   announced, the save result is announced.
4. Home: balance, allowance, money map, upcoming bills and review banners are
   understandable without colour.
5. Insights and reports: charts have a readable summary or an accessible list.
6. Settings: every switch announces its name, state and effect.
7. Consent: notification and payment-detection choices are understandable and
   reversible.
8. Support: the report builder and copy result are announced.
9. Data controls: the destructive confirmation cannot be triggered accidentally.
10. App lock: PIN entry, error state and biometric fallback are usable.

### Measurements to record

- contrast ratio for body text, secondary text, buttons, warning banners and
  chart series in both themes;
- actual touch target size for tutorial buttons and icon buttons;
- overflow at 200% text for Home, Insights, Activity, Settings, Reports and the
  new screens;
- screen-reader order and announcement for each tour step.

## 6. Standards position

The app does not claim conformance with WCAG, EN 301 549, the Android
Accessibility Scanner thresholds or any app-store accessibility badge. The
checks above are the minimum expected before making any accessibility claim.

## 7. Questions for review

1. Which accessibility standard, if any, must be published for the target
   markets and app store?
2. Is an accessibility conformance report required, and at what level?
3. Must the app provide an accessibility feedback route separate from general
   support?
4. Are there jurisdiction-specific requirements for financial apps that go
   beyond the standard?
5. Should the tutorial be dismissible with the Android back gesture as well as
   the Skip button?

## Document control

| Item | Value |
|---|---|
| In-app sources | `lib/widgets/tutorial_overlay.dart`, `lib/app.dart`, `lib/screens/welcome_screen.dart` |
| Review status | Not reviewed |
| Device accessibility pass | Not run |
| Contrast audit | Not run |
| Claimed conformance | None |
