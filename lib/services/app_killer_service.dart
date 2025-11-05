import 'package:flutter/services.dart';

/// Service untuk force close aplikasi target
/// Menggunakan Accessibility Service di native Android (Kotlin)
class AppKillerService {
  static const MethodChannel _channel =
      MethodChannel('com.reflvy.app/app_killer');

  /// Fungsi: Cek apakah Accessibility Service sudah aktif
  /// Return: true jika sudah aktif, false jika belum
  Future<bool> isAccessibilityServiceEnabled() async {
    try {
      final bool? isEnabled =
          await _channel.invokeMethod('isAccessibilityEnabled');
      return isEnabled ?? false;
    } catch (e) {
      print('❌ Error checking accessibility: $e');
      return false;
    }
  }

  /// Fungsi: Buka halaman pengaturan Accessibility
  /// User harus manual aktifkan service di Settings
  Future<void> openAccessibilitySettings() async {
    try {
      await _channel.invokeMethod('openAccessibilitySettings');
      print('✅ Membuka pengaturan Accessibility');
    } catch (e) {
      print('❌ Error opening accessibility settings: $e');
    }
  }

  /// Fungsi: Force close aplikasi target (TikTok, Instagram, dll)
  /// Input: packageName (contoh: "com.zhiliaoapp.musically" untuk TikTok)
  /// Return: true jika berhasil, false jika gagal
  Future<bool> forceCloseApp(String packageName) async {
    try {
      print('🚫 Mencoba force close: $packageName');

      final bool? success = await _channel.invokeMethod('forceCloseApp', {
        'packageName': packageName,
      });

      if (success == true) {
        print('✅ Berhasil force close: $packageName');
        return true;
      } else {
        print('⚠️ Gagal force close: $packageName');
        return false;
      }
    } catch (e) {
      print('❌ Error force closing app: $e');
      return false;
    }
  }

  /// Fungsi: Dapatkan package name dari nama app
  /// Mapping nama app ke package name
  String getPackageNameFromAppName(String appName) {
    // Lowercase untuk matching
    String lowerAppName = appName.toLowerCase();

    // Map nama app populer ke package name
    if (lowerAppName.contains('tiktok')) {
      return 'com.zhiliaoapp.musically';
    } else if (lowerAppName.contains('instagram')) {
      return 'com.instagram.android';
    } else if (lowerAppName.contains('facebook')) {
      return 'com.facebook.katana';
    } else if (lowerAppName.contains('youtube')) {
      return 'com.google.android.youtube';
    } else if (lowerAppName.contains('twitter') || lowerAppName.contains('x')) {
      return 'com.twitter.android';
    } else if (lowerAppName.contains('snapchat')) {
      return 'com.snapchat.android';
    } else if (lowerAppName.contains('telegram')) {
      return 'org.telegram.messenger';
    } else if (lowerAppName.contains('whatsapp')) {
      return 'com.whatsapp';
    } else if (lowerAppName.contains('chrome')) {
      return 'com.android.chrome';
    } else if (lowerAppName.contains('browser')) {
      return 'com.android.browser';
    } else {
      // Jika tidak ketemu, kembalikan nama app as-is
      // (mungkin sudah format package name)
      return appName;
    }
  }
}
