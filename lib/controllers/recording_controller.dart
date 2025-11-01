import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'dart:io' show Platform;

class RecordingController extends GetxController {
  static const MethodChannel _ch = MethodChannel('screen_rec');

  final RxBool isRecording = false.obs;
  final RxString lastError = ''.obs;
  final RxString lastMessage = ''.obs;

  @override
  void onInit() {
    super.onInit();
    debugPrint('RecordingController: Initialized');
  }

  Future<void> startNativeRecording() async {
    if (!Platform.isAndroid) {
      lastError.value = 'Screen recording only available on Android';
      debugPrint('RecordingController: ${lastError.value}');
      return;
    }

    try {
      debugPrint('RecordingController: Calling start method...');
      await _ch.invokeMethod('start');
      isRecording.value = true;
      lastMessage.value = 'Screen recording started';
      lastError.value = '';
      debugPrint('RecordingController: Start method called successfully');
    } on PlatformException catch (e) {
      debugPrint('RecordingController: PlatformException: ${e.message}');
      isRecording.value = false;
      lastError.value = 'Failed to start recording: ${e.message}';
      lastMessage.value = '';
    } on MissingPluginException catch (e) {
      debugPrint('RecordingController: MissingPluginException: $e');
      isRecording.value = false;
      lastError.value =
          'Native implementation not found. Did you rebuild the app?';
      lastMessage.value = '';
    } catch (e) {
      debugPrint('RecordingController: Unknown error: $e');
      isRecording.value = false;
      lastError.value = 'Unexpected error: $e';
      lastMessage.value = '';
    }
  }

  Future<void> stopNativeRecording() async {
    if (!Platform.isAndroid) {
      return;
    }

    try {
      debugPrint('RecordingController: Calling stop method...');
      await _ch.invokeMethod('stop');
      isRecording.value = false;
      lastMessage.value = 'Screen recording stopped';
      lastError.value = '';
      debugPrint('RecordingController: Stop method called successfully');
    } on PlatformException catch (e) {
      debugPrint('RecordingController: Stop PlatformException: ${e.message}');
      isRecording.value = false;
      lastError.value = 'Failed to stop recording: ${e.message}';
      lastMessage.value = '';
    } catch (e) {
      debugPrint('RecordingController: Stop error: $e');
      isRecording.value = false;
      lastError.value = 'Stop error: $e';
      lastMessage.value = '';
    }
  }
}
