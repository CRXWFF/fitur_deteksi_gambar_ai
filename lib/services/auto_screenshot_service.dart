import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'app_detection_service.dart';
import 'screen_capture_service.dart';

/**
 * AutoScreenshotService - Service untuk auto capture setiap 5 detik
 * 
 * FUNGSI:
 * 1. Timer otomatis setiap 5 detik
 * 2. Capture FULL SCREEN (bukan cuma app Flutter)
 * 3. Detect app yang sedang dibuka
 * 4. Save ke folder dengan filename: screenshot_[time]_[appname].png
 * 5. Track semua screenshot dalam list
 */
class AutoScreenshotService extends GetxController {
  // Service untuk detect app name
  final AppDetectionService _appDetectionService = AppDetectionService();

  // Service untuk capture FULL SCREEN (MediaProjection)
  final ScreenCaptureService _screenCaptureService = ScreenCaptureService();

  // Timer untuk loop 5 detik
  Timer? _timer;

  // Observable variables untuk UI update
  final RxBool isRecording = false.obs;
  final RxInt screenshotCount = 0.obs;
  final RxString currentApp = 'Unknown'.obs;
  final RxList<Map<String, dynamic>> screenshots = <Map<String, dynamic>>[].obs;

  // Path folder untuk session ini
  String? _sessionFolder;

  /**
   * START - Mulai auto screenshot setiap 5 detik
   * 
   * FLOW:
   * 1. Request MediaProjection permission (popup system)
   * 2. User klik "Start now"
   * 3. Buat folder untuk session ini
   * 4. Capture screenshot pertama
   * 5. Start timer untuk capture tiap 5 detik
   */
  Future<void> startAutoScreenshot() async {
    if (isRecording.value) return;

    // STEP 1: Request permission untuk capture full screen
    print('🔑 Requesting screen capture permission...');
    bool permissionGranted = await _screenCaptureService.startCapture();

    if (!permissionGranted) {
      Get.snackbar(
        'Permission Denied',
        'Anda harus mengizinkan screen capture untuk melanjutkan',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
      return;
    }

    print('✅ Permission granted! Setting up monitoring...');

    // STEP 2: Buat folder untuk session ini
    await _createSessionFolder();

    // STEP 3: Reset counters
    isRecording.value = true;
    screenshotCount.value = 0;
    screenshots.clear();

    // STEP 4: Wait for warm-up (native side does dummy capture ~1.2s)
    // Give a safe buffer so first real capture succeeds on most devices
    print('⏳ Waiting ~1.5s for VirtualDisplay warm-up...');
    await Future.delayed(const Duration(milliseconds: 1500));

    // STEP 5: Start timer untuk capture setiap 5 detik
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      await _captureAndSave();
    });

    // STEP 6: Capture pertama
    print('📸 Starting first actual capture...');
    await _captureAndSave();

    Get.snackbar(
      'Recording Started ✅',
      'Screenshot akan diambil setiap 5 detik',
      backgroundColor: Colors.green,
      colorText: Colors.white,
      duration: const Duration(seconds: 3),
    );
  }

  /**
   * STOP - Hentikan auto screenshot
   * 
   * FLOW:
   * 1. Cancel timer
   * 2. Stop MediaProjection
   * 3. Show summary
   */
  Future<void> stopAutoScreenshot() async {
    // Cancel timer
    _timer?.cancel();
    _timer = null;

    // Stop screen capture
    await _screenCaptureService.stopCapture();

    isRecording.value = false;

    Get.snackbar(
      'Recording Stopped ⏹️',
      'Total ${screenshotCount.value} screenshot disimpan di:\n$_sessionFolder',
      backgroundColor: Colors.orange,
      colorText: Colors.white,
      duration: const Duration(seconds: 5),
    );
  }

  /**
   * CAPTURE AND SAVE - Ambil 1 screenshot dan simpan ke file
   * 
   * FLOW:
   * 1. Detect app yang sedang dibuka (UsageStatsManager)
   * 2. Capture full screen frame (MediaProjection)
   * 3. Generate filename: screenshot_[time]_[appname].png
   * 4. Save ke folder session
   * 5. Add ke list screenshots
   */
  Future<void> _captureAndSave() async {
    try {
      // STEP 1: Deteksi aplikasi yang sedang dibuka
      String appName = await _appDetectionService.getCurrentApp();
      currentApp.value = appName;
      print('📱 Current app: $appName');

      // STEP 2: Capture FULL SCREEN - langsung tanpa wait
      final Uint8List? imageBytes = await _screenCaptureService.captureFrame();

      if (imageBytes == null) {
        print(
          '! No frame available yet - VirtualDisplay might still be initializing',
        );
        print('   Will retry in 5 seconds...');
        return;
      }

      if (imageBytes.isEmpty) {
        print('⚠️ Captured image is empty');
        return;
      }

      // STEP 3: Generate filename dengan timestamp
      String timestamp = DateFormat('HHmmss_SSS').format(DateTime.now());
      String safeAppName = appName.replaceAll(' ', '_').replaceAll('/', '_');
      String filename = 'screenshot_${timestamp}_$safeAppName.png';

      if (_sessionFolder == null) {
        print('❌ Session folder is null!');
        return;
      }

      String filePath = '$_sessionFolder/$filename';

      // STEP 4: Simpan ke file
      try {
        File file = File(filePath);
        await file.writeAsBytes(imageBytes);
        print('💾 File saved to: $filePath');
      } catch (e) {
        print('❌ Error saving file: $e');
        return;
      }

      // STEP 5: Increment counter
      screenshotCount.value++;

      // STEP 6: Simpan info ke list
      screenshots.add({
        'timestamp': DateTime.now(),
        'app_name': appName,
        'file_path': filePath,
        'file_size': imageBytes.length,
      });

      // Log info
      print('✅ Screenshot #${screenshotCount.value} saved: $filename');
      print('   📱 App: $appName');
      print('   📦 Size: ${(imageBytes.length / 1024).toStringAsFixed(2)} KB');
    } catch (e, stackTrace) {
      print('❌ Error capturing screenshot: $e');
      print('   Stack trace: $stackTrace');
    }
  }

  /// Buat folder untuk session ini
  Future<void> _createSessionFolder() async {
    try {
      // Get external storage directory
      Directory? externalDir = await getExternalStorageDirectory();

      if (externalDir == null) {
        print('❌ External storage not available');
        return;
      }

      // Buat folder dengan nama tanggal dan waktu
      String sessionName = DateFormat(
        'yyyy-MM-dd_HH-mm-ss',
      ).format(DateTime.now());
      String basePath = '${externalDir.path}/Reflvy_Screenshots';
      _sessionFolder = '$basePath/$sessionName';

      Directory sessionDir = Directory(_sessionFolder!);
      if (!await sessionDir.exists()) {
        await sessionDir.create(recursive: true);
      }

      print('📁 Session folder created: $_sessionFolder');
    } catch (e) {
      print('❌ Error creating session folder: $e');
    }
  }

  /// Get folder path saat ini
  String? getSessionFolder() {
    return _sessionFolder;
  }

  /// Clear semua data
  void clear() {
    screenshots.clear();
    screenshotCount.value = 0;
    currentApp.value = 'Unknown';
  }

  @override
  void onClose() {
    _timer?.cancel();
    super.onClose();
  }
}
