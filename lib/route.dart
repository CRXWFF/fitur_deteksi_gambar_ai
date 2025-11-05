import 'package:get/get.dart';
import 'screens/monitoring_screen.dart';

class Routes {
  static const String monitoring = '/monitoring';
}

class AppPages {
  static final pages = [
    GetPage(name: Routes.monitoring, page: () => const MonitoringScreen()),
  ];
}

var apiLink = 'https://web-production-f55c5.up.railway.app/detect';
