# Setup Report — DailyMoney (Flutter app)

> **Phase 8 output** · Project Setup execution report
> Resumed session · 2026-10-26

---

## Goal

`dailymoney_flutter/` had only a `pubspec.yaml` from the previous session (interrupted
mid-setup). This run completed the project: Flutter SDK install, app scaffold, full
implementation, and verification with captured proof.

## What was found on resume

- `flutter_windows.zip` in the workspace root was a **corrupted download** (SHA256
  mismatch, 263 files extracted, missing `bin/flutter.bat`).
- Flutter was **not on PATH** and no SDK folder existed.
- App folder contained only `pubspec.yaml` (fonts referenced but missing; icon package
  constraint `lucide_icons ^0.0.2` points to a version that was never published).

## What was done

1. **Flutter SDK 3.47.8 (stable)** installed to `D:\flutter`
   - Re-downloaded fresh (previous zip was corrupt); SHA256 verified against the
     official release manifest: `11e19ea3…193eb6e` ✓
   - Archive was kept temporarily at `D:\tracking\flutter_windows.zip`; deleted after the
     SDK was verified, freeing 1.8 GB
   - At this stage `flutter doctor`: Flutter ✓, Chrome ✓, web build ✓; the Android SDK
     and Visual Studio C++ toolchain were not installed yet (Android was added later —
     see section 7)

2. **Project scaffold** via `flutter create --project-name dailymoney
   --platforms windows,android,web` — existing `pubspec.yaml` preserved byte-for-byte
   (hash-checked).

3. **Fonts** — the 5 static Inter TTFs (Regular/Medium/SemiBold/Bold/ExtraBold) the
   pubspec declares were extracted from the official rsms/inter v4.1 release into
   `assets/fonts/`.

4. **Dependency fix** — `lucide_icons ^0.257.0` is abandoned and **breaks compilation**
   on Flutter 3.47 (`IconData` is now a `final class`; caught by `flutter test`, not by
   `flutter analyze`). Switched to the maintained fork `lucide_icons_flutter ^4.0.1`;
   all 37 icon constants used were verified against the package source.

5. **Full app implementation** (~1,800 LOC, 23 Dart files):
   - Models: `Tx` (income/expense transaction), 17-item category catalog
   - Storage: `SharedPreferences`-backed `StorageService`, versioned JSON keys,
     corrupt-data tolerant
   - Providers: `TransactionsProvider` (add/update/remove/batch, balance, month
     totals, category breakdown, 6-month series, search/filter) and
     `SettingsProvider` (currency, budget, theme, seeded flag)
   - Screens: Home (balance card, budget pace, stat cards, recent), Insights
     (month switcher, fl_chart bar + donut, top categories), Activity (search, type
     filters, month nav, day grouping, edit/delete), Settings (currency, budget,
     theme, demo/clear data)
   - Add/Edit bottom sheet with validation; first launch seeds ~85 demo transactions
   - Material 3 theming with Inter, light + dark, 8 currencies

6. **Tests** — 25 tests across 5 files (model round-trip, provider CRUD + persistence,
   aggregation math, formatting, demo seeder invariants, app boot smoke test, and a
   393 dp narrow-layout regression test covering every tab with seeded data).

7. **Android-only conversion** (follow-up request):
   - Deleted the `windows/` and `web/` platform folders, the stale `build/` output, and
     the `web`/`windows` entries in `.metadata`. Only `android/` remains.
   - Installed the Android toolchain:
     - Android SDK command-line tools → `D:\android-sdk`
     - `platform-tools`, `platforms;android-36`, `build-tools;36.0.0`
     - All SDK licenses accepted; `flutter doctor` Android toolchain ✓
     - `JAVA_HOME` changed from the stale JDK 11 path to `C:\Program Files\Java\jdk-21.0.12`
       (user-level environment variable), `ANDROID_HOME` / `ANDROID_SDK_ROOT` set to
       `D:\android-sdk`
   - App identity: `applicationId` / `namespace` changed from `com.example.dailymoney`
     to **`com.dailymoney.app`**; `MainActivity` moved to the matching package; launcher
     label changed from `dailymoney` to **`DailyMoney`**.
   - First build failed in `shared_preferences_android` with a Kotlin incremental-cache
     crash (“this and base files have different roots”) because the Pub cache is on C:
     and the project on D:. Fixed by disabling Kotlin incremental caches in
     `android/gradle.properties` (`kotlin.incremental=false`,
     `kotlin.incremental.useClasspathSnapshot=false`).

8. **On-device verification and responsive fixes**:
   - MIUI rejected the normal `adb install` even with “Install via USB” enabled.
     Installing for the primary user succeeded: `adb install -r --user 0 …`.
   - Launched the release APK on the connected Xiaomi 2201116PI (Android 13) and
     captured all four tabs. This exposed genuine narrow-screen overflows that the
     wider web test window had hidden.
   - Added `test/narrow_layout_test.dart`, which renders the app at **393 dp**
     (1080 px @ 2.75x) with seeded data and asserts every tab lays out without a
     `RenderFlex` overflow.
   - Fixed the three overflows it found:
     - Home: “Recent activity” header row → title is now `Expanded` + ellipsis.
     - Activity: filter chips + month navigator overflowed by 221 px → chips are a
       horizontal scroller and month navigation sits on its own right-aligned row.
     - Settings: currency dropdown overflowed by 84 px → dropdown is `Expanded`,
       `isExpanded: true`, with ellipsized currency names.
   - Rebuilt and reinstalled the APK; all four tabs verified on the phone.

## Verification (captured proof)

| Check | Result |
|---|---|
| `flutter analyze` | No issues found |
| `flutter test` | **25/25 passing** (incl. 393 dp layout test with seeded data) |
| `flutter build apk --release` | **Built `app-release.apk` — 55,949,672 bytes (53.4 MB)** |
| APK identity (`aapt2 dump badging`) | package `com.dailymoney.app`, version 1.0.0 (code 1), label **DailyMoney**, targetSdk 36, launchable `com.dailymoney.app.MainActivity` |
| APK SHA256 | `3B275AC87146443567862051E161EE8A078E0B25D56BB6EE5B48150F1059BE7A` |
| APK signing cert | `CN=Android Debug` (SHA-256 `e4d087d2…d7e792`) — test signing only at setup time; a release key was added later |
| Build log | `doc/setup/android-build.log` |
| Phone install | **Installed and running** on Xiaomi 2201116PI (Android 13, MIUI V816). Normal `adb install` was rejected; `adb install -r --user 0 …` succeeded |
| On-device screenshots | `proof-android-home.png`, `proof-android-insights.png`, `proof-android-activity.png`, `proof-android-settings.png` (all four tabs, real device) |
| Earlier web verification (removed target) | All 4 tabs + add-transaction flow verified in browser; screenshots `proof-home-web.png`, `proof-insights-web.png`, `proof-activity-web.png`, `proof-settings-web.png`, `proof-addsheet-web.png`, `proof-added-web.png` |

## Bugs caught & fixed during verification

1. `monthAdd` mis-navigated across year boundaries (negative `~/` truncation) →
   rewritten with absolute month indices; regression test added.
2. `fmtMoney` dropped trailing zeros (`$1,234.5`) → fixed decimal pattern per
   currency (2 decimals, 0 for JPY); tests updated.
3. `lucide_icons` incompatibility → replaced with `lucide_icons_flutter` (above).
4. Flutter 3.47 removed `CupertinoPageTransitionsBuilder`/`FadeUpwardsPageTransitionsBuilder`
   → switched to `ZoomPageTransitionsBuilder` / `FadeForwardsPageTransitionsBuilder`.
5. Narrow-screen overflows found on the real phone (393 dp): Home “Recent activity”
   row +31 px, Activity filter/month row +221 px, Settings currency row +84 px. Fixed
   with an expanded header title, scrollable filters + separate month row, and a
   constrained dropdown; new `test/narrow_layout_test.dart` guards all tabs at 393 dp.

## Pending / requiring Ashwin

- **Play Store release:** a local release keystore now exists and release builds are
  signed with it; Play Console registration and the store listing are still pending.
- A local Git repository has been initialized for the GitHub upload; no remote has been
  configured yet.

## Decisions made (no approval needed, reversible)

- Platforms: **Android only** (per Ashwin's request). The `windows/` and `web/` folders
  were removed; iOS/Linux/macOS can be added later with `flutter create --platforms`.
- App id `com.dailymoney.app` replaces the template's `com.example.dailymoney`.
- Demo data seeds on first launch (flagged in settings, removable) so charts aren't
  empty on first open.
- Kept the interrupted session's `pubspec.yaml` choices (provider, shared_preferences,
  fl_chart, intl, uuid, Inter) — only the icon package constraint changed out of
  necessity.
