import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'app_detection_service.dart';
import 'screen_capture_service.dart';
import 'content_analysis_service.dart';
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
 * 6. Minimize app ke home screen jika user klik "Tutup Aplikasi"
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

  // Timer untuk auto-resume monitoring jika overlay tidak merespons
  Timer? _pauseTimeoutTimer;

  /**
   * START - Mulai auto screenshot dengan CHECK SEMUA PERMISSION DULU
   * 
   * FLOW:
   * 1. Check & request Screen Capture permission
   * 2. Check & request Overlay permission (SYSTEM_ALERT_WINDOW)
   * 3. Setup overlay event listener
   * 4. Start monitoring
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

      // ✅ STEP 3: Setup overlay event listener
      print('3️⃣ Setting up overlay event listener...');
      _overlayEventSubscription = _overlayService.overlayEvents.listen((event) {
        _handleOverlayEvent(event);
      });
      print('✅ Overlay event listener ready');

      // ✅ STEP 4: Semua permission OK! Start monitoring
      print('✅ ALL PERMISSIONS GRANTED! Starting monitoring...');

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
      'Total ${screenshotCount.value} screenshot tersimpan di memory',
      backgroundColor: Colors.orange,
      colorText: Colors.white,
      duration: const Duration(seconds: 3),
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

      // ✅ START TIMEOUT TIMER: Auto-resume setelah 10 detik jika tidak ada event
      _pauseTimeoutTimer?.cancel();
      _pauseTimeoutTimer = Timer(const Duration(seconds: 10), () {
        if (isPaused.value) {
          print('⏰ Timeout reached! No overlay event received.');
          print('✅ Auto-resuming monitoring...');
          isPaused.value = false;
        }
      });
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

    // Cancel timeout timer jika ada event masuk
    _pauseTimeoutTimer?.cancel();
    _pauseTimeoutTimer = null;

    final action = event['action'] as String?;

    if (action == 'dismissed') {
      // User klik "Abaikan" (LOW only)
      print('ℹ️ User dismissed warning (LOW level)');

      // ✅ RESUME monitoring
      isPaused.value = false;
      print('✅ Monitoring RESUMED after dismiss');
    } else if (action == 'close_app') {
      // User klik "Tutup Aplikasi" - App sudah di-minimize ke home screen oleh native
      final appName = event['app_name'] as String? ?? 'Unknown';
      print('🏠 User chose to close app: $appName (already minimized to home)');

      // ✅ RESUME monitoring
      isPaused.value = false;
      print('✅ Monitoring RESUMED after closing app');
    }
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
    _pauseTimeoutTimer?.cancel();
    _overlayEventSubscription?.cancel();
    super.onClose();
  }
}
