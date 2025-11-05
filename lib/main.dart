import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'route.dart';
import 'services/auto_screenshot_service.dart';

/**
 * MAIN - Entry point aplikasi
 * 
 * SETUP:
 * 1. Initialize AutoScreenshotService
 * 2. Jalankan app dengan GetMaterialApp
 * 3. Route ke MonitoringScreen untuk AI monitoring
 * 
 * FITUR:
 * - Auto screenshot setiap 5 detik
 * - AI content detection (LOW/MEDIUM/HIGH)
 * - Realtime popup overlay intervention
 * - App minimize to home screen
 */
void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Register GetX controllers secara global
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
      initialRoute: Routes.monitoring,
      getPages: AppPages.pages,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
    );
  }
}
