import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'route.dart';
import 'controllers/capture_controller.dart';
import 'controllers/recording_controller.dart';
import 'package:screenshot/screenshot.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // siapkan controller global sebelum runApp
  Get.put(CaptureController());
  Get.put(RecordingController());
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // siapkan ScreenshotController lokal untuk menghindari dependensi pada RecordingController
    final ScreenshotController screenshotController = ScreenshotController();

    // bungkus seluruh app dengan Screenshot sehingga capture tetap bekerja di background
    return Screenshot(
      controller: screenshotController,
      child: GetMaterialApp(
        title: 'Fitur Deteksi AI',
        debugShowCheckedModeBanner: false,
        initialRoute: Routes.home,
        getPages: AppPages.pages,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.cyan),
          useMaterial3: true,
        ),
      ),
    );
  }
}
