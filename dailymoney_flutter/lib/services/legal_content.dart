/// Versioned, in-app legal and trust content.
///
/// This file is the single source of truth for the public policies shown in
/// the app. It describes the implementation in this repository. It is not a
/// substitute for review by a qualified lawyer, and the app must not claim
/// regulatory compliance that has not been independently verified.
library;

const String kAppVersion = '1.3.1 (8)';
const String kLegalVersion = '1.1';
const String kLegalUpdatedOn = '30 October 2026';
const String kConsentVersion = '1.1';

/// Optional build-time contact configuration.
///
/// Supply with:
///   flutter build apk --dart-define=DAILYMONEY_SUPPORT_EMAIL=you@example.com
///
/// The app deliberately refuses to invent an address. When these values are
/// empty the Support screen says so and still lets the user copy a report.
const String kSupportEmail = String.fromEnvironment('DAILYMONEY_SUPPORT_EMAIL');
const String kSecurityEmail =
    String.fromEnvironment('DAILYMONEY_SECURITY_EMAIL');
const String kPrivacyEmail = String.fromEnvironment('DAILYMONEY_PRIVACY_EMAIL');
const String kSupportResponseTime =
    String.fromEnvironment('DAILYMONEY_SUPPORT_RESPONSE_TIME');

bool get hasConfiguredSupportContact => kSupportEmail.isNotEmpty;

class LegalSection {
  const LegalSection({
    required this.title,
    this.paragraphs = const [],
    this.bullets = const [],
  });

  final String title;
  final List<String> paragraphs;
  final List<String> bullets;
}

class LegalDocument {
  const LegalDocument({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.sections,
    this.version = kLegalVersion,
    this.updatedOn = kLegalUpdatedOn,
  });

  final String id;
  final String title;
  final String subtitle;
  final String version;
  final String updatedOn;
  final List<LegalSection> sections;

  String get plainText {
    final buffer = StringBuffer()
      ..writeln(title)
      ..writeln('Version $version - updated $updatedOn')
      ..writeln()
      ..writeln(subtitle)
      ..writeln();
    for (final section in sections) {
      buffer
        ..writeln(section.title)
        ..writeln();
      for (final paragraph in section.paragraphs) {
        buffer
          ..writeln(paragraph)
          ..writeln();
      }
      for (final bullet in section.bullets) {
        buffer.writeln('- $bullet');
      }
      if (section.bullets.isNotEmpty) buffer.writeln();
    }
    return buffer.toString().trim();
  }
}

const LegalDocument privacyPolicy = LegalDocument(
  id: 'privacy',
  title: 'Privacy Policy',
  subtitle:
      'How DailyMoney handles the information you record, where it lives, and '
      'the controls available to you.',
  sections: [
    LegalSection(
      title: '1. Scope',
      paragraphs: [
        'This policy applies to the DailyMoney Android app. DailyMoney is a '
            'local-first personal budgeting tool. It has no user accounts, no '
            'cloud service, no advertising and no analytics SDK.',
        'The app does not transmit your records to DailyMoney or to any third '
            'party. The release Android manifest does not request the INTERNET '
            'permission. Debug and profile builds add it only for development '
            'tooling; those builds are not distributed.',
      ],
    ),
    LegalSection(
      title: '2. Information the app stores',
      paragraphs: [
        'The app stores the information you enter so that its budgeting, '
            'planning and reporting features can work. This information stays '
            'in the app\'s private storage on your device.',
      ],
      bullets: [
        'Ledger records: transaction title, amount, income or expense type, '
            'category, date, note, and your share of a split expense.',
        'Planning records: upcoming bills, savings goals, expected income, '
            'shared expenses, repayments and settlement records.',
        'Preferences: greeting name (optional), currency, monthly budget, '
            'allowance policy, money-protection settings, recovery plan, '
            'student mode, theme, notification times and screenshot blocking.',
        'Trust and onboarding records: policy version accepted, acceptance '
            'time, tutorial progress, consent choices and the time they were '
            'recorded.',
        'App-lock records: a PBKDF2-HMAC-SHA256 digest of your PIN and lock '
            'timing. The PIN itself is never stored. Biometric matching is '
            'performed by Android; DailyMoney does not receive or store your '
            'fingerprint or face data.',
        'Imported statements: when you paste a CSV export, the text is parsed '
            'on the device. The original pasted text is not retained; only the '
            'transactions you choose to import are stored.',
      ],
    ),
    LegalSection(
      title: '3. Optional payment detection',
      paragraphs: [
        'Payment detection is off by default. If you grant Android notification '
            'access and turn the feature on, DailyMoney reads notifications '
            'from other apps to look for payment-style messages.',
        'The listener keeps a detection only when the notification contains '
            'payment wording and a detectable amount. It ignores DailyMoney '
            'itself, system apps, one-time passwords and login codes. It keeps '
            'the notification title, an app label, package name, amount, type, '
            'timestamp and up to 300 characters of notification text. That '
            'snippet is briefly queued in plaintext inside the app\'s private '
            'SharedPreferences so the app can import it on next open; the app '
            'then moves it into encrypted storage and clears the queue.',
        'Nothing is added to your ledger automatically. You review each '
            'detection and choose whether to accept or ignore it.',
        'You can turn payment detection off at any time in Settings or in '
            'Consent and permissions. Android notification access can be '
            'revoked in Android Settings. Any snippet already queued when you '
            'turn the feature off is discarded the next time the app opens '
            'instead of being added to the review list.',
      ],
    ),
    LegalSection(
      title: '4. How information is protected',
      bullets: [
        'App data is stored in Android app-private storage.',
        'Payloads are encrypted with AES-256-GCM using a random key held in the '
            'Android Keystore when the device supports it.',
        'If a usable Keystore is unavailable, the app falls back to app-private '
            'JSON storage so it remains usable. The Privacy screen shows whether '
            'encryption is currently on.',
        'Android cloud backup and device-to-device transfer are disabled for '
            'DailyMoney. The backup rules exclude app files and preferences.',
        'The app-lock PIN is verified against a PBKDF2 digest (100,000 '
            'iterations). A legacy salted SHA-256 record is upgraded in place '
            'after a successful unlock.',
        'The optional JSON export is copied to the Android clipboard at your '
            'request. Clipboard contents can be visible to other apps depending '
            'on the Android version and your device. Export only when you are '
            'ready to store the file somewhere safe.',
        'Screenshot and recent-apps blocking is on by default. It hides app '
            'content from screenshots, screen recording and the recent-apps '
            'preview. You can turn it off in Settings > Security & privacy > '
            'Block screenshots. A camera pointed at the screen cannot be '
            'blocked by the app.',
        'Restore reads a DailyMoney JSON backup from the clipboard only when '
            'you choose Restore from clipboard. It replaces financial records '
            'and selected preferences, but it does not import the app-lock PIN, '
            'biometrics, consent choices, notification settings or tutorial '
            'progress.',
      ],
    ),
    LegalSection(
      title: '5. Sharing and third parties',
      paragraphs: [
        'DailyMoney does not sell, rent, share or upload your records. The app '
            'contains no analytics, advertising, crash-reporting, cloud-sync or '
            'bank-connection SDK. It does not connect to a bank or Account '
            'Aggregator.',
        'The app uses Android system services for local notifications, '
            'biometric authentication, the clipboard and app-private storage. '
            'Those services are provided by your device and operating system.',
        'If you install DailyMoney from an app store, the store may process '
            'installation, update and crash information under its own privacy '
            'policy. That processing is outside the app\'s control and is not '
            'performed by DailyMoney.',
      ],
    ),
    LegalSection(
      title: '6. Retention',
      bullets: [
        'Ledger, planning, preference and security records are kept until you '
            'delete them in the app or uninstall DailyMoney.',
        'The native payment-detection queue is cleared when the app next opens '
            'and imports it. Detections you ignore or delete are removed.',
        'Exported JSON exists only where you paste or save it. DailyMoney does '
            'not keep a copy. Restore reads the clipboard only when you choose '
            'Restore from clipboard.',
        'This build does not maintain a separate crash or diagnostic store. '
            'If one is added, it must exclude transaction amounts, notes and '
            'names and must be removed by Delete all data.',
        'There is no server-side retention because the app has no server.',
        'The random encryption key remains in the Android Keystore after '
            'Delete all data so the app can keep working. It contains no '
            'financial records and is removed when the app is uninstalled or '
            'Android app data is cleared.',
      ],
    ),
    LegalSection(
      title: '7. Deletion and your controls',
      paragraphs: [
        'DailyMoney has no accounts, so deleting the data on this device is the '
            'equivalent of account deletion. Open Settings > Help & support > '
            'Legal & privacy > Data controls to review the scope, export a '
            'backup, and erase all '
            'transactions, bills, goals, expected income, shared expenses, '
            'detections, preferences, tutorial and consent records, and the '
            'app-lock PIN.',
        'You can also uninstall the app, which removes its private storage. '
            'Android backup is disabled, so a reinstall does not restore the '
            'deleted data.',
      ],
      bullets: [
        'Access and portability: export a JSON copy from Data controls.',
        'Restore: paste a DailyMoney JSON backup in Data controls. Restore '
            'replaces financial records, not the device security or consent '
            'state.',
        'Correction: edit or delete individual records in the app.',
        'Deletion: erase all data from Data controls.',
        'Withdraw optional consent: turn notifications or payment detection '
            'off in Consent and permissions.',
        'Limit local access: enable the app lock, biometric unlock and '
            'screenshot blocking.',
      ],
    ),
    LegalSection(
      title: '8. Children',
      paragraphs: [
        'DailyMoney is a general-purpose budgeting tool. It does not create '
            'accounts, does not knowingly collect information from children, '
            'and cannot identify who is using a device. Parents and guardians '
            'should decide whether the app is appropriate for a child and '
            'should use the device\'s app-lock controls.',
      ],
    ),
    LegalSection(
      title: '9. Changes to this policy',
      paragraphs: [
        'The policy has a version and an updated date. When the version '
            'changes, the Legal & privacy screen shows that the current '
            'version has not been accepted and offers the new version for '
            'review. The app does not block access to your existing records '
            'while a new version is pending. Material changes will be '
            'described in the app.',
      ],
    ),
    LegalSection(
      title: '10. Contact',
      paragraphs: [
        'Privacy questions and complaints can be started from Support & '
            'complaints in the app. This beta build does not yet publish a '
            'monitored support email. A verified privacy contact must be '
            'configured before public release; the Support screen shows the '
            'configured route when one is available.',
      ],
    ),
  ],
);

const LegalDocument termsOfService = LegalDocument(
  id: 'terms',
  title: 'Terms of Service',
  subtitle:
      'The rules for using DailyMoney, what the app does and does not do, and '
      'how complaints are handled.',
  sections: [
    LegalSection(
      title: '1. Acceptance',
      paragraphs: [
        'By installing or using DailyMoney you agree to these terms and '
            'acknowledge the Privacy Policy. If you do not agree, do not use '
            'the app and uninstall it.',
        'These terms apply to the DailyMoney Android app. They do not create '
            'an account or a continuing service relationship.',
      ],
    ),
    LegalSection(
      title: '2. What DailyMoney is',
      paragraphs: [
        'DailyMoney is a personal record-keeping and budgeting tool. It helps '
            'you record income and expenses, plan a monthly budget, reserve '
            'money for bills and goals, and explore estimates.',
        'DailyMoney does not hold, transfer or custody money. It does not '
            'execute payments, connect directly to a bank, provide credit, or '
            'give regulated financial advice. Bank statement import is a '
            'manual, offline paste-and-parse feature.',
      ],
    ),
    LegalSection(
      title: '3. Your responsibilities',
      bullets: [
        'Enter information that is accurate enough for your own purposes. '
            'Budget calculations and projections depend on what you enter.',
        'Keep your device, app lock and exported backups secure.',
        'Use the app only for lawful personal money management and do not use '
            'it to deceive, defraud or harm another person.',
        'Do not attempt to bypass the app lock, extract another person\'s '
            'data, reverse engineer the app for misuse, or interfere with its '
            'operation.',
        'Do not rely on the app as the only record of a payment, bill or '
            'financial obligation. Keep the original bank, employer or merchant '
            'records where they matter.',
      ],
    ),
    LegalSection(
      title: '4. Your data',
      paragraphs: [
        'Your records belong to you. DailyMoney claims no ownership of the '
            'financial information you enter.',
        'The app stores data on your device. You are responsible for exporting '
            'a backup before deleting data, uninstalling the app, or moving to '
            'another device. Android cloud backup and device-to-device transfer '
            'are disabled because the encryption key cannot travel with the '
            'data.',
        'You can restore a DailyMoney JSON backup from the clipboard in Data '
            'controls. Restore replaces the financial records then on the '
            'device; it does not import the app-lock PIN, biometrics, consent '
            'choices, notification settings or tutorial progress. Keep the '
            'exported copy until you have checked the restored records.',
      ],
    ),
    LegalSection(
      title: '5. Estimates, not guarantees',
      paragraphs: [
        'Daily allowance, budget pace, money-map reservations, recovery plans, '
            'what-if scenarios and forecasts are estimates produced from the '
            'information available to the app. They are not guarantees that '
            'money will be available, that a bill will be affordable, or that a '
            'projection will come true.',
        'The app is not a substitute for professional financial, tax, '
            'investment or legal advice. For decisions with significant '
            'consequences, consult a qualified professional.',
      ],
    ),
    LegalSection(
      title: '6. Availability and changes',
      paragraphs: [
        'DailyMoney is provided on an as-is and as-available basis. The app may '
            'change, lose a feature, or stop being distributed. Local features '
            'can stop working if the operating system, device storage or '
            'Keystore changes.',
        'We do not promise uninterrupted or error-free operation. Notifications '
            'are scheduled inexactly and may be delayed or suppressed by the '
            'operating system or device battery settings.',
      ],
    ),
    LegalSection(
      title: '7. Paid features',
      paragraphs: [
        'DailyMoney currently has no paid features, subscriptions or in-app '
            'purchases. If paid features are added, the price, billing period, '
            'renewal, cancellation and refund terms will be shown before '
            'purchase and handled through the app store that processes the '
            'payment.',
      ],
    ),
    LegalSection(
      title: '8. Intellectual property',
      paragraphs: [
        'The DailyMoney name, app, visual design, source code and documentation '
            'are protected by applicable intellectual property laws. You receive '
            'a personal, non-exclusive, non-transferable licence to use the app '
            'for your own money management. You may not redistribute, sell or '
            'claim authorship of the app except where the law expressly allows '
            'it.',
        'Open-source packages used by the app remain subject to their own '
            'licences. Your entered data is not covered by this licence.',
      ],
    ),
    LegalSection(
      title: '9. Complaints and disputes',
      paragraphs: [
        'Start with Support & complaints in the app. Include the app version, '
            'what you expected, what happened, and whether the issue concerns a '
            'calculation, privacy, security or accessibility. Do not send '
            'one-time passwords, full bank account numbers or card numbers.',
        'A monitored contact and response target must be configured before '
            'public release. This beta build does not promise a response time '
            'where no such target is published. Nothing in this section limits '
            'rights you have under mandatory consumer law.',
      ],
    ),
    LegalSection(
      title: '10. Limitation of liability',
      paragraphs: [
        'To the fullest extent permitted by applicable law, DailyMoney is not '
            'liable for indirect, incidental or consequential loss, loss of '
            'data, loss of profit, or a financial decision made in reliance on '
            'an estimate, alert or projection in the app.',
        'Nothing in these terms excludes or limits liability that cannot '
            'lawfully be excluded, including mandatory consumer rights. The '
            'scope and wording of this section require review by a qualified '
            'lawyer before public release.',
      ],
    ),
    LegalSection(
      title: '11. Governing law',
      paragraphs: [
        'Governing law and the forum for disputes have not been selected for '
            'this beta build. They must be confirmed for the countries where '
            'the app is distributed. Any choice of law remains subject to '
            'mandatory protections that apply where you live.',
      ],
    ),
    LegalSection(
      title: '12. Changes and contact',
      paragraphs: [
        'These terms have a version and an updated date. A new version will be '
            'offered for review in the Legal & privacy screen. The app does not '
            'block access to your existing records while a new version is '
            'pending. If you do not agree to a change, stop using the app and '
            'delete your data.',
        'Contact routes are listed on the Support & complaints screen. A '
            'verified support and legal contact must be configured before '
            'public release.',
      ],
    ),
  ],
);

const LegalDocument financialDisclaimer = LegalDocument(
  id: 'disclaimer',
  title: 'Financial Disclaimer',
  subtitle:
      'What the numbers in DailyMoney mean, and what they do not promise.',
  sections: [
    LegalSection(
      title: 'Estimates, not guarantees',
      paragraphs: [
        'Daily allowance, remaining budget, money-map reservations, recovery '
            'plans, what-if scenarios, purchase checks and future projections '
            'are estimates. They are calculated from the records and settings '
            'you provide. They are not bank balances and are not guarantees.',
        'If a transaction is missing, duplicated, recorded on the wrong date, '
            'or categorised incorrectly, every figure that depends on it can '
            'change. Review your records and reconcile them with your bank or '
            'payment provider when accuracy matters.',
        'A restored backup replaces the financial records on this device. Check '
            'the record counts and the resulting balance before relying on the '
            'restored data, and keep the exported copy until you have done so.',
      ],
    ),
    LegalSection(
      title: 'DailyMoney does not move money',
      paragraphs: [
        'DailyMoney does not hold money, execute payments, transfer funds, '
            'connect directly to a bank, or act as a payment service. Marking '
            'a bill as paid or accepting a detected payment only changes your '
            'local records.',
        'Reserved bills, savings goals and protected buckets are planning '
            'allocations. They do not move or lock money in a real account.',
      ],
    ),
    LegalSection(
      title: 'Alerts and notifications',
      paragraphs: [
        'Budget alerts and daily briefings are conveniences. Android may delay '
            'or suppress a notification because of battery restrictions, '
            'permission changes, reboot timing or operating-system policy. Do '
            'not rely on a notification as the only warning before a payment '
            'or due date.',
      ],
    ),
    LegalSection(
      title: 'Not professional advice',
      paragraphs: [
        'DailyMoney is not a financial adviser, tax adviser, investment '
            'adviser, lender or credit counsellor. Its observations and tips '
            'are general rules over your own records. They do not consider your '
            'full circumstances and are not a recommendation to buy, borrow, '
            'invest or take any other financial action.',
        'For significant decisions, consult a qualified professional who can '
            'review your complete situation.',
      ],
    ),
  ],
);

const LegalDocument consentAndPermissionsDocument = LegalDocument(
  id: 'consent',
  title: 'Consent and Permissions',
  subtitle:
      'What is essential, what is optional, and how to change your choices.',
  version: kConsentVersion,
  sections: [
    LegalSection(
      title: 'Essential local processing',
      paragraphs: [
        'DailyMoney cannot provide a ledger or budget without storing the '
            'records you enter. This local processing is essential to the '
            'feature you are using. It happens on your device and is not used '
            'for advertising, analytics or profiling.',
      ],
    ),
    LegalSection(
      title: 'Optional choices',
      bullets: [
        'Notifications: Android permission for morning briefings, nightly '
            'summaries, budget alerts and detected-payment prompts. Off until '
            'you enable a notification feature.',
        'Payment detection: Android notification access, used only to find '
            'payment-style notifications for your review. Off by default.',
        'Biometric unlock: uses Android biometric authentication for app lock. '
            'Optional and controlled by you.',
        'Export: copies a JSON backup to the clipboard only when you tap '
            'Export a backup.',
        'Restore: reads a DailyMoney JSON backup from the clipboard only when '
            'you tap Restore from clipboard. It replaces financial records, not '
            'consent or app-lock state.',
        'Screenshot blocking: on by default to hide balances from screenshots '
            'and the recent-apps preview. You can turn it off in Security & '
            'privacy.',
      ],
    ),
    LegalSection(
      title: 'What DailyMoney does not do',
      paragraphs: [
        'There is no analytics consent because the app contains no analytics. '
            'There is no marketing consent because the app sends no marketing. '
            'There is no cloud-sync consent because the app has no cloud '
            'service. The app does not request contacts, SMS, location, '
            'microphone, camera or internet access.',
      ],
    ),
    LegalSection(
      title: 'Records and withdrawal',
      paragraphs: [
        'When you enable notifications or payment detection, the app records '
            'the choice, the consent version and the time. You can change '
            'either choice in Consent and permissions. Turning notifications '
            'off also turns off the morning, nightly and budget-alert options '
            'and stops detected-payment prompt notifications; payment '
            'detection can remain on and still queue items for in-app review. '
            'Android notification access can be revoked in Android Settings.',
        'The app records the privacy and terms version you accepted and when. '
            'A new version is offered for review in the Legal & privacy screen '
            'while the app continues to allow access to existing records.',
      ],
    ),
  ],
);

const List<LegalDocument> legalDocuments = [
  privacyPolicy,
  termsOfService,
  financialDisclaimer,
  consentAndPermissionsDocument,
];

String supportEmailFor(String topic) {
  switch (topic) {
    case 'security':
      if (kSecurityEmail.isNotEmpty) return kSecurityEmail;
      return kSupportEmail;
    case 'privacy':
      if (kPrivacyEmail.isNotEmpty) return kPrivacyEmail;
      return kSupportEmail;
    default:
      return kSupportEmail;
  }
}
