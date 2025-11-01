import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/auto_screenshot_service.dart';
import '../services/app_detection_service.dart';

class MonitoringScreen extends StatefulWidget {
  const MonitoringScreen({super.key});

  @override
  State<MonitoringScreen> createState() => _MonitoringScreenState();
}

class _MonitoringScreenState extends State<MonitoringScreen> {
  final AutoScreenshotService _screenshotService =
      Get.find<AutoScreenshotService>();
  final AppDetectionService _appDetectionService = AppDetectionService();

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    // Request storage permission
    if (await Permission.storage.isDenied) {
      await Permission.storage.request();
    }

    // Request photos permission untuk Android 13+
    if (await Permission.photos.isDenied) {
      await Permission.photos.request();
    }

    // Check Usage Stats permission untuk deteksi app
    Future.delayed(const Duration(milliseconds: 500), () async {
      bool hasPermission = await _appDetectionService.hasPermission();
      if (!hasPermission && mounted) {
        _showUsageStatsPermissionDialog();
      }
    });
  }

  void _showUsageStatsPermissionDialog() {
    Get.dialog(
      AlertDialog(
        title: const Text('⚠️ Permission Diperlukan'),
        content: const Text(
          'Aplikasi memerlukan izin "Usage Access" untuk mendeteksi aplikasi yang sedang dibuka.\n\n'
          'Langkah-langkah:\n'
          '1. Klik "Buka Settings" di bawah\n'
          '2. Cari "Reflvy" atau "fitur_deteksi_gambar_ai"\n'
          '3. Aktifkan toggle "Permit usage access"\n'
          '4. Kembali ke aplikasi ini',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Nanti'),
          ),
          ElevatedButton(
            onPressed: () async {
              Get.back();
              await _appDetectionService.requestPermission();

              // Show instruction snackbar
              Get.snackbar(
                'Aktifkan Permission',
                'Cari app ini dalam daftar dan aktifkan "Permit usage access"',
                backgroundColor: Colors.orange,
                colorText: Colors.white,
                duration: const Duration(seconds: 5),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
            ),
            child: const Text('Buka Settings'),
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reflvy Monitor'),
        centerTitle: true,
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // Status Card
            Obx(() => Card(
                  elevation: 4,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: _screenshotService.isRecording.value
                            ? [Colors.red.shade400, Colors.red.shade700]
                            : [Colors.blue.shade400, Colors.blue.shade700],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          _screenshotService.isRecording.value
                              ? Icons.fiber_manual_record
                              : Icons.play_circle_outline,
                          size: 60,
                          color: Colors.white,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _screenshotService.isRecording.value
                              ? '🔴 MONITORING AKTIF'
                              : '⏸️ MONITORING BERHENTI',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                )),

            const SizedBox(height: 20),

            // Info Card
            Obx(() => Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        _buildInfoRow(
                          Icons.camera_alt,
                          'Screenshots',
                          '${_screenshotService.screenshotCount.value}',
                          Colors.blue,
                        ),
                        const Divider(),
                        _buildInfoRow(
                          Icons.apps,
                          'Current App',
                          _screenshotService.currentApp.value,
                          Colors.green,
                        ),
                        const Divider(),
                        _buildInfoRow(
                          Icons.folder,
                          'Save Folder',
                          _screenshotService.getSessionFolder() ??
                              'Not created',
                          Colors.orange,
                        ),
                      ],
                    ),
                  ),
                )),

            const SizedBox(height: 20),

            // Control Buttons
            Obx(() => _screenshotService.isRecording.value
                ? ElevatedButton.icon(
                    onPressed: () {
                      _screenshotService.stopAutoScreenshot();
                    },
                    icon: const Icon(Icons.stop),
                    label: const Text('STOP MONITORING'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 15,
                      ),
                      textStyle: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                : ElevatedButton.icon(
                    onPressed: () async {
                      await _screenshotService.startAutoScreenshot();
                    },
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('START MONITORING'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 15,
                      ),
                      textStyle: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )),

            const SizedBox(height: 20),

            // Screenshot List
            Expanded(
              child: Obx(() {
                if (_screenshotService.screenshots.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.photo_library_outlined,
                          size: 80,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Belum ada screenshot',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return Card(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        color: Colors.deepPurple.shade50,
                        child: Row(
                          children: [
                            const Icon(Icons.history, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Screenshot History (${_screenshotService.screenshots.length})',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          itemCount: _screenshotService.screenshots.length,
                          reverse: true, // Newest first
                          itemBuilder: (context, index) {
                            final reversedIndex =
                                _screenshotService.screenshots.length -
                                    1 -
                                    index;
                            final screenshot =
                                _screenshotService.screenshots[reversedIndex];
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.deepPurple,
                                child: Text(
                                  '${reversedIndex + 1}',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                              title: Text(screenshot['app_name']),
                              subtitle: Text(
                                '${screenshot['timestamp'].toString().substring(11, 19)} • '
                                '${(screenshot['file_size'] / 1024).toStringAsFixed(1)} KB',
                              ),
                              trailing: const Icon(Icons.check_circle,
                                  color: Colors.green),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
