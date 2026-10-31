import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Thin wrapper around local notifications.
///
/// Every method is best-effort: if the platform plugin is unavailable (for
/// example in a widget test) the app keeps working and simply sends nothing.
class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _ready = false;

  static bool get isReady => _ready;

  static const int morningId = 1001;
  static const int nightId = 1002;
  static const int budgetAlertId = 1003;

  static const String _dailyChannel = 'dm_daily';
  static const String _alertChannel = 'dm_budget';

  /// Loads the device timezone and registers the plugin. Safe to call once at
  /// startup; failures leave [isReady] false.
  static Future<void> init() async {
    try {
      tzdata.initializeTimeZones();
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      // Keep the default location; schedules still work in most cases.
    }

    try {
      const android = AndroidInitializationSettings('ic_stat_wallet');
      const darwin = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: android,
          iOS: darwin,
          macOS: darwin,
        ),
      );
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  /// Asks for notification permission. Returns true when allowed.
  static Future<bool> requestPermission() async {
    if (!_ready) return false;
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        return await android.requestNotificationsPermission() ?? false;
      }
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        return await ios.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Replaces the two daily briefings with the supplied content.
  static Future<void> refreshBriefings({
    required bool morningEnabled,
    required TimeOfDay morningTime,
    required String morningTitle,
    required String morningBody,
    required bool nightEnabled,
    required TimeOfDay nightTime,
    required String nightTitle,
    required String nightBody,
  }) async {
    if (!_ready) return;
    try {
      await _plugin.cancel(id: morningId);
      await _plugin.cancel(id: nightId);
      if (morningEnabled) {
        await _scheduleDaily(
          id: morningId,
          time: morningTime,
          title: morningTitle,
          body: morningBody,
        );
      }
      if (nightEnabled) {
        await _scheduleDaily(
          id: nightId,
          time: nightTime,
          title: nightTitle,
          body: nightBody,
        );
      }
    } catch (_) {
      // Never break the UI because a notification could not be scheduled.
    }
  }

  /// Shows an immediate budget alert.
  static Future<void> showBudgetAlert({
    required String title,
    required String body,
  }) async {
    if (!_ready) return;
    try {
      await _plugin.show(
        id: budgetAlertId,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _alertChannel,
            'Budget alerts',
            channelDescription:
                'Warnings when the daily allowance is nearly used',
            icon: 'ic_stat_wallet',
            importance: Importance.high,
            priority: Priority.high,
            color: Color(0xFFF59E0B),
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
    } catch (_) {
      // Ignore. The in-app card already shows the same state.
    }
  }

  static Future<void> _scheduleDaily({
    required int id,
    required TimeOfDay time,
    required String title,
    required String body,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    if (!scheduled.isAfter(now)) {
      // Rebuild tomorrow's wall-clock time instead of adding 24 hours, which
      // would drift across a daylight-saving change.
      scheduled = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day + 1,
        time.hour,
        time.minute,
      );
    }

    await _plugin.zonedSchedule(
      id: id,
      scheduledDate: scheduled,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _dailyChannel,
          'Daily briefings',
          channelDescription: 'Morning allowance and nightly spending summary',
          icon: 'ic_stat_wallet',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          color: Color(0xFF10B981),
        ),
        iOS: DarwinNotificationDetails(),
      ),
      // Inexact avoids the Android 14 exact-alarm permission while still
      // delivering reliably around the chosen time.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }
}
