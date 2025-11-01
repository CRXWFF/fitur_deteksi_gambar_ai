import 'dart:typed_data';
import 'package:get/get.dart';

class CaptureController extends GetxController {
  // list reaktif menyimpan screenshots (Uint8List)
  final RxList<Uint8List> captures = <Uint8List>[].obs;

  void addCapture(Uint8List bytes) {
    captures.add(bytes);
  }

  // hapus capture berdasarkan instance bytes (jika ada)
  bool remove(Uint8List bytes) {
    return captures.remove(bytes);
  }

  // hapus berdasarkan index jika valid
  void removeAt(int index) {
    if (index >= 0 && index < captures.length) {
      captures.removeAt(index);
    }
  }

  void clear() {
    captures.clear();
  }
}
