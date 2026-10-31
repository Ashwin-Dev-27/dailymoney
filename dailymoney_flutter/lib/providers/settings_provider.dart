import 'package:flutter/material.dart';

import '../services/legal_content.dart';
import '../services/screen_security.dart';
import '../services/sound_service.dart';
import '../services/storage_service.dart';
import '../utils/format.dart';

/// What happens to money left unspent at the end of a day.
enum AllowancePolicy {
  /// Roll leftover allowance into tomorrow's allowance.
  carryForward,

  /// Treat leftover allowance as savings rather than spendable money.
  savings,

  /// Keep leftover allowance as a safety buffer for later in the month.
  buffer,
}

extension AllowancePolicyLabel on AllowancePolicy {
  String get label => switch (this) {
        AllowancePolicy.carryForward => 'Carry forward',
        AllowancePolicy.savings => 'Move to savings',
        AllowancePolicy.buffer => 'Keep as buffer',
      };

  String get description => switch (this) {
        AllowancePolicy.carryForward =>
          'Unused daily money raises tomorrow\'s allowance',
        AllowancePolicy.savings =>
          'Unused daily money is treated as savings, not spendable',
        AllowancePolicy.buffer =>
          'Unused daily money stays back as a safety buffer',
      };
}

/// User preferences: currency, monthly budget, planning and notifications.
class SettingsProvider extends ChangeNotifier {
  SettingsProvider(this._storage);

  final StorageService _storage;

  String currencyCode = 'USD';
  String userName = '';
  double monthlyBudget = 0; // 0 = no budget set
  ThemeMode themeMode = ThemeMode.system;
  bool seeded = false;

  /// Hides the app contents from screenshots and the Android recents preview.
  /// On by default because the app displays balances and transaction history.
  bool blockScreenshots = true;

  /// How unused daily allowance is treated.
  AllowancePolicy allowancePolicy = AllowancePolicy.carryForward;

  /// Cap the daily allowance by money actually left after protected buckets.
  bool moneyProtection = true;

  /// Money kept back for emergencies. A planning allocation, not a transfer.
  double emergencyBuffer = 0;

  /// Optional student budgeting language and tools.
  bool studentMode = false;

  // Financial recovery plan. Inactive when recoveryDays is 0.
  bool recoveryActive = false;
  double recoveryDailyCut = 0;
  int recoveryDays = 0;
  double recoveryTarget = 0;
  String? recoveryStartedOn;

  /// The local date (yyyy-MM-dd) the missing-expense nudge was dismissed on.
  String? missingExpenseDismissedOn;

  // Notification features start off. Permission is requested only after the
  // user turns one on, never during app startup.
  bool morningBriefing = false;
  int morningMinutes = 8 * 60; // 08:00
  bool nightSummary = false;
  int nightMinutes = 21 * 60; // 21:00
  bool budgetAlerts = false;
  bool notificationsAsked = false;

  /// Purpose-specific consent for local notifications.
  bool notificationsConsent = false;
  String? notificationsConsentAt;
  String? notificationsConsentVersion;

  /// Watch payment notifications and queue them for review.
  bool autoCapture = false;

  /// Purpose-specific consent for reading payment-style notifications.
  bool autoCaptureConsent = false;
  String? autoCaptureConsentAt;
  String? autoCaptureConsentVersion;

  // Onboarding and legal state. The version strings live in legal_content.dart
  // so the screens, persistence and tests cannot drift apart.
  bool welcomeSeen = false;
  bool tutorialCompleted = false;

  // Sound & haptics preferences.
  bool soundEnabled = true;
  double soundVolume = 0.35;
  bool hapticsEnabled = true;

  // Splash intro preferences.
  bool splashIntroEnabled = true;
  bool splashIntroSeen = false;
  bool tutorialInProgress = false;
  bool tutorialSkipped = false;
  int tutorialStep = 0;
  String? tutorialCompletedAt;
  String? legalAcceptedVersion;
  String? legalAcceptedAt;

  /// Backwards-compatible view used by older pieces of the UI and tests.
  bool get carryForward => allowancePolicy == AllowancePolicy.carryForward;

  TimeOfDay get morningTime => _timeFromMinutes(morningMinutes);
  TimeOfDay get nightTime => _timeFromMinutes(nightMinutes);

  static TimeOfDay _timeFromMinutes(int minutes) =>
      TimeOfDay(hour: (minutes ~/ 60) % 24, minute: minutes % 60);

  static int _minutesFromTime(TimeOfDay time) => time.hour * 60 + time.minute;

  static String dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  bool get encryptedAtRest => _storage.encryptionEnabled;

  Future<void> load() async {
    final s = await _storage.loadSettings();
    currencyCode = (s['currencyCode'] as String?) ?? currencyCode;
    userName = (s['userName'] as String?) ?? userName;
    monthlyBudget = ((s['monthlyBudget'] as num?) ?? monthlyBudget).toDouble();
    seeded = (s['seeded'] as bool?) ?? seeded;
    welcomeSeen = (s['welcomeSeen'] as bool?) ?? seeded;
    splashIntroEnabled =
        (s['splashIntroEnabled'] as bool?) ?? splashIntroEnabled;
    splashIntroSeen = (s['splashIntroSeen'] as bool?) ?? splashIntroSeen;
    soundEnabled = (s['soundEnabled'] as bool?) ?? soundEnabled;
    soundVolume =
        ((s['soundVolume'] as num?) ?? soundVolume).toDouble().clamp(0.0, 1.0);
    hapticsEnabled = (s['hapticsEnabled'] as bool?) ?? hapticsEnabled;
    SoundService.instance.enabled = soundEnabled;
    SoundService.instance.volume = soundVolume;
    SoundService.instance.hapticsEnabled = hapticsEnabled;
    blockScreenshots = (s['blockScreenshots'] as bool?) ?? blockScreenshots;

    final savedPolicy = s['allowancePolicy'] as String?;
    if (savedPolicy != null) {
      allowancePolicy = AllowancePolicy.values.firstWhere(
        (p) => p.name == savedPolicy,
        orElse: () => AllowancePolicy.carryForward,
      );
    } else {
      // Migration from the old boolean switch.
      allowancePolicy = ((s['carryForward'] as bool?) ?? true)
          ? AllowancePolicy.carryForward
          : AllowancePolicy.buffer;
    }

    moneyProtection = (s['moneyProtection'] as bool?) ?? moneyProtection;
    emergencyBuffer =
        ((s['emergencyBuffer'] as num?) ?? emergencyBuffer).toDouble();
    studentMode = (s['studentMode'] as bool?) ?? studentMode;
    recoveryActive = (s['recoveryActive'] as bool?) ?? recoveryActive;
    recoveryDailyCut =
        ((s['recoveryDailyCut'] as num?) ?? recoveryDailyCut).toDouble();
    recoveryDays = (s['recoveryDays'] as num?)?.toInt() ?? recoveryDays;
    recoveryTarget =
        ((s['recoveryTarget'] as num?) ?? recoveryTarget).toDouble();
    recoveryStartedOn = s['recoveryStartedOn'] as String?;
    missingExpenseDismissedOn = s['missingExpenseDismissedOn'] as String?;

    morningBriefing = (s['morningBriefing'] as bool?) ?? morningBriefing;
    nightSummary = (s['nightSummary'] as bool?) ?? nightSummary;
    budgetAlerts = (s['budgetAlerts'] as bool?) ?? budgetAlerts;
    notificationsAsked =
        (s['notificationsAsked'] as bool?) ?? notificationsAsked;
    autoCapture = (s['autoCapture'] as bool?) ?? autoCapture;
    notificationsConsent = (s['notificationsConsent'] as bool?) ??
        (notificationsAsked &&
            (morningBriefing || nightSummary || budgetAlerts));
    notificationsConsentAt = s['notificationsConsentAt'] as String?;
    notificationsConsentVersion = s['notificationsConsentVersion'] as String?;
    autoCaptureConsent = (s['autoCaptureConsent'] as bool?) ?? autoCapture;
    autoCaptureConsentAt = s['autoCaptureConsentAt'] as String?;
    autoCaptureConsentVersion = s['autoCaptureConsentVersion'] as String?;

    tutorialCompleted = (s['tutorialCompleted'] as bool?) ?? false;
    tutorialInProgress = (s['tutorialInProgress'] as bool?) ?? false;
    tutorialSkipped = (s['tutorialSkipped'] as bool?) ?? false;
    tutorialStep =
        ((s['tutorialStep'] as num?)?.toInt() ?? 0).clamp(0, 999).toInt();
    tutorialCompletedAt = s['tutorialCompletedAt'] as String?;
    legalAcceptedVersion = s['legalAcceptedVersion'] as String?;
    legalAcceptedAt = s['legalAcceptedAt'] as String?;

    await _storage.setCaptureEnabled(autoCapture);
    await _storage.setNotificationPromptsEnabled(notificationsConsent);
    morningMinutes = (s['morningMinutes'] as num?)?.toInt() ?? morningMinutes;
    nightMinutes = (s['nightMinutes'] as num?)?.toInt() ?? nightMinutes;
    switch (s['themeMode'] as String?) {
      case 'light':
        themeMode = ThemeMode.light;
      case 'dark':
        themeMode = ThemeMode.dark;
      default:
        themeMode = ThemeMode.system;
    }
  }

  Future<void> _persist() => _storage.saveSettings({
        'currencyCode': currencyCode,
        'userName': userName,
        'monthlyBudget': monthlyBudget,
        'themeMode': themeMode.name,
        'seeded': seeded,
        'blockScreenshots': blockScreenshots,
        'allowancePolicy': allowancePolicy.name,
        // Kept for older installs and for the notification signature.
        'carryForward': carryForward,
        'moneyProtection': moneyProtection,
        'emergencyBuffer': emergencyBuffer,
        'studentMode': studentMode,
        'recoveryActive': recoveryActive,
        'recoveryDailyCut': recoveryDailyCut,
        'recoveryDays': recoveryDays,
        'recoveryTarget': recoveryTarget,
        'recoveryStartedOn': recoveryStartedOn,
        'missingExpenseDismissedOn': missingExpenseDismissedOn,
        'morningBriefing': morningBriefing,
        'morningMinutes': morningMinutes,
        'nightSummary': nightSummary,
        'nightMinutes': nightMinutes,
        'budgetAlerts': budgetAlerts,
        'notificationsAsked': notificationsAsked,
        'notificationsConsent': notificationsConsent,
        'notificationsConsentAt': notificationsConsentAt,
        'notificationsConsentVersion': notificationsConsentVersion,
        'autoCapture': autoCapture,
        'autoCaptureConsent': autoCaptureConsent,
        'autoCaptureConsentAt': autoCaptureConsentAt,
        'autoCaptureConsentVersion': autoCaptureConsentVersion,
        'welcomeSeen': welcomeSeen,
        'tutorialCompleted': tutorialCompleted,
        'splashIntroEnabled': splashIntroEnabled,
        'splashIntroSeen': splashIntroSeen,
        'soundEnabled': soundEnabled,
        'soundVolume': soundVolume,
        'hapticsEnabled': hapticsEnabled,
        'tutorialInProgress': tutorialInProgress,
        'tutorialSkipped': tutorialSkipped,
        'tutorialStep': tutorialStep,
        'tutorialCompletedAt': tutorialCompletedAt,
        'legalAcceptedVersion': legalAcceptedVersion,
        'legalAcceptedAt': legalAcceptedAt,
      });

  Future<void> setCurrency(String code) async {
    if (code == currencyCode) return;
    currencyCode = code;
    notifyListeners();
    await _persist();
  }

  Future<void> setUserName(String value) async {
    final name = value.trim();
    if (name == userName) return;
    userName = name;
    notifyListeners();
    await _persist();
  }

  Future<void> setMonthlyBudget(double value) async {
    monthlyBudget = value < 0 ? 0 : value;
    notifyListeners();
    await _persist();
  }

  Future<void> setAllowancePolicy(AllowancePolicy policy) async {
    if (policy == allowancePolicy) return;
    allowancePolicy = policy;
    notifyListeners();
    await _persist();
  }

  /// Old boolean API: true means carry forward, false means keep as buffer.
  Future<void> setCarryForward(bool value) => setAllowancePolicy(
        value ? AllowancePolicy.carryForward : AllowancePolicy.buffer,
      );

  Future<void> setMoneyProtection(bool value) async {
    if (value == moneyProtection) return;
    moneyProtection = value;
    notifyListeners();
    await _persist();
  }

  Future<void> setEmergencyBuffer(double value) async {
    final next = value < 0 ? 0.0 : value;
    if (next == emergencyBuffer) return;
    emergencyBuffer = next;
    notifyListeners();
    await _persist();
  }

  Future<void> setStudentMode(bool value) async {
    if (value == studentMode) return;
    studentMode = value;
    notifyListeners();
    await _persist();
  }

  /// Starts a recovery plan on [now]'s local date.
  Future<void> startRecovery({
    required double dailyCut,
    required int days,
    required double target,
    DateTime? now,
  }) async {
    final start = now ?? DateTime.now();
    recoveryActive = dailyCut > 0 && days > 0;
    recoveryDailyCut = dailyCut < 0 ? 0 : dailyCut;
    recoveryDays = days < 1 ? 0 : days;
    recoveryTarget = target < 0 ? 0 : target;
    recoveryStartedOn = recoveryActive ? dateKey(start) : null;
    if (!recoveryActive) {
      recoveryDailyCut = 0;
      recoveryDays = 0;
      recoveryTarget = 0;
    }
    notifyListeners();
    await _persist();
  }

  Future<void> dismissRecovery() async {
    recoveryActive = false;
    recoveryDailyCut = 0;
    recoveryDays = 0;
    recoveryTarget = 0;
    recoveryStartedOn = null;
    notifyListeners();
    await _persist();
  }

  /// The amount to subtract from the allowance on [day], or zero when the
  /// plan is inactive or finished.
  double recoveryCutOn(DateTime day) {
    if (!recoveryActive || recoveryDailyCut <= 0 || recoveryDays <= 0) {
      return 0;
    }
    final start = DateTime.tryParse(recoveryStartedOn ?? '');
    if (start == null) return 0;
    final today = DateTime(day.year, day.month, day.day);
    final first = DateTime(start.year, start.month, start.day);
    final index = today.difference(first).inDays;
    if (index < 0 || index >= recoveryDays) return 0;
    return recoveryDailyCut;
  }

  /// 1-based day number in the plan, or zero when it is not running.
  int recoveryDayNumber(DateTime day) {
    if (recoveryCutOn(day) <= 0) return 0;
    final start = DateTime.tryParse(recoveryStartedOn ?? '');
    if (start == null) return 0;
    final today = DateTime(day.year, day.month, day.day);
    final first = DateTime(start.year, start.month, start.day);
    return today.difference(first).inDays + 1;
  }

  bool recoveryFinished(DateTime day) {
    if (!recoveryActive) return false;
    final start = DateTime.tryParse(recoveryStartedOn ?? '');
    if (start == null) return true;
    final today = DateTime(day.year, day.month, day.day);
    final first = DateTime(start.year, start.month, start.day);
    return today.difference(first).inDays >= recoveryDays;
  }

  Future<void> dismissMissingExpense(DateTime day) async {
    missingExpenseDismissedOn = dateKey(day);
    notifyListeners();
    await _persist();
  }

  bool missingExpenseDismissed(DateTime day) =>
      missingExpenseDismissedOn == dateKey(day);

  Future<void> setThemeMode(ThemeMode mode) async {
    if (mode == themeMode) return;
    themeMode = mode;
    notifyListeners();
    await _persist();
  }

  Future<void> setBlockScreenshots(bool value) async {
    if (value == blockScreenshots) return;
    blockScreenshots = value;
    notifyListeners();
    await _persist();
    await ScreenSecurity.setBlocked(value);
  }

  /// Restores only user-facing preferences from a backup.
  ///
  /// Security state, consent, notification choices and onboarding progress are
  /// intentionally excluded: they describe this device and this person, not an
  /// old backup file.
  Future<void> restoreBackupPreferences(Map<String, dynamic> s) async {
    final code = s['currencyCode'];
    if (code is String && kCurrencies.any((c) => c.code == code)) {
      currencyCode = code;
    }
    final name = s['userName'];
    if (name is String) userName = name.trim();
    final budget = s['monthlyBudget'];
    if (budget is num && budget.isFinite && budget >= 0) {
      monthlyBudget = budget.toDouble();
    }
    final policy = s['allowancePolicy'];
    if (policy is String) {
      allowancePolicy = AllowancePolicy.values.firstWhere(
        (p) => p.name == policy,
        orElse: () => allowancePolicy,
      );
    }
    final protection = s['moneyProtection'];
    if (protection is bool) moneyProtection = protection;
    final buffer = s['emergencyBuffer'];
    if (buffer is num && buffer.isFinite && buffer >= 0) {
      emergencyBuffer = buffer.toDouble();
    }
    final student = s['studentMode'];
    if (student is bool) studentMode = student;
    switch (s['themeMode']) {
      case 'light':
        themeMode = ThemeMode.light;
      case 'dark':
        themeMode = ThemeMode.dark;
      case 'system':
        themeMode = ThemeMode.system;
    }
    notifyListeners();
    await _persist();
  }

  Future<void> setMorningBriefing(bool value) async {
    if (value == morningBriefing) return;
    morningBriefing = value;
    if (value) await _recordNotificationConsent();
    notifyListeners();
    await _persist();
  }

  Future<void> setNightSummary(bool value) async {
    if (value == nightSummary) return;
    nightSummary = value;
    if (value) await _recordNotificationConsent();
    notifyListeners();
    await _persist();
  }

  Future<void> setBudgetAlerts(bool value) async {
    if (value == budgetAlerts) return;
    budgetAlerts = value;
    if (value) await _recordNotificationConsent();
    notifyListeners();
    await _persist();
  }

  /// Records that the user asked for a notification feature.
  ///
  /// The Android permission itself is still requested separately by the
  /// settings flow. This record exists so the consent choice and version are
  /// inspectable later.
  Future<void> _recordNotificationConsent() async {
    notificationsConsent = true;
    notificationsConsentAt ??= DateTime.now().toIso8601String();
    notificationsConsentVersion ??= kConsentVersion;
    await _storage.setNotificationPromptsEnabled(true);
  }

  /// Master switch used by the Consent screen. Turning it off disables every
  /// notification feature instead of leaving a hidden channel enabled.
  Future<void> setNotificationsConsent(bool value) async {
    notificationsConsent = value;
    if (value) {
      notificationsConsentAt = DateTime.now().toIso8601String();
      notificationsConsentVersion = kConsentVersion;
    } else {
      notificationsConsentAt = null;
      notificationsConsentVersion = null;
      morningBriefing = false;
      nightSummary = false;
      budgetAlerts = false;
    }
    notifyListeners();
    await _storage.setNotificationPromptsEnabled(value);
    await _persist();
  }

  Future<void> setMorningTime(TimeOfDay time) async {
    morningMinutes = _minutesFromTime(time);
    notifyListeners();
    await _persist();
  }

  Future<void> setNightTime(TimeOfDay time) async {
    nightMinutes = _minutesFromTime(time);
    notifyListeners();
    await _persist();
  }

  Future<void> setAutoCapture(bool value) async {
    if (value == autoCapture) return;
    autoCapture = value;
    autoCaptureConsent = value;
    if (value) {
      autoCaptureConsentAt = DateTime.now().toIso8601String();
      autoCaptureConsentVersion = kConsentVersion;
    } else {
      autoCaptureConsentAt = null;
      autoCaptureConsentVersion = null;
    }
    notifyListeners();
    await _storage.setCaptureEnabled(value);
    await _persist();
  }

  /// True when the current policy version has been accepted and recorded.
  bool get hasAcceptedCurrentPolicies =>
      legalAcceptedVersion == kLegalVersion && legalAcceptedAt != null;

  Future<void> acceptPolicies({DateTime? now}) async {
    legalAcceptedVersion = kLegalVersion;
    legalAcceptedAt = (now ?? DateTime.now()).toIso8601String();
    notifyListeners();
    await _persist();
  }

  /// Leaves the welcome gate and enters the app without the tour.
  Future<void> dismissWelcome() async {
    welcomeSeen = true;
    tutorialInProgress = false;
    notifyListeners();
    await _persist();
  }

  Future<void> startTutorial() async {
    welcomeSeen = true;
    tutorialInProgress = true;
    tutorialStep = 0;
    tutorialSkipped = false;
    notifyListeners();
    await _persist();
  }

  Future<void> setTutorialStep(int step) async {
    final next = step < 0 ? 0 : step;
    if (next == tutorialStep) return;
    tutorialStep = next;
    tutorialInProgress = true;
    notifyListeners();
    await _persist();
  }

  /// Marks the tour complete while keeping the completion card on screen until
  /// the user taps "Start using DailyMoney".
  Future<void> markTutorialCompleted({DateTime? now}) async {
    tutorialCompleted = true;
    tutorialCompletedAt = (now ?? DateTime.now()).toIso8601String();
    tutorialStep = 999;
    tutorialInProgress = true;
    notifyListeners();
    await _persist();
  }

  Future<void> finishTutorial() async {
    tutorialInProgress = false;
    notifyListeners();
    await _persist();
  }

  Future<void> skipTutorial() async {
    tutorialInProgress = false;
    tutorialSkipped = true;
    tutorialStep = 0;
    notifyListeners();
    await _persist();
  }

  /// Enables or disables the splash intro animation.
  Future<void> setSplashIntroEnabled(bool value) async {
    if (value == splashIntroEnabled) return;
    splashIntroEnabled = value;
    notifyListeners();
    await _persist();
  }

  Future<void> setSoundEnabled(bool value) async {
    if (value == soundEnabled) return;
    soundEnabled = value;
    SoundService.instance.enabled = value;
    notifyListeners();
    await _persist();
  }

  Future<void> setSoundVolume(double value) async {
    final v = value.clamp(0.0, 1.0);
    if (v == soundVolume) return;
    soundVolume = v;
    SoundService.instance.volume = v;
    notifyListeners();
    await _persist();
  }

  Future<void> setHapticsEnabled(bool value) async {
    if (value == hapticsEnabled) return;
    hapticsEnabled = value;
    SoundService.instance.hapticsEnabled = value;
    notifyListeners();
    await _persist();
  }

  /// Marks the splash intro as seen.
  Future<void> markSplashIntroSeen() async {
    if (splashIntroSeen) return;
    splashIntroSeen = true;
    notifyListeners();
    await _persist();
  }

  /// Replays the tour immediately from step one.
  Future<void> replayTutorial() async {
    welcomeSeen = true;
    tutorialInProgress = true;
    tutorialSkipped = false;
    tutorialStep = 0;
    notifyListeners();
    await _persist();
  }

  /// Shows the welcome screen again on the next app launch. Legal acceptance
  /// is intentionally not cleared; only the tutorial/welcome state is.
  Future<void> resetTutorialProgress() async {
    welcomeSeen = false;
    tutorialCompleted = false;
    tutorialInProgress = false;
    tutorialSkipped = false;
    tutorialStep = 0;
    tutorialCompletedAt = null;
    notifyListeners();
    await _persist();
  }

  Future<void> markNotificationsAsked() async {
    if (notificationsAsked) return;
    notificationsAsked = true;
    await _persist();
  }

  Future<void> markSeeded() async {
    if (seeded) return;
    seeded = true;
    await _persist();
  }

  /// Restores first-run defaults after a full data wipe.
  Future<void> resetToDefaults() async {
    currencyCode = 'USD';
    userName = '';
    monthlyBudget = 0;
    themeMode = ThemeMode.system;
    blockScreenshots = true;
    allowancePolicy = AllowancePolicy.carryForward;
    moneyProtection = true;
    emergencyBuffer = 0;
    studentMode = false;
    recoveryActive = false;
    recoveryDailyCut = 0;
    recoveryDays = 0;
    recoveryTarget = 0;
    recoveryStartedOn = null;
    missingExpenseDismissedOn = null;
    morningBriefing = false;
    morningMinutes = 8 * 60;
    nightSummary = false;
    nightMinutes = 21 * 60;
    budgetAlerts = false;
    notificationsAsked = false;
    notificationsConsent = false;
    notificationsConsentAt = null;
    notificationsConsentVersion = null;
    autoCapture = false;
    autoCaptureConsent = false;
    autoCaptureConsentAt = null;
    autoCaptureConsentVersion = null;
    welcomeSeen = false;
    tutorialCompleted = false;
    tutorialInProgress = false;
    tutorialSkipped = false;
    tutorialStep = 0;
    tutorialCompletedAt = null;
    splashIntroEnabled = true;
    splashIntroSeen = false;
    soundEnabled = true;
    soundVolume = 0.35;
    hapticsEnabled = true;
    legalAcceptedVersion = null;
    legalAcceptedAt = null;
    // Keep demo data out of a deliberate reset.
    seeded = true;
    notifyListeners();
    await _storage.setCaptureEnabled(false);
    await _storage.setNotificationPromptsEnabled(false);
    await _persist();
  }
}
