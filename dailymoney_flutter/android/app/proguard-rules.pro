# DailyMoney release shrinking rules.
#
# R8/ProGuard can remove and rename bytecode, but it cannot make reverse
# engineering impossible. These rules keep the entry points that Flutter,
# plugins and Android reflection rely on.

# Flutter engine and embedding.
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class * implements io.flutter.embedding.engine.plugins.FlutterPlugin { *; }
-keep class * extends io.flutter.plugin.common.MethodChannel$MethodCallHandler { *; }
-dontwarn io.flutter.embedding.**

# Keep annotations and reflection metadata used by plugins.
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes Exceptions
-keepattributes InnerClasses
-keepattributes EnclosingMethod
-keepattributes RuntimeVisibleAnnotations

# flutter_local_notifications
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-dontwarn com.dexterous.flutterlocalnotifications.**

# local_auth / biometric APIs
-keep class androidx.biometric.** { *; }
-dontwarn androidx.biometric.**

# flutter_secure_storage
-keep class com.it_nomads.fluttersecurestorage.** { *; }
-dontwarn com.it_nomads.fluttersecurestorage.**
