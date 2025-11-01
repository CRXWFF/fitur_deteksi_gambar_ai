import 'home.dart';
import 'package:get/get.dart';
import 'screen_capture.dart';

class Routes {
  static const String home = '/home';
  static const String screenCapture = '/screen_capture';
}

class AppPages {
  static final pages = [
    GetPage(name: Routes.home, page: () => const HomePage()),
    GetPage(name: Routes.screenCapture, page: () => const ScreenCapture()),
  ];
}

var apiLink = 'https://web-production-f55c5.up.railway.app/detect';
