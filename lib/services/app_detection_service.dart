import 'package:flutter/services.dart';

class AppDetectionService {
  static const platform = MethodChannel('com.reflvy.app/app_detection');

  String _lastDetectedApp = 'Unknown';
  String _lastPackageName = '';

  /// Check if app has Usage Stats permission
  Future<bool> hasPermission() async {
    try {
      final bool hasPermission = await platform.invokeMethod('hasPermission');
      print('✓ Has Usage Stats Permission: $hasPermission');
      return hasPermission;
    } on PlatformException catch (e) {
      print('❌ Error checking permission: ${e.message}');
      return false;
    } catch (e) {
      print('❌ Error checking permission: $e');
      return false;
    }
  }

  /// Request Usage Stats permission (opens Settings)
  Future<void> requestPermission() async {
    try {
      await platform.invokeMethod('requestPermission');
      print('✓ Opened Usage Stats Settings');
    } on PlatformException catch (e) {
      print('❌ Error requesting permission: ${e.message}');
    } catch (e) {
      print('❌ Error requesting permission: $e');
    }
  }

  /// Get aplikasi yang sedang dibuka (REAL DETECTION via Usage Stats API)
  Future<String> getCurrentApp() async {
    try {
      // Check permission first
      bool hasPermission = await this.hasPermission();
      if (!hasPermission) {
        print('⚠️ Usage Stats permission not granted');
        return 'Permission Required';
      }

      // Get current app from native code
      final String? appName = await platform.invokeMethod('getCurrentApp');

      if (appName != null && appName.isNotEmpty && appName != 'Unknown') {
        _lastDetectedApp = appName;
        print('✓ Current app detected: $appName');
        return appName;
      }

      print('⚠️ Could not detect app, using last: $_lastDetectedApp');
      return _lastDetectedApp.isEmpty ? 'Unknown' : _lastDetectedApp;
    } on PlatformException catch (e) {
      print('❌ Platform error detecting app: ${e.message}');
      return 'Error: ${e.message}';
    } catch (e) {
      print('❌ Error detecting current app: $e');
      return 'Error';
    }
  }

  /// Get package name (for debugging)
  Future<String> getCurrentPackage() async {
    try {
      final String? packageName =
          await platform.invokeMethod('getCurrentPackage');
      _lastPackageName = packageName ?? '';
      print('✓ Current package: $packageName');
      return _lastPackageName;
    } on PlatformException catch (e) {
      print('❌ Error getting package: ${e.message}');
      return '';
    } catch (e) {
      print('❌ Error getting package: $e');
      return '';
    }
  }

  /// Get last detected app
  String getLastDetectedApp() {
    return _lastDetectedApp;
  }
}

// Extension untuk capitalize string
extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
