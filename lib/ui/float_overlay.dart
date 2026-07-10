import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../services/analytics_service.dart';
import '../services/overlay_manager.dart';
import '../theme/app_theme.dart';
import 'capture_bar.dart';
import 'orb_radial_menu.dart';

// ---------------------------------------------------------------------------
// State machine
// ---------------------------------------------------------------------------

enum _OrbState { idle, blooming, menuActive, capture, dismissing }

// ---------------------------------------------------------------------------
// FloatOverlay
// ---------------------------------------------------------------------------

class FloatOverlay extends StatefulWidget {
  const FloatOverlay({super.key});

  @override
  State<FloatOverlay> createState() => _FloatOverlayState();
}

class _FloatOverlayState extends State<FloatOverlay> with TickerProviderStateMixin {
  static const _tag = 'FloatOverlay';

  // --- state ----------------------------------------------------------------
  _OrbState _state = _OrbState.idle;
  int _highlightedSector = -1;
  int _captureMode = -1;

  // --- timers --------------------------------------------------------------
  Timer? _menuTimer;
  Timer? _idleTimer;
  Timer? _captureSafetyTimer; // auto-dismiss capture if stuck

  // --- animation controllers -----------------------------------------------
  late final AnimationController _bloomCtrl;
  late final AnimationController _idleFadeCtrl;
  late final AnimationController _glowPulseCtrl;

  // --- orb position --------------------------------------------------------
  Offset _orbCenter = Offset.zero;

  // --- idle fade -----------------------------------------------------------
  bool _idleFading = false;

  // --- flag: menu was opened via quick tap (not hold) ----------------------
  bool _tapMenu = false;

  @override
  void initState() {
    super.initState();

    _bloomCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..addListener(() => setState(() {}))
      ..addStatusListener(_onBloomStatus);

    _idleFadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..addListener(() => setState(() {}));

    _glowPulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) => _updateOrbCenter());
    _resetIdleTimer();
  }

  @override
  void dispose() {
    _menuTimer?.cancel();
    _idleTimer?.cancel();
    _captureSafetyTimer?.cancel();
    _bloomCtrl.dispose();
    _idleFadeCtrl.dispose();
    _glowPulseCtrl.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Position
  // ---------------------------------------------------------------------------

  void _updateOrbCenter() {
    final size = MediaQuery.of(context).size;
    if (size.width > 0 && size.height > 0) {
      _orbCenter = Offset(size.width / 2, size.height / 2);
    }
  }

  // ---------------------------------------------------------------------------
  // Idle fade
  // ---------------------------------------------------------------------------

  void _resetIdleTimer() {
    _idleTimer?.cancel();
    if (_idleFading) {
      _idleFadeCtrl.reverse();
      _idleFading = false;
    }
    _idleTimer = Timer(const Duration(seconds: 5), () {
      if (_state == _OrbState.idle && mounted) {
        _idleFading = true;
        _idleFadeCtrl.forward(from: 0);
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Gesture — Flutter gesture arena handles tap vs hold vs drag naturally.
  // Native drag handler (enableDrag=true in idle) takes over when finger moves;
  // Flutter detects this as gesture cancellation and doesn't fire tap/longPress.
  // ---------------------------------------------------------------------------

  void _onTap() {
    if (_state == _OrbState.idle) {
      _tapMenu = true;
      _startBloom();
    } else if (_state == _OrbState.capture) {
      _onCaptureDone(); // tap orb during capture → dismiss
    }
  }

  void _onHoldStart(LongPressStartDetails details) {
    if (_state == _OrbState.idle) {
      _tapMenu = false;
      _startBloom();
    }
  }

  void _onHoldMove(LongPressMoveUpdateDetails details) {
    if (_state != _OrbState.menuActive && _state != _OrbState.blooming) return;
    final sector = OrbRadialMenu.detectSector(
      details.localPosition, _orbCenter,
    );
    if (sector != _highlightedSector) {
      setState(() => _highlightedSector = sector);
      if (_state == _OrbState.menuActive && sector >= 0) _startMenuTimeout();
    }
  }

  void _onHoldEnd(LongPressEndDetails details) {
    if (_state == _OrbState.blooming) {
      _tapMenu = true; // hold released during bloom → keep menu open after
      return;
    }
    if (_state == _OrbState.menuActive) {
      if (_highlightedSector >= 0) {
        _captureMode = _highlightedSector;
        _activateCapture();
      } else if (!_tapMenu) {
        _dismiss();
      }
      _tapMenu = false;
    }
  }

  void _onTapOnIcon(int sector) {
    if (_state != _OrbState.menuActive) return;
    _captureMode = sector;
    _highlightedSector = sector;
    _activateCapture();
  }

  // ---------------------------------------------------------------------------
  // State transitions
  // ---------------------------------------------------------------------------

  void _startBloom() {
    _state = _OrbState.blooming;
    _highlightedSector = -1;
    _captureMode = -1;
    _menuTimer?.cancel();
    _bloomCtrl.forward(from: 0);
    _resetIdleTimer();

    // Disable native drag so Flutter handles gesture
    OverlayManager.setOrbMenuSize().catchError((e) {
      AnalyticsService.instance.warning(_tag, 'setOrbMenuSize failed',
          properties: {'error': e.toString()});
    });
  }

  void _onBloomStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      if (_state == _OrbState.blooming) {
        if (_captureMode >= 0) {
          _activateCapture();
        } else {
          setState(() => _state = _OrbState.menuActive);
          _startMenuTimeout();
        }
      } else if (_state == _OrbState.dismissing) {
        _finishDismiss();
      }
    } else if (status == AnimationStatus.dismissed) {
      // Reverse bloom completed — finish dismiss
      if (_state == _OrbState.dismissing) {
        _finishDismiss();
      }
    }
  }

  void _startMenuTimeout() {
    _menuTimer?.cancel();
    _menuTimer = Timer(const Duration(seconds: 3), () {
      if (_state == _OrbState.menuActive && mounted) {
        _dismiss();
      }
    });
  }

  void _activateCapture() {
    if (_captureMode < 0) return;
    setState(() => _state = _OrbState.capture);
    _menuTimer?.cancel();

    // Safety: auto-dismiss after 30s if user gets stuck
    _captureSafetyTimer?.cancel();
    _captureSafetyTimer = Timer(const Duration(seconds: 30), () {
      if (_state == _OrbState.capture && mounted) {
        AnalyticsService.instance.warning(_tag, 'Capture safety timeout triggered');
        _dismiss();
      }
    });

    if (_captureMode == 0) {
      OverlayManager.setOrbVoiceMode().catchError((e) {
        AnalyticsService.instance.warning(_tag, 'setOrbVoiceMode failed',
            properties: {'error': e.toString()});
      });
    } else {
      OverlayManager.setOrbCaptureMode().catchError((e) {
        AnalyticsService.instance.warning(_tag, 'setOrbCaptureMode failed',
            properties: {'error': e.toString()});
      });
    }
  }

  void _dismiss() {
    if (_state == _OrbState.dismissing || _state == _OrbState.idle) return;
    _state = _OrbState.dismissing;
    _highlightedSector = -1;
    _captureMode = -1;
    _tapMenu = false;
    _menuTimer?.cancel();
    _captureSafetyTimer?.cancel();

    if (_bloomCtrl.value > 0) {
      _bloomCtrl.reverse(from: _bloomCtrl.value);
    } else {
      _finishDismiss();
    }
  }

  Future<void> _finishDismiss() async {
    setState(() {
      _state = _OrbState.idle;
      _highlightedSector = -1;
      _captureMode = -1;
      _tapMenu = false;
    });
    _resetIdleTimer();
    try {
      await OverlayManager.setOrbIdle();
    } catch (e) {
      AnalyticsService.instance.warning(_tag, 'setOrbIdle failed',
          properties: {'error': e.toString()});
    }
  }

  void _onCaptureDone() {
    AnalyticsService.instance.trackEvent('capture_done',
        properties: {'mode': _captureMode});
    _dismiss();
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    _updateOrbCenter();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.overlay(),
      home: Material(
        color: Colors.transparent,
        child: RawGestureDetector(
          behavior: HitTestBehavior.translucent,
          gestures: {
            TapGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
              () => TapGestureRecognizer(),
              (t) => t.onTap = _onTap,
            ),
            LongPressGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<
                    LongPressGestureRecognizer>(
              () => LongPressGestureRecognizer(
                  duration: const Duration(milliseconds: 150)),
              (l) {
                l.onLongPressStart = _onHoldStart;
                l.onLongPressMoveUpdate = _onHoldMove;
                l.onLongPressEnd = _onHoldEnd;
              },
            ),
          },
          child: Stack(
            children: [
              // --- Orb --- (visible in all states; in capture it's small + dismissible)
              _buildOrb(),

              // --- Radial menu ---
              if (_state == _OrbState.blooming || _state == _OrbState.menuActive)
                OrbRadialMenu(
                  bloomProgress: _bloomCtrl.value,
                  highlightedSector: _highlightedSector,
                  orbCenter: _orbCenter,
                  onTapIcon: _onTapOnIcon,
                ),

              // --- Capture bar ---
              if (_state == _OrbState.capture) _buildCaptureBar(),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Orb visual
  // ---------------------------------------------------------------------------

  Widget _buildOrb() {
    final idleAlpha = _idleFading ? (0.5 - 0.42 * _idleFadeCtrl.value) : 0.5;
    final bloomGlow = _bloomCtrl.value;
    final glowAlpha = (idleAlpha + bloomGlow * 0.5).clamp(0.0, 1.0);
    final pulse = _glowPulseCtrl.value;
    final orbSize = 16.0 + bloomGlow * 4.0;
    final glowRadius = 10.0 + bloomGlow * 14.0 + pulse * 3.0;

    return Positioned(
      left: _orbCenter.dx - orbSize / 2,
      top: _orbCenter.dy - orbSize / 2,
      child: Container(
        width: orbSize,
        height: orbSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF0C060), Color(0xFFE8A838)],
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.orbGlow.withValues(alpha: glowAlpha),
              blurRadius: glowRadius,
              spreadRadius: glowRadius * 0.3,
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Capture bar
  // ---------------------------------------------------------------------------

  Widget _buildCaptureBar() {
    Widget bar;
    switch (_captureMode) {
      case 1:
        bar = TextCaptureBar(
            onDone: _onCaptureDone, onCancel: _onCaptureDone);
        break;
      case 2:
        bar = ClipboardCaptureBar(onDone: _onCaptureDone);
        break;
      case 0:
        bar = VoiceCaptureBar(
            onDone: _onCaptureDone, onCancel: _onCaptureDone);
        break;
      case 3:
        bar = ScreenshotCaptureBar(onDone: _onCaptureDone);
        break;
      default:
        return const SizedBox.shrink();
    }

    return Center(child: bar);
  }
}
