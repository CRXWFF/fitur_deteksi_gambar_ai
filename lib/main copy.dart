import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'route.dart';
import 'controllers/capture_controller.dart';
import 'controllers/recording_controller.dart';
import 'services/auto_screenshot_service.dart';

/**
 * MAIN - Entry point aplikasi
 * 
 * SETUP:
 * 1. Initialize GetX controllers (CaptureController, RecordingController, AutoScreenshotService)
 * 2. Jalankan app dengan GetMaterialApp
 * 
 * CATATAN:
 * - Screenshot tidak menggunakan widget wrapper lagi
 * - Capture dilakukan di native side (MediaProjection API)
 * - Flutter hanya menampilkan UI dan menerima hasil screenshot
 */
void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Register semua GetX controllers secara global
  Get.put(CaptureController());
  Get.put(RecordingController());
  Get.put(AutoScreenshotService());

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Reflvy - AI Monitor',
      debugShowCheckedModeBanner: false,
      initialRoute: Routes.home,
      getPages: AppPages.pages,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
    );
  }
}
