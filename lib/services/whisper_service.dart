import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Offline speech recognition via whisper.cpp.
///
/// Requires the whisper model file (ggml-tiny.bin) placed at
///   /sdcard/Android/data/com.float.capture/files/models/ggml-tiny.bin
/// or push via adb:
///   adb push ggml-tiny.bin /sdcard/Android/data/com.float.capture/files/models/
class WhisperService {
  static const _channel = MethodChannel('com.float.capture/whisper');
  static const _resultChannel = EventChannel('com.float.capture/whisper_result');

  bool _loaded = false;

  Future<bool> loadModel({String? modelPath}) async {
    try {
      final path = modelPath ?? await _defaultModelPath();
      final ok = await _channel.invokeMethod<bool>('loadModel', {'path': path});
      _loaded = ok == true;
      return _loaded;
    } catch (_) {
      _loaded = false;
      return false;
    }
  }

  bool get isLoaded => _loaded;

  /// Transcribe an AMR audio file. Returns the recognized text.
  Future<String> transcribeFile(String filePath, {String language = 'zh'}) async {
    if (!_loaded) return '';

    final completer = Completer<String>();

    // Set up one-shot listener for the result
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onResult') {
        if (!completer.isCompleted) {
          completer.complete(call.arguments as String? ?? '');
        }
      } else if (call.method == 'onError') {
        if (!completer.isCompleted) {
          completer.complete('');
        }
      }
    });

    await _channel.invokeMethod('transcribeFile', {
      'filePath': filePath,
      'language': language,
    });

    // Timeout after 30s
    return completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () => '',
    );
  }

  Future<void> free() async {
    await _channel.invokeMethod('free');
    _loaded = false;
  }

  Future<String> _defaultModelPath() async {
    final dir = await getApplicationDocumentsDirectory();
    // /data/data/com.float.capture/app_flutter/ → /data/data/com.float.capture/files/models/ggml-tiny.bin
    final base = dir.path.replaceAll('/app_flutter', '');
    return '$base/files/models/ggml-tiny.bin';
  }
}
