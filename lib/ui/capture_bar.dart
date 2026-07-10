import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/capture_item.dart';
import '../services/analytics_service.dart';
import '../services/audio_recorder.dart';
import '../services/capture_storage.dart';
import '../services/whisper_service.dart';
import '../theme/app_theme.dart';

/// Signature for capture bar callbacks.
typedef CaptureCallback = void Function();
/// Signature for user activity notifications — resets the auto-dismiss safety timer.
typedef ActivityCallback = void Function();

// ---------------------------------------------------------------------------
// Text capture bar
// ---------------------------------------------------------------------------

class TextCaptureBar extends StatefulWidget {
  const TextCaptureBar({super.key, required this.onDone, required this.onCancel, this.onUserActivity});

  final CaptureCallback onDone;
  final CaptureCallback onCancel;
  final ActivityCallback? onUserActivity;

  @override
  State<TextCaptureBar> createState() => _TextCaptureBarState();
}

class _TextCaptureBarState extends State<TextCaptureBar> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _saving = false;
  bool _clipboardTried = false;

  @override
  void initState() {
    super.initState();
    _tryClipboard();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  Future<void> _tryClipboard() async {
    if (_clipboardTried) return;
    _clipboardTried = true;
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim();
      if (text != null && text.isNotEmpty && mounted) {
        _controller.text = text;
        _controller.selection = TextSelection.fromPosition(
          TextPosition(offset: text.length),
        );
      }
    } catch (_) {}
  }

  Future<void> _save() async {
    final content = _controller.text.trim();
    if (content.isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      await CaptureStorage.instance.insert(
        CaptureItem(content: content, capturedAt: DateTime.now()),
      );
      AnalyticsService.instance.trackEvent('capture_text_saved',
          properties: {'length': content.length});
      widget.onDone();
    } catch (e) {
      AnalyticsService.instance.error('TextCaptureBar', 'Save failed',
          properties: {'error': e.toString()});
      widget.onCancel();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(10),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: AppTheme.orbSurfaceGlass,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Spacer(),
              Container(
                width: 28, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: widget.onCancel,
                child: const Icon(Icons.close,
                    color: AppTheme.orbTextOnGlass, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Icon(Icons.edit_note, color: AppTheme.orbCore, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  style: const TextStyle(color: AppTheme.orbTextOnGlass, fontSize: 14),
                  maxLines: 3, minLines: 1,
                  textInputAction: TextInputAction.done,
                  onChanged: (_) => widget.onUserActivity?.call(),
                  onSubmitted: (_) => _save(),
                  decoration: InputDecoration(
                    hintText: '想到什么？',
                    hintStyle: TextStyle(
                      color: AppTheme.orbTextOnGlass.withValues(alpha: 0.35),
                      fontSize: 14,
                    ),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.06),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    isDense: true,
                  ),
                ),
              ),
              if (_saving)
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                )
              else
                GestureDetector(
                  onTap: _save,
                  child: Container(
                    margin: const EdgeInsets.only(left: 8, bottom: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.orbCore,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text('保存',
                        style: TextStyle(color: Colors.black, fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Clipboard auto-save
// ---------------------------------------------------------------------------

class ClipboardCaptureBar extends StatefulWidget {
  const ClipboardCaptureBar({super.key, required this.onDone});
  final CaptureCallback onDone;
  @override
  State<ClipboardCaptureBar> createState() => _ClipboardCaptureBarState();
}

class _ClipboardCaptureBarState extends State<ClipboardCaptureBar> {
  String? _status;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _tryClipboard();
  }

  Future<void> _tryClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim();
      if (text != null && text.isNotEmpty) {
        await CaptureStorage.instance.insert(
          CaptureItem(content: text, capturedAt: DateTime.now(), sourceHint: 'clipboard'),
        );
        AnalyticsService.instance.trackEvent('capture_clipboard_saved',
            properties: {'length': text.length});
        if (mounted) setState(() => _status = '✓ 已保存最近复制内容');
      } else {
        if (mounted) setState(() => _status = '剪贴板为空');
      }
    } catch (_) {
      if (mounted) setState(() => _status = '剪贴板不可用');
    }
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && !_done) { _done = true; widget.onDone(); }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.orbSurfaceGlass,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 20, offset: const Offset(0, 6))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.content_paste, color: Color(0xFF42A5F5), size: 20),
          const SizedBox(width: 10),
          Text(_status ?? '读取剪贴板中…',
              style: const TextStyle(color: AppTheme.orbTextOnGlass, fontSize: 13)),
          if (_done) ...[
            const SizedBox(width: 8),
            const Icon(Icons.check_circle, color: Color(0xFF66BB6A), size: 18),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Voice capture (audio recording)
// ---------------------------------------------------------------------------

class VoiceCaptureBar extends StatefulWidget {
  const VoiceCaptureBar({super.key, required this.onDone, this.onCancel, this.onUserActivity});
  final CaptureCallback onDone;
  final CaptureCallback? onCancel;
  final ActivityCallback? onUserActivity;

  @override
  State<VoiceCaptureBar> createState() => _VoiceCaptureBarState();
}

class _VoiceCaptureBarState extends State<VoiceCaptureBar> {
  static const _tag = 'VoiceCaptureBar';

  final _recorder = AudioRecorder();
  WhisperService? _whisper;
  bool _recording = false;
  bool _transcribing = false;
  int _seconds = 0;
  Timer? _timer;
  String? _filePath;
  String _transcript = '';

  @override
  void initState() {
    super.initState();
    _startRecording();
  }

  Future<void> _startRecording() async {
    if (_recording) return;
    try {
      _filePath = await _recorder.start();
      if (mounted) setState(() => _recording = true);
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) { setState(() => _seconds++); widget.onUserActivity?.call(); }
      });
    } catch (e) {
      AnalyticsService.instance.error(_tag, 'Record failed', properties: {'error': e.toString()});
    }
  }

  Future<void> _finish() async {
    _timer?.cancel();
    if (_recording) {
      try { _filePath = await _recorder.stop(); } catch (_) {}
    }
    if (!mounted) return;
    setState(() => _recording = false);

    if (_filePath != null && _seconds > 0) {
      // Lazy-init whisper only when needed
      if (_whisper == null) {
        _whisper = WhisperService();
        await _whisper!.loadModel();
      }
      if (_whisper!.isLoaded) {
        setState(() => _transcribing = true);
        final text = await _whisper!.transcribeFile(_filePath!);
        if (mounted) setState(() { _transcribing = false; _transcript = text; });
      }
    }
  }

  Future<void> _save() async {
    final text = _transcript.isNotEmpty ? _transcript : '🎤 语音笔记 $_duration';
    try {
      await CaptureStorage.instance.insert(
        CaptureItem(content: text, capturedAt: DateTime.now(), sourceHint: 'voice'),
      );
      AnalyticsService.instance.trackEvent('capture_voice_saved',
          properties: {'seconds': _seconds, 'hasTranscript': _transcript.isNotEmpty});
    } catch (e) {
      AnalyticsService.instance.error(_tag, 'Voice save failed', properties: {'error': e.toString()});
    }
    if (mounted) widget.onDone();
  }

  String get _duration => '${(_seconds ~/ 60).toString().padLeft(2, '0')}:${(_seconds % 60).toString().padLeft(2, '0')}';

  @override
  void dispose() {
    _timer?.cancel();
    if (_recording) { _recorder.stop().catchError((_) {}); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_recording) {
      return _buildBox(
        icon: Icons.mic, iconColor: const Color(0xFFEF5350),
        text: '🔴 录音中  $_duration', listening: true,
        trailing: _closeBtn(() { _recorder.stop().catchError((_) {}); _timer?.cancel(); widget.onDone(); }),
        action: GestureDetector(
          onTap: _finish,
          child: Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(color: AppTheme.orbCore, borderRadius: BorderRadius.circular(10)),
            child: const Text('完成', style: TextStyle(color: Colors.black, fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ),
      );
    }

    if (_transcribing) {
      return _buildBox(
        icon: Icons.hourglass_top, iconColor: AppTheme.orbGlow,
        text: '识别中...',
        trailing: _closeBtn(widget.onDone),
        action: const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (_transcript.isNotEmpty) {
      return _buildBox(
        icon: Icons.check_circle, iconColor: const Color(0xFF66BB6A),
        text: _transcript,
        trailing: _closeBtn(widget.onDone),
        action: GestureDetector(
          onTap: _save,
          child: Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(color: AppTheme.orbCore, borderRadius: BorderRadius.circular(10)),
            child: const Text('保存', style: TextStyle(color: Colors.black, fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ),
      );
    }

    return _buildBox(
      icon: Icons.mic_off, iconColor: AppTheme.orbTextOnGlass,
      text: '未识别到文字',
      trailing: _closeBtn(widget.onDone),
      action: GestureDetector(
        onTap: _save,
        child: Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(color: AppTheme.orbCore, borderRadius: BorderRadius.circular(10)),
          child: const Text('保存录音', style: TextStyle(color: Colors.black, fontSize: 13, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }

  Widget _closeBtn(VoidCallback onTap) => GestureDetector(onTap: onTap, child: const Icon(Icons.close, color: AppTheme.orbTextOnGlass, size: 16));

  Widget _buildBox({required IconData icon, required Color iconColor, required String text, Widget? trailing, Widget? action, bool listening = false}) {
    return Container(
      margin: const EdgeInsets.all(10), padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppTheme.orbSurfaceGlass, borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 20, offset: const Offset(0, 6))]),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [const Spacer(), if (trailing != null) trailing]),
        const SizedBox(height: 6),
        Row(mainAxisSize: MainAxisSize.min, children: [
          listening ? _PulsingMicIcon(icon: icon, color: iconColor) : Icon(icon, color: iconColor, size: 28),
          const SizedBox(width: 10),
          Flexible(child: Text(text, style: const TextStyle(color: AppTheme.orbTextOnGlass, fontSize: 14), maxLines: 4, overflow: TextOverflow.ellipsis)),
        ]),
        if (action != null) ...[const SizedBox(height: 10), action],
      ]),
    );
  }
}

/// Simple pulsing microphone icon to indicate active listening.
class _PulsingMicIcon extends StatefulWidget {
  const _PulsingMicIcon({required this.icon, required this.color});
  final IconData icon;
  final Color color;
  @override
  State<_PulsingMicIcon> createState() => _PulsingMicIconState();
}

class _PulsingMicIconState extends State<_PulsingMicIcon>
    with SingleTickerProviderStateMixin {
  late final _ctrl = AnimationController(
    vsync: this, duration: const Duration(milliseconds: 800),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) => Transform.scale(
        scale: 1.0 + _ctrl.value * 0.25,
        child: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color.withValues(alpha: 0.15 + _ctrl.value * 0.1),
          ),
          child: Icon(widget.icon, color: widget.color, size: 24),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Screenshot capture (placeholder)
// ---------------------------------------------------------------------------

class ScreenshotCaptureBar extends StatelessWidget {
  const ScreenshotCaptureBar({super.key, required this.onDone});
  final CaptureCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.orbSurfaceGlass,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 20, offset: const Offset(0, 6))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.crop, color: Color(0xFFFFA726), size: 20),
          const SizedBox(width: 10),
          const Text('请使用系统截图手势 📷',
              style: TextStyle(color: AppTheme.orbTextOnGlass, fontSize: 13)),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onDone,
            child: const Icon(Icons.close, color: AppTheme.orbTextOnGlass, size: 18),
          ),
        ],
      ),
    );
  }
}
