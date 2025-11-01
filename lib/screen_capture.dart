import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'controllers/recording_controller.dart';
import 'controllers/capture_controller.dart';

class ScreenCapture extends StatefulWidget {
  const ScreenCapture({super.key});

  @override
  State<ScreenCapture> createState() => _ScreenCaptureState();
}

class _ScreenCaptureState extends State<ScreenCapture> {
  late final RecordingController _recCtrl;
  late final CaptureController _captureCtrl;

  @override
  void initState() {
    super.initState();
    _captureCtrl = Get.put(CaptureController());
    _recCtrl = Get.put(RecordingController());
    // jika dipanggil dengan argument true -> mulai
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = Get.arguments;
      if (args is bool && args) {
        _recCtrl.startNativeRecording();
      }
    });
  }

  @override
  void dispose() {
    // jangan stop otomatis di dispose — biarkan user yang menghentikan jika ingin persist saat navigasi
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Screen Capture'),
        actions: [
          Obx(() {
            final isRec = _recCtrl.isRecording.value;
            return IconButton(
              tooltip: isRec ? 'Stop' : 'Start',
              icon: Icon(isRec ? Icons.stop : Icons.fiber_manual_record),
              onPressed: () {
                if (isRec) {
                  _recCtrl.stopNativeRecording();
                } else {
                  _recCtrl.startNativeRecording();
                }
              },
            );
          }),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Obx(() {
                final isRec = _recCtrl.isRecording.value;
                final count = _captureCtrl.captures.length;
                return Text(
                  isRec ? 'Recording... ($count captures)' : 'Not recording',
                  style: const TextStyle(fontSize: 18),
                );
              }),
            ),
          ),
          Obx(() {
            final list = _captureCtrl.captures;
            if (list.isEmpty) return const SizedBox.shrink();
            return SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: list.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Image.memory(list[index]),
                  );
                },
              ),
            );
          }),
        ],
      ),
    );
  }
}
