import 'package:flutter/services.dart';

/// Bridge to the native notification listener.
class CaptureService {
  CaptureService._();

  static const MethodChannel _channel =
      MethodChannel('com.dailymoney.app/capture');

  /// Whether the user has granted notification access to DailyMoney.
  static Future<bool> hasAccess() async {
    try {
      return await _channel.invokeMethod<bool>('hasAccess') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Opens Android's notification-access screen for this app.
  static Future<void> openSettings() async {
    try {
      await _channel.invokeMethod<void>('openSettings');
    } catch (_) {
      // Nothing to do if the OEM removed the screen.
    }
  }
}
