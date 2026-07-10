import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Thin wrapper around the native MediaRecorder via MethodChannel.
class AudioRecorder {
  static const _channel = MethodChannel('com.float.capture/audio_recorder');

  String? _currentPath;

  /// Start recording. Returns the file path being written to.
  Future<String> start() async {
    final dir = await getTemporaryDirectory();
    final ts = DateTime.now().millisecondsSinceEpoch;
    _currentPath = '${dir.path}/voice_$ts.amr';
    await _channel.invokeMethod('start', {'path': _currentPath});
    return _currentPath!;
  }

  /// Stop recording. Returns the saved file path.
  Future<String?> stop() async {
    final path = await _channel.invokeMethod('stop');
    _currentPath = null;
    return path as String?;
  }

  Future<bool> isRecording() async {
    final v = await _channel.invokeMethod('isRecording');
    return v == true;
  }

  void dispose() {
    if (_currentPath != null) {
      _channel.invokeMethod('stop').catchError((_) {});
    }
  }
}
