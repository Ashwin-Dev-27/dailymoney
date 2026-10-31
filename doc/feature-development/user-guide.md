# In-App User Guide and Help Centre

> **Internal engineering document.** It explains how the in-app manual is
> structured, how to keep it accurate, and which checks protect it. The user
> guide itself is the text served inside the app, not this document.

- **Version:** 1.1
- **Last updated:** 30 October 2026
- **App version described:** 1.3.1+8 (`com.dailymoney.app`)
- **Sources:** `lib/services/user_guide_content.dart`,
  `lib/screens/help_centre_screen.dart`, `lib/screens/settings_screen.dart`,
  `test/help_centre_test.dart`

## 1. Purpose

The Help Centre gives a private-beta user a complete reference without leaving
the app. It covers the 12 requested chapters, answers the most common questions
from verified behaviour, and offers the guided tour again. It is deliberately a
reference manual, not a second onboarding flow.

Principles:

1. Every statement must be checked against the shipped code. If a feature is
   planned or partial, do not write instructions for it.
2. Content is data, not UI. A feature change should require one content edit,
   not a screen rewrite.
3. The guide never replaces the interactive tour; it links to it.
4. No screenshots. `blockScreenshots` is on by default (`FLAG_SECURE`), so the
   guide uses icons, headings, spacing and colour to illustrate structure.
5. Wording stays plain and specific. Prefer "Open Settings > Privacy & security"
   over "go to the settings area".

## 2. Where it lives

| Piece | File | Responsibility |
|---|---|---|
| Content source of truth | `lib/services/user_guide_content.dart` | 12 `GuideChapter` values, 18 `GuideFaq` values, lookup and search helpers. |
| Main Help Centre | `lib/screens/help_centre_screen.dart` | Search field, chapter list, FAQ expansion tiles, support card, footer. |
| Chapter detail | `lib/screens/help_centre_screen.dart` | What / why / where / steps / example / mistakes / related questions. |
| Settings entry | `lib/screens/settings_screen.dart` | **Help & support > Help centre**, the only new menu entry. |
| Tour replay | `lib/providers/settings_provider.dart` | `replayTutorial()` starts the existing 10-step tour. |
| Tests | `test/help_centre_test.dart` | Content integrity, search, detail sections, replay, Settings entry, narrow layout and 2x text. |

There is one Help Centre entry in Settings. Do not add a separate menu for each
chapter, a second FAQ screen, or a duplicate tour implementation.

## 3. Content model

### `GuideChapter`

| Field | Used for |
|---|---|
| `id` | Stable identifier. Never change it; search tests and FAQ links use it. |
| `number` | Display order 1-12 and the "Chapter N of 12" label. |
| `title` | Chapter name on the list and detail page. |
| `summary` | One line on the chapter tile. |
| `icon` | Lucide icon used as the chapter illustration. |
| `what` | Plain description of the feature. |
| `why` | The problem it solves for the user. |
| `where` | Exact in-app location. Use the shipped labels. |
| `steps` | Ordered instructions. At least three per chapter. |
| `example` | A concrete everyday example with realistic amounts. |
| `mistakes` | `GuideMistake(problem, fix)` entries. At least two per chapter. |
| `keywords` | Extra search words that do not appear naturally in the prose. |

`searchText` concatenates every field plus mistake text and keywords. Search is
case-insensitive, punctuation-insensitive and requires every query word, so
`daily  allowance`, `allowance?` and `DAILY-ALLOWANCE` behave sensibly.

### `GuideFaq`

| Field | Used for |
|---|---|
| `id` | Stable identifier used by tests and keys. |
| `question` | Expansion tile title. |
| `answer` | Verified answer. May contain short paragraphs. |
| `chapterId` | Must resolve with `guideChapterById` and points to the full explanation. |
| `keywords` | Synonyms and likely search words. |

The 18 current questions cover allowance maths, overspending, editing,
deleting, offline use, storage, reporting, data deletion, expected income,
currency, categories, budget alerts, bill payment, splits, multiple devices,
zero allowance, backup security and uninstall.

## 4. Adding or changing content

When a shipped behaviour changes:

1. Find every chapter and FAQ that mentions the old behaviour. Search the
   content file for the visible labels and amounts, not just the feature name.
2. Update the prose to match the code. Check screen titles, button labels,
   default values, formulas and limits in the implementation.
3. If a new screen or control is involved, update `where` and `steps`; do not
   only change `what`.
4. If the change affects search discovery, add the user's likely words to
   `keywords`.
5. If a new FAQ is needed, attach it to an existing chapter. Do not create a
   question that the app cannot answer from implemented behaviour.
6. Run `flutter test test/help_centre_test.dart`. The structural tests fail if a
   chapter number is missing, an id is duplicated, a FAQ points at a missing
   chapter, or a required section is empty.

Do not:

- document live bank linking, cloud sync, custom categories, an account,
  automatic backups, exchange-rate conversion or an undo action - none exist;
- add a support email address that has not been verified;
- promise reminders, exact notification timing or response times;
- copy the whole guided tour into the guide. Link to the tour instead.

## 5. Screen behaviour

### Main page

- App bar: **Help centre**.
- Hero: what the guide is, with a book icon.
- Search: filters both chapters and questions as the user types.
- **Replay guided tour** card: pops every route above the shell and calls
  `replayTutorial()`, so the overlay lands on the real app rather than on the
  guide.
- **Browse chapters**: all 12 tiles with icon, chapter number, title, summary.
- **Common questions**: all 18 expansion tiles. Expanding a question also
  offers a link to its chapter.
- **Still stuck?**: opens the existing `SupportScreen`.
- Footer: the shared `DailyMoneyFooter`.

When a search has no matches, the page shows the query, suggests simpler words
and offers **Clear search** and **Ask for help**.

### Chapter page

- App bar: **Chapter N**.
- Header: icon, "Chapter N of 12", title, summary.
- Sections: **What it is**, **Why it matters**, **Where to find it**,
  **Step by step**, **A real-life example**, **Common mistakes**.
- **Related questions** when the chapter has FAQs.
- **Prefer to see it?** card reopens the tour.
- **Still stuck?** card and the shared footer.

### Layout and accessibility

- Content is capped at 760 dp and centred, with 16 dp side padding on phones and
  24 dp on wider screens.
- Rows use `Expanded` text, not fixed heights, so large Android text settings
  grow the cards instead of clipping.
- Section headings are marked as headers for screen readers.
- Text is at least 11.5 sp, body text is 13-14 sp with 1.4-1.55 line height,
  and labels are not hidden behind icons alone.
- Tests at 320 dp width and 2x text scaling must remain free of overflow
  exceptions.

## 6. Verification

Current automated coverage in `test/help_centre_test.dart`:

1. 12 sequential chapters, unique ids, all required fields, at least three
   steps and two mistakes per chapter.
2. 18 unique FAQs, all linked to real chapters, no empty answers.
3. Search requires all words, ignores punctuation and handles empty queries.
4. Main page lists chapters, expands a FAQ and links to the chapter.
5. Search filters chapters and answers and clears back to browse mode.
6. The no-results state offers both recovery actions.
7. Chapter detail shows every required section.
8. Replay closes the guide, sets `tutorialInProgress` and resets the step to 0.
9. Settings has exactly one Help centre entry and opens the page.
10. 320 dp width at 2x text has no overflow on the list or a chapter page.

Run:

```bash
dart format lib/services/user_guide_content.dart lib/screens/help_centre_screen.dart test/help_centre_test.dart
flutter analyze --no-fatal-infos
flutter test
```

A device pass on the Redmi (`the Redmi test device`) on 30 October 2026 confirmed the
Settings entry, chapter list, `backup` search (2 chapters / 5 answers), FAQ
expansion, chapter detail (all sections plus footer), and tour replay from both
the Help Centre and a chapter page. The tour ran through steps 1-10 and
completed with the ledger unchanged. TalkBack traversal and 200% system text
size on the physical phone remain pending; the 320 dp / 2x layout is covered by
the widget test.

## 7. Known boundaries

- The guide describes the local-only implementation. It does not describe a
  server, an account, cloud sync or a live bank connection.
- The build may have no support email configured; the Support screen shows that
  warning and the copied report remains the fallback.
- Screenshots are blocked by default, which is why the guide is icon-based.
- The footer version string is fixed by product decision and is not read from
  the package version.

## Document control

| Item | Value |
|---|---|
| Public? | Yes - published in this repository |
| In-app source | `user_guide_content.dart`, `help_centre_screen.dart` |
| Chapters | 12 |
| FAQ answers | 18 |
| Automated coverage | 10 tests in `test/help_centre_test.dart` |
| Device verification | Help Centre list/search/FAQ/chapter/replay and tour steps 1-10 passed on the Redmi test device, 30 October 2026; TalkBack and physical 2x text pending |
