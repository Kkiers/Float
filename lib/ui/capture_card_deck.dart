import 'package:flutter/material.dart';

import '../models/capture_item.dart';
import '../theme/app_theme.dart';

/// 想法卡片的「牌堆」滑动容器。
///
/// 顶层卡片可左右拖拽（跟手平移 + 轻微旋转），背后叠放上一张/下一张形成牌堆；
/// 松手超过阈值则飞出一张并前进/后退一格，否则回弹。底部操作条由外层固定，不随卡片滑。
class CaptureCardDeck extends StatefulWidget {
  const CaptureCardDeck({
    super.key,
    required this.items,
    required this.index,
    required this.onIndexChanged,
    required this.cardBuilder,
  });

  final List<CaptureItem> items;
  final int index;
  final ValueChanged<int> onIndexChanged;
  final Widget Function(CaptureItem item) cardBuilder;

  @override
  State<CaptureCardDeck> createState() => _CaptureCardDeckState();
}

class _CaptureCardDeckState extends State<CaptureCardDeck>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late int _index;
  double _dragX = 0;

  // 松手后的 settle 动画（回弹或飞出）。
  Animation<double>? _settleAnim;
  int _dismissDir = 0; // -1 左（下一张）/ +1 右（上一张）

  double get _threshold => MediaQuery.of(context).size.width * 0.26;

  @override
  void initState() {
    super.initState();
    _index = widget.index;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    )..addListener(() {
        if (_settleAnim != null) {
          setState(() => _dragX = _settleAnim!.value);
        }
      });
  }

  @override
  void didUpdateWidget(covariant CaptureCardDeck old) {
    super.didUpdateWidget(old);
    // 父级主动改 index 时同步（本组件自己飞出改的不在此列）。
    if (widget.index != old.index && widget.index != _index) {
      _index = widget.index;
      _dragX = 0;
      _dismissDir = 0;
      _settleAnim = null;
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDragStart(DragStartDetails d) {
    _controller.stop();
    _settleAnim = null;
  }

  void _onDragUpdate(DragUpdateDetails d) {
    setState(() => _dragX += d.delta.dx);
  }

  void _onDragEnd(DragEndDetails d) {
    final w = MediaQuery.of(context).size.width;
    final v = d.velocity.pixelsPerSecond.dx;
    final goLeft = _dragX < -_threshold || v < -900;
    final goRight = _dragX > _threshold || v > 900;

    if (goLeft && _index < widget.items.length - 1) {
      _startDismiss(-1, w);
    } else if (goRight && _index > 0) {
      _startDismiss(1, w);
    } else {
      _springBack();
    }
  }

  void _springBack() {
    _dismissDir = 0;
    _settleAnim = Tween<double>(begin: _dragX, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _controller.forward(from: 0);
  }

  void _startDismiss(int dir, double w) {
    _dismissDir = dir;
    _settleAnim = Tween<double>(begin: _dragX, end: dir * w * 1.3).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward(from: 0).whenComplete(_commitDismiss);
  }

  void _commitDismiss() {
    if (!mounted) return;
    final next = _index + _dismissDir;
    if (next < 0 || next >= widget.items.length) {
      _springBack();
      return;
    }
    setState(() {
      _index = next;
      _dragX = 0;
      _settleAnim = null;
    });
    _controller.value = 0;
    widget.onIndexChanged(_index);
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final progress = (_dragX.abs() / _threshold).clamp(0.0, 1.0).toDouble();
    // 1 = 向下一张方向（左滑露 index+1），-1 = 向上一张方向（右滑露 index-1）。
    final dir = _dragX <= 0 ? 1 : -1;
    final nearIndex = _index + dir;
    final farIndex = _index + 2 * dir;
    final nearOffset = 10.0 * (1 - progress);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: _onDragStart,
        onHorizontalDragUpdate: _onDragUpdate,
        onHorizontalDragEnd: _onDragEnd,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            if (farIndex >= 0 && farIndex < widget.items.length)
              _behindCard(offsetY: 20),
            if (nearIndex >= 0 && nearIndex < widget.items.length)
              _behindCard(offsetY: nearOffset),
            Positioned.fill(
              child: Transform.translate(
                offset: Offset(_dragX, 0),
                child: Transform.rotate(
                  angle: (_dragX / w) * 0.18,
                  child: _cardShell(widget.items[_index]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 顶层卡片外壳：白底圆角 + 暖色光晕。
  Widget _cardShell(CaptureItem item) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE7E4DE)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.orbGlow.withValues(alpha: 0.35),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: widget.cardBuilder(item),
      ),
    );
  }

  /// 背后的占位牌：只露出底部一条，形成「多张叠加」的层次。
  Widget _behindCard({required double offsetY}) {
    return Positioned.fill(
      child: Transform.translate(
        offset: Offset(0, offsetY),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF0EEE8),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE7E4DE)),
          ),
        ),
      ),
    );
  }
}
