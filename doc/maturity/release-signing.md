# Release signing runbook

This is an internal engineering runbook, not a legal or store-compliance document.
It explains how to produce a release-signed APK without committing secrets.

## Current state

- `android/app/build.gradle.kts` uses a private release key only when
  `android/key.properties` exists.
- Without that file, `flutter build apk --release` still works but falls back to
  the Android **debug key**. A debug-signed APK is for local testing only and
  must not be distributed as the private beta or a store build.
- A local release key exists and a release-signed `v1.3.1+8` APK has been built.
  The key, `key.properties` and the obfuscation symbols are gitignored and backed
  up outside the repository.
- The developer device still runs the debug-signed `v1.3.1+8` build, which
  preserves existing data. Do not replace it with a release-signed build until
  the migration below has been followed.

## Create the key (one time, offline)

Run from the `dailymoney_flutter/android` directory so the relative path in
`key.properties.example` matches:

```bash
keytool -genkeypair -v -keystore dailymoney-release.jks \
  -keyalg RSA -keysize 4096 -validity 10000 -alias dailymoney-release
```

Then copy the example file and fill in the real values:

```bash
cp key.properties.example key.properties
```

`android/key.properties`, `*.jks` and `*.keystore` are excluded by
`android/.gitignore`. Keep at least two offline backups of the keystore and its
passwords. Losing the key means existing installs cannot be updated; the only
recovery is a different application id or uninstall, which removes app data.

## Build and inspect

```bash
flutter build apk --release
```

Verify the signer before distributing:

```bash
apksigner verify --print-certs build/app/outputs/flutter-apk/app-release.apk
```

`apksigner` is under the Android SDK build-tools. The certificate digest must
match the key created above and must be the same for every future update.

## Moving an existing debug install to the release key

Android refuses to install an APK signed by a different key over an existing
one. Existing financial data cannot survive the key change by itself. The
supported path with backup restore is:

1. Build and install `v1.3.1+8` with the **debug** key over the currently
   installed debug build. This preserves app data and provides restore.
2. Open **Settings → Help & support → Legal & privacy → Data controls → Export
   a backup**. Save the JSON somewhere outside the app and confirm it is readable.
3. Uninstall DailyMoney. This removes app storage and the Android Keystore key.
4. Install the release-signed `v1.3.1+8` APK.
5. Complete onboarding, then open **Settings → Help & support → Legal & privacy
   → Data controls → Restore from clipboard**. Paste the JSON saved in step 2
   and confirm the counts.
6. Check the ledger, bills, goals, expected income and shared records before
   deleting the backup copy.

Record the export/restore check in the beta notes. The restore replaces
financial records and selected preferences but deliberately keeps the app-lock
PIN, biometrics, consent choices, notification settings and tutorial state of
the device it is restored onto.

## If the key is lost

- Installed users cannot receive an update signed by a new key.
- A new key plus a new application id creates a separate app with no data.
- A new key with the same application id requires uninstalling the old app,
  which erases its private data, then restoring from a JSON backup if one was
  exported.

Keep at least two offline copies of the keystore and its passwords. The current
key is backed up outside the repository; a second offline copy is still
recommended. Losing the key means existing installs cannot be updated; the only
recovery is a different application id or uninstall, which removes app data.
