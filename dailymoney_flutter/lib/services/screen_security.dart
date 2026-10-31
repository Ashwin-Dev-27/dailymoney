import 'package:flutter/services.dart';

/// Android window privacy controls that Flutter does not expose directly.
///
/// `FLAG_SECURE` hides app contents from screenshots and the recents preview.
/// The native side lives in `MainActivity.kt`. Failures are deliberately
/// non-fatal: an OEM that rejects the flag must not make the app unusable.
class ScreenSecurity {
  static const MethodChannel _channel =
      MethodChannel('com.dailymoney.app/privacy');

  static Future<void> setBlocked(bool blocked) async {
    try {
      await _channel.invokeMethod<void>('setSecure', {
        'enabled': blocked,
      });
    } catch (_) {
      // Tests and non-Android hosts have no channel; the preference is still
      // stored and applied on the next real Android launch.
    }
  }
}
