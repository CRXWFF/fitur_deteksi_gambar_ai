import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'controllers/capture_controller.dart';
import 'controllers/recording_controller.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    // pastikan controller tersedia (tidak membuat duplikat jika sudah ada)
    final CaptureController captureCtrl = Get.isRegistered<CaptureController>()
        ? Get.find<CaptureController>()
        : Get.put(CaptureController());

    final RecordingController recCtrl = Get.isRegistered<RecordingController>()
        ? Get.find<RecordingController>()
        : Get.put(RecordingController());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        centerTitle: true,
        titleTextStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.red,
        ),
        actions: [
          // tombol hapus semua dengan konfirmasi
          IconButton(
            icon: const Icon(Icons.delete_forever_outlined),
            tooltip: 'Hapus semua screenshot',
            onPressed: () async {
              if (captureCtrl.captures.isEmpty) {
                Get.snackbar(
                  'Info',
                  'Tidak ada screenshot untuk dihapus',
                  snackPosition: SnackPosition.BOTTOM,
                );
                return;
              }
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Hapus semua?'),
                  content: const Text(
                    'Semua thumbnail screenshot akan dihapus.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Batal'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Hapus'),
                    ),
                  ],
                ),
              );
              if (confirmed == true) {
                captureCtrl.clear();
                Get.snackbar(
                  'Berhasil',
                  'Semua screenshot dihapus',
                  snackPosition: SnackPosition.BOTTOM,
                );
              }
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // kotak dengan 3 row (tetap)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.redAccent,
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: Colors.black),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .5),
                    spreadRadius: 2,
                    blurRadius: 5,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text(
                        'Arul Ganteng',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        'Arul Ganteng',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text(
                        'Arul Ganteng',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        'Arul Ganteng',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text(
                        'Arul Ganteng',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        'Arul Ganteng',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // Tombol ke Monitoring Screen - FITUR BARU
            ElevatedButton.icon(
              onPressed: () {
                Get.toNamed('/monitoring');
              },
              icon: const Icon(Icons.monitor, size: 28),
              label: const Text('AUTO SCREENSHOT MONITOR'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 30,
                  vertical: 15,
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                elevation: 5,
              ),
            ),

            const SizedBox(height: 20),

            // preview thumbnails dari captures (reaktif) — horizontal scroll dengan Scrollbar
            Obx(() {
              final list = captureCtrl.captures;
              if (list.isEmpty) {
                return const SizedBox.shrink();
              }

              final ScrollController thumbController = ScrollController();

              return SizedBox(
                height: 110,
                child: Scrollbar(
                  controller: thumbController,
                  thumbVisibility: true,
                  radius: const Radius.circular(8),
                  child: ListView.builder(
                    controller: thumbController,
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: list.length,
                    itemBuilder: (context, idx) {
                      final bytes = list[idx];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6.0),
                        child: GestureDetector(
                          // tap buka full screen
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (_) => Dialog(
                                insetPadding: const EdgeInsets.all(8),
                                child: InteractiveViewer(
                                  child: Image.memory(bytes),
                                ),
                              ),
                            );
                          },
                          // long press untuk menghapus satu item (dengan konfirmasi)
                          onLongPress: () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text('Hapus screenshot?'),
                                content: const Text(
                                  'Screenshot ini akan dihapus dari daftar.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(false),
                                    child: const Text('Batal'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(true),
                                    child: const Text('Hapus'),
                                  ),
                                ],
                              ),
                            );
                            if (confirmed == true) {
                              captureCtrl.removeAt(idx);
                              Get.snackbar(
                                'Dihapus',
                                'Screenshot dihapus',
                                snackPosition: SnackPosition.BOTTOM,
                              );
                            }
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(
                              bytes,
                              width: 90,
                              height: 90,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              );
            }),

            const SizedBox(height: 20),

            // Start / Stop recording buttons di halaman Home
            Obx(() {
              final isRec = recCtrl.isRecording.value;
              return ElevatedButton.icon(
                onPressed: () async {
                  if (isRec) {
                    await recCtrl.stopNativeRecording();
                    // Tampilkan feedback setelah operasi selesai
                    if (recCtrl.lastError.value.isNotEmpty) {
                      Get.snackbar(
                        'Error',
                        recCtrl.lastError.value,
                        snackPosition: SnackPosition.BOTTOM,
                        backgroundColor: Colors.red,
                        colorText: Colors.white,
                      );
                    } else if (recCtrl.lastMessage.value.isNotEmpty) {
                      Get.snackbar(
                        'Success',
                        recCtrl.lastMessage.value,
                        snackPosition: SnackPosition.BOTTOM,
                        duration: const Duration(seconds: 2),
                      );
                    }
                  } else {
                    await recCtrl.startNativeRecording();
                    // Tampilkan feedback setelah operasi selesai
                    if (recCtrl.lastError.value.isNotEmpty) {
                      Get.snackbar(
                        'Error',
                        recCtrl.lastError.value,
                        snackPosition: SnackPosition.BOTTOM,
                        backgroundColor: Colors.red,
                        colorText: Colors.white,
                      );
                    } else if (recCtrl.lastMessage.value.isNotEmpty) {
                      Get.snackbar(
                        'Success',
                        recCtrl.lastMessage.value,
                        snackPosition: SnackPosition.BOTTOM,
                        duration: const Duration(seconds: 2),
                      );
                    }
                  }
                },
                icon: Icon(isRec ? Icons.stop : Icons.play_arrow_rounded),
                label: Text(isRec ? 'Stop Record' : 'Start Record'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isRec ? Colors.red : Colors.black,
                  foregroundColor: Colors.white,
                  elevation: 3,
                  shadowColor: Colors.redAccent,
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
