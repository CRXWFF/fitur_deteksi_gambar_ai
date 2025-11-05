import 'dart:typed_data';
import 'package:flutter/services.dart';

/**
 * OVERLAY SERVICE - Komunikasi dengan native OverlayService untuk popup realtime
 * 
 * FLOW:
 * 1. showOverlay() → kirim intent ke native OverlayService
 * 2. Native tampilkan overlay di atas TikTok/Instagram (REALTIME)
 * 3. User pilih aksi (Abaikan/Tutup Aplikasi)
 * 4. Native broadcast hasil ke Flutter via EventChannel
 * 5. Flutter handle callback (onDismiss/onCloseApp)
 */
class OverlayService {
  static const MethodChannel _channel = MethodChannel('com.reflvy.app/overlay');

  static const EventChannel _eventChannel =
      EventChannel('com.reflvy.app/overlay_events');

  /**
   * Cek apakah SYSTEM_ALERT_WINDOW permission sudah diaktifkan
   */
  Future<bool> canDrawOverlays() async {
    try {
      final bool result = await _channel.invokeMethod('canDrawOverlays');
      return result;
    } catch (e) {
      print('❌ Error checking overlay permission: $e');
      return false;
    }
  }

  /**
   * Buka settings untuk aktifkan SYSTEM_ALERT_WINDOW permission
   */
  Future<void> openOverlaySettings() async {
    try {
      await _channel.invokeMethod('openOverlaySettings');
    } catch (e) {
      print('❌ Error opening overlay settings: $e');
    }
  }

  /**
   * Tampilkan overlay REALTIME di atas aplikasi yang sedang dibuka (TikTok, Instagram, dll)
   * 
   * Input:
   * - level: LOW, MEDIUM, HIGH
   * - appName: nama aplikasi (TikTok, Instagram, dll)
   * - imageBytes: screenshot yang terdeteksi berbahaya
   */
  Future<void> showOverlay({
    required String level,
    required String appName,
    required Uint8List imageBytes,
  }) async {
    try {
      print('📢 Sending overlay to native: level=$level, app=$appName');

      await _channel.invokeMethod('showOverlay', {
        'level': level,
        'app_name': appName,
        'image_bytes': imageBytes,
      });

      print('✅ Overlay request sent to native');
    } catch (e) {
      print('❌ Error showing overlay: $e');
    }
  }

  /**
   * Sembunyikan overlay
   */
  Future<void> hideOverlay() async {
    try {
      await _channel.invokeMethod('hideOverlay');
    } catch (e) {
      print('❌ Error hiding overlay: $e');
    }
  }

  /**
   * Listen event dari native (user dismiss/close app)
   * 
   * Return Stream yang emit:
   * - {'action': 'dismissed'} → user pilih Abaikan
   * - {'action': 'close_app', 'app_name': 'TikTok'} → user pilih Tutup Aplikasi
   */
  Stream<Map<String, dynamic>> get overlayEvents {
    return _eventChannel.receiveBroadcastStream().map((event) {
      print('📨 Received overlay event: $event');
      return Map<String, dynamic>.from(event as Map);
    });
  }
}
