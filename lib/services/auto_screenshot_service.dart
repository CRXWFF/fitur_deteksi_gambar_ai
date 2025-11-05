import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'app_detection_service.dart';
import 'screen_capture_service.dart';
import 'content_analysis_service.dart';
import 'app_killer_service.dart';
import 'overlay_service.dart';

/**
 * AutoScreenshotService - Service untuk auto capture setiap 5 detik
 * 
 * FUNGSI:
 * 1. Timer otomatis setiap 5 detik
 * 2. Capture FULL SCREEN (bukan cuma app Flutter)
 * 3. Detect app yang sedang dibuka
 * 4. Analisis konten dengan AI (dummy: random LOW/MEDIUM/HIGH)
 * 5. Intervensi otomatis jika detect konten berbahaya
 * 6. Force close aplikasi target jika user klik "Tutup Aplikasi"
 * 7. Track semua screenshot dalam list (in-memory)
 */
class AutoScreenshotService extends GetxController {
  // Service untuk detect app name
  final AppDetectionService _appDetectionService = AppDetectionService();

  // Service untuk capture FULL SCREEN (MediaProjection)
  final ScreenCaptureService _screenCaptureService = ScreenCaptureService();

  // Service untuk analisis konten (AI dummy)
  final ContentAnalysisService _contentAnalysisService =
      ContentAnalysisService();

  // Service untuk force close aplikasi
  final AppKillerService _appKillerService = AppKillerService();

  // Service untuk overlay realtime
  final OverlayService _overlayService = OverlayService();

  // Timer untuk loop 5 detik
  Timer? _timer;

  // Stream subscription untuk overlay events
  StreamSubscription<Map<String, dynamic>>? _overlayEventSubscription;

  // Observable variables untuk UI update
  final RxBool isRecording = false.obs;
  final RxInt screenshotCount = 0.obs;
  final RxString currentApp = 'Unknown'.obs;
  final RxList<Map<String, dynamic>> screenshots = <Map<String, dynamic>>[].obs;

  // Flag untuk pause monitoring saat popup intervensi muncul
  final RxBool isPaused = false.obs;

  // Path folder untuk session ini (opsional - sekarang simpan di memory)
  String? _sessionFolder;

  /**
   * START - Mulai auto screenshot dengan CHECK SEMUA PERMISSION DULU
   * 
   * FLOW:
   * 1. Check & request Screen Capture permission
   * 2. Check & request Overlay permission (SYSTEM_ALERT_WINDOW)
   * 3. Check & request Accessibility permission (untuk force close)
   * 4. Setup overlay event listener
   * 5. Start monitoring
   */
  Future<void> startAutoScreenshot() async {
    if (isRecording.value) return;

    try {
      print('🚀 Starting AUTO SCREENSHOT MONITORING...');
      print('🔑 Checking all permissions...');

      // ✅ STEP 1: Screen Capture Permission
      print('1️⃣ Checking Screen Capture permission...');
      bool captureGranted = await _screenCaptureService.startCapture();

      if (!captureGranted) {
        Get.snackbar(
          '❌ Permission Denied',
          'Screen capture permission diperlukan untuk monitoring',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          duration: Duration(seconds: 3),
        );
        return;
      }
      print('✅ Screen Capture permission granted');

      // ✅ STEP 2: Overlay Permission (SYSTEM_ALERT_WINDOW)
      print('2️⃣ Checking Overlay permission...');
      bool canDrawOverlays = await _overlayService.canDrawOverlays();

      if (!canDrawOverlays) {
        print('⚠️ Overlay permission not granted');

        // Tampilkan dialog konfirmasi
        bool? userWantsToContinue = await Get.dialog<bool>(
          AlertDialog(
            title: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange),
                SizedBox(width: 8),
                Text('Permission Required'),
              ],
            ),
            content: Text(
              'Aplikasi membutuhkan izin "Display over other apps" untuk menampilkan peringatan REALTIME di atas TikTok/Instagram.\n\n'
              'Tanpa permission ini, popup hanya muncul saat Anda kembali ke app.\n\n'
              'Aktifkan sekarang?',
              style: TextStyle(fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: () => Get.back(result: false),
                child: Text('Batal'),
              ),
              ElevatedButton(
                onPressed: () => Get.back(result: true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                ),
                child: Text('Buka Settings'),
              ),
            ],
          ),
          barrierDismissible: false,
        );

        if (userWantsToContinue == true) {
          await _overlayService.openOverlaySettings();

          // Tunggu user balik dari settings
          Get.snackbar(
            'ℹ️ Info',
            'Aktifkan permission dan kembali ke app untuk melanjutkan',
            backgroundColor: Colors.blue,
            colorText: Colors.white,
            duration: Duration(seconds: 5),
          );
        }

        return; // Stop monitoring jika user tidak enable
      }
      print('✅ Overlay permission granted');

      // ✅ STEP 3: Accessibility Permission (untuk force close)
      print('3️⃣ Checking Accessibility permission...');
      bool accessibilityEnabled =
          await _appKillerService.isAccessibilityServiceEnabled();

      if (!accessibilityEnabled) {
        print('⚠️ Accessibility permission not granted');

        // Tampilkan dialog konfirmasi
        bool? userWantsToContinue = await Get.dialog<bool>(
          AlertDialog(
            title: Row(
              children: [
                Icon(Icons.accessibility_new, color: Colors.orange),
                SizedBox(width: 8),
                Text('Permission Required'),
              ],
            ),
            content: Text(
              'Aplikasi membutuhkan izin "Accessibility Service" untuk menutup aplikasi berbahaya secara otomatis.\n\n'
              'Tanpa permission ini, aplikasi berbahaya tidak akan ditutup otomatis.\n\n'
              'Aktifkan sekarang?',
              style: TextStyle(fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: () => Get.back(result: false),
                child: Text('Batal'),
              ),
              ElevatedButton(
                onPressed: () => Get.back(result: true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                ),
                child: Text('Buka Settings'),
              ),
            ],
          ),
          barrierDismissible: false,
        );

        if (userWantsToContinue == true) {
          await _appKillerService.openAccessibilitySettings();

          // Tunggu user balik dari settings
          Get.snackbar(
            'ℹ️ Info',
            'Aktifkan "Reflvy" di Accessibility dan kembali ke app',
            backgroundColor: Colors.blue,
            colorText: Colors.white,
            duration: Duration(seconds: 5),
          );
        }

        return; // Stop monitoring jika user tidak enable
      }
      print('✅ Accessibility permission granted');

      // ✅ STEP 4: Setup overlay event listener
      print('4️⃣ Setting up overlay event listener...');
      _overlayEventSubscription = _overlayService.overlayEvents.listen((event) {
        _handleOverlayEvent(event);
      });
      print('✅ Overlay event listener ready');

      // ✅ STEP 5: Semua permission OK! Start monitoring
      print('✅ ALL PERMISSIONS GRANTED! Starting monitoring...');

      // Buat folder untuk session
      await _createSessionFolder();

      // Reset state
      isRecording.value = true;
      screenshotCount.value = 0;
      screenshots.clear();
      isPaused.value = false; // Pastikan tidak paused

      // Wait for warm-up
      print('⏳ Waiting ~1.5s for VirtualDisplay warm-up...');
      await Future.delayed(const Duration(milliseconds: 1500));

      // Start timer
      _timer = Timer.periodic(const Duration(seconds: 5), (timer) async {
        await _captureAndSave();
      });

      // First capture
      print('📸 Starting first actual capture...');
      await _captureAndSave();

      // Success notification
      Get.snackbar(
        '✅ Monitoring Started',
        'Auto screenshot setiap 5 detik dengan AI detection',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: Duration(seconds: 3),
      );
    } catch (e, stackTrace) {
      print('❌ Error starting monitoring: $e');
      print('Stack: $stackTrace');

      Get.snackbar(
        '❌ Error',
        'Gagal memulai monitoring: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
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
   * CAPTURE - Ambil 1 screenshot, analisis konten, dan lakukan intervensi jika perlu
   * 
   * FLOW:
   * 1. Cek jika sedang pause (popup tampil) → skip
   * 2. Detect app yang sedang dibuka (UsageStatsManager)
   * 3. Capture full screen frame (MediaProjection)
   * 4. Analisis konten dengan AI (dummy: random level)
   * 5. Jika detect konten berbahaya → PAUSE monitoring & tampilkan popup
   * 6. User pilih aksi → Resume monitoring
   */
  Future<void> _captureAndSave() async {
    // Jika sedang pause (popup intervensi muncul), skip capture
    if (isPaused.value) {
      print('⏸️ Monitoring paused (popup is showing), skipping capture');
      return;
    }

    try {
      // STEP 1: Deteksi aplikasi yang sedang dibuka
      String appName = await _appDetectionService.getCurrentApp();
      currentApp.value = appName;
      print('📱 Current app: $appName');

      // STEP 2: Capture FULL SCREEN
      final Uint8List? imageBytes = await _screenCaptureService.captureFrame();

      if (imageBytes == null) {
        print('! No frame available yet - VirtualDisplay initializing');
        print('   Will retry in 5 seconds...');
        return;
      }

      if (imageBytes.isEmpty) {
        print('⚠️ Captured image is empty');
        return;
      }

      // STEP 3: Analisis konten dengan AI (dummy)
      print('🔍 Analyzing content...');
      ContentLevel level =
          await _contentAnalysisService.analyzeContent(imageBytes);

      String levelLabel = ContentAnalysisService.getLabelForLevel(level);
      print('📊 Analysis result: $levelLabel');

      // STEP 4: Jika terdeteksi konten berbahaya → INTERVENSI!
      if (level != ContentLevel.safe) {
        print('🚨 DANGEROUS CONTENT DETECTED! Level: $levelLabel');
        print('⏸️ Pausing monitoring...');

        isPaused.value = true; // Pause monitoring

        // Simpan screenshot untuk history
        screenshotCount.value++;
        screenshots.add({
          'timestamp': DateTime.now(),
          'app_name': appName,
          'image_bytes': imageBytes,
          'size': imageBytes.length,
          'level': level, // Simpan level untuk UI
        });

        // Tampilkan popup intervensi
        _showInterventionPopup(level, appName, imageBytes);
      } else {
        // Konten aman, simpan saja (opsional)
        print('✅ Content is SAFE, no intervention needed');

        screenshotCount.value++;
        screenshots.add({
          'timestamp': DateTime.now(),
          'app_name': appName,
          'image_bytes': imageBytes,
          'size': imageBytes.length,
          'level': level,
        });

        print('✅ Screenshot #${screenshotCount.value} saved');
        print(
            '   📦 Size: ${(imageBytes.length / 1024).toStringAsFixed(2)} KB');
      }
    } catch (e, stackTrace) {
      print('❌ Error: $e');
      print('Stack: $stackTrace');
    }
  }

  /**
   * Fungsi: Tampilkan popup intervensi REALTIME di atas TikTok/Instagram
   * Input: level, appName, imageBytes
   * 
   * REALTIME = Popup muncul langsung di atas aplikasi yang sedang dibuka!
   * LOW: User bisa abaikan atau tutup app
   * MEDIUM/HIGH: User harus tutup app
   */
  void _showInterventionPopup(
    ContentLevel level,
    String appName,
    Uint8List imageBytes,
  ) async {
    try {
      // Cek permission overlay dulu
      bool canDraw = await _overlayService.canDrawOverlays();

      if (!canDraw) {
        print('⚠️ Overlay permission not granted!');
        print('   Opening settings...');

        // Tampilkan notifikasi ke user
        Get.snackbar(
          '⚠️ Permission Diperlukan',
          'Aktifkan "Display over other apps" untuk popup realtime',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
          duration: Duration(seconds: 5),
        );

        // Buka settings
        await _overlayService.openOverlaySettings();

        // Resume monitoring (user harus enable manual)
        isPaused.value = false;
        return;
      }

      // Tampilkan overlay REALTIME!
      String levelString = ContentAnalysisService.getLabelForLevel(level);
      print('📢 Showing REALTIME overlay: $levelString');

      await _overlayService.showOverlay(
        level: levelString,
        appName: appName,
        // ✅ NO MORE imageBytes - fixed TransactionTooLargeException
      );

      print('✅ Overlay displayed, waiting for user action...');
    } catch (e) {
      print('❌ Error showing overlay: $e');

      // Resume monitoring jika error
      isPaused.value = false;
    }
  }

  /**
   * Handle event dari native overlay (user klik tombol)
   * 
   * Event types:
   * - dismissed: User klik "Abaikan" (LOW only)
   * - close_app: User klik "Tutup Aplikasi"
   */
  void _handleOverlayEvent(Map<String, dynamic> event) {
    print('📨 Overlay event received: $event');

    final action = event['action'] as String?;

    if (action == 'dismissed') {
      // User klik "Abaikan" (LOW only)
      print('ℹ️ User dismissed warning (LOW level)');

      // ✅ RESUME monitoring
      isPaused.value = false;
      print('✅ Monitoring RESUMED after dismiss');
    } else if (action == 'close_app') {
      // User klik "Tutup Aplikasi"
      final appName = event['app_name'] as String? ?? 'Unknown';
      print('🚫 User chose to close app: $appName');

      // Force close app
      _forceCloseTargetApp(appName);

      // ✅ RESUME monitoring
      isPaused.value = false;
      print('✅ Monitoring RESUMED after closing app');
    }
  }

  /**
   * Fungsi: Force close aplikasi target
   * Input: appName (contoh: "TikTok", "Instagram")
   * 
   * 1. Convert nama app ke package name
   * 2. Panggil native Kotlin untuk force close
   * 3. Tampilkan notifikasi ke user
   */
  Future<void> _forceCloseTargetApp(String appName) async {
    try {
      // Cek apakah Accessibility Service sudah aktif
      bool isEnabled = await _appKillerService.isAccessibilityServiceEnabled();

      if (!isEnabled) {
        // Jika belum aktif, buka settings
        print('⚠️ Accessibility Service not enabled');

        Get.snackbar(
          '⚠️ Permission Diperlukan',
          'Aktifkan Accessibility Service untuk menutup aplikasi',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
          duration: Duration(seconds: 3),
        );

        await _appKillerService.openAccessibilitySettings();
        return;
      }

      // Convert nama app ke package name
      String packageName = _appKillerService.getPackageNameFromAppName(appName);
      print('📦 Package name: $packageName');

      // Force close app
      bool success = await _appKillerService.forceCloseApp(packageName);

      if (success) {
        Get.snackbar(
          '✅ Aplikasi Ditutup',
          '$appName telah ditutup untuk keamanan Anda',
          backgroundColor: Colors.green,
          colorText: Colors.white,
          duration: Duration(seconds: 2),
        );
      } else {
        Get.snackbar(
          '⚠️ Gagal Menutup',
          'Tidak dapat menutup $appName',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          duration: Duration(seconds: 2),
        );
      }
    } catch (e) {
      print('❌ Error closing app: $e');

      Get.snackbar(
        '❌ Error',
        'Terjadi kesalahan: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: Duration(seconds: 2),
      );
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
    _overlayEventSubscription?.cancel();
    super.onClose();
  }
}
