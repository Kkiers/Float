import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/capture_item.dart';
import '../theme/app_theme.dart';

/// 卡片类型：由 sourceHint 派生，决定卡片的配色与角标。
enum CaptureType { text, voice, clipboard, insight }

CaptureType captureTypeOf(CaptureItem item) {
  switch (item.sourceHint) {
    case 'voice':
      return CaptureType.voice;
    case 'clipboard':
      return CaptureType.clipboard;
    case 'chat':
      return CaptureType.insight;
    default:
      return CaptureType.text;
  }
}

/// 每种类型的视觉样式（Apple / ColorOS 低饱和基调）。
class CaptureTypeStyle {
  const CaptureTypeStyle(this.bg, this.accent, this.icon, this.label);

  final Color bg;
  final Color accent;
  final IconData icon;
  final String label;
}

CaptureTypeStyle styleOf(CaptureType t) => switch (t) {
      CaptureType.text => const CaptureTypeStyle(
          Color(0xFFFFF7E6), AppTheme.orbCore, Icons.notes, '文字'),
      CaptureType.voice => const CaptureTypeStyle(
          Color(0xFFEAF1FF), AppTheme.cycleAccent, Icons.mic, '语音'),
      CaptureType.clipboard => const CaptureTypeStyle(
          Color(0xFFF1F0ED), Color(0xFF8E8A82), Icons.content_paste, '剪贴板'),
      CaptureType.insight => const CaptureTypeStyle(
          Color(0xFFEAF6EF), Color(0xFF2F9E6E), Icons.lightbulb_outline, '洞见'),
    };

/// 相对时间：刚刚 / N 分钟前 / N 小时前 / 昨天 / M月d日 / yyyy年M月d日。
String relativeTime(DateTime t, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final today = DateTime(n.year, n.month, n.day);
  final day = DateTime(t.year, t.month, t.day);
  final diffDays = today.difference(day).inDays;

  if (diffDays <= 0) {
    final mins = n.difference(t).inMinutes;
    if (mins < 1) return '刚刚';
    if (mins < 60) return '$mins 分钟前';
    final hours = n.difference(t).inHours;
    if (hours < 24) return '$hours 小时前';
    return DateFormat('HH:mm').format(t);
  }
  if (diffDays == 1) return '昨天';
  if (t.year == n.year) return DateFormat('M月d日').format(t);
  return DateFormat('yyyy年M月d日').format(t);
}

/// 完整时间：详情页使用。
String captureFullTime(DateTime t) => DateFormat('yyyy年M月d日 HH:mm').format(t);

/// 通用捕获卡片：按类型配色，内容最多 maxLines 行，右下角相对时间。
class CaptureCard extends StatelessWidget {
  const CaptureCard({
    super.key,
    required this.item,
    this.maxLines = 3,
    this.onTap,
    this.onLongPress,
    this.selected = false,
  });

  final CaptureItem item;
  final int maxLines;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final type = captureTypeOf(item);
    final style = styleOf(type);

    return Material(
      color: style.bg,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? AppTheme.cycleAccent
                  : Colors.black.withValues(alpha: 0.05),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Stack(
            children: [
              Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (type != CaptureType.text) ...[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(style.icon, size: 13, color: style.accent),
                    const SizedBox(width: 5),
                    Text(
                      style.label,
                      style: TextStyle(
                        fontSize: 11,
                        color: style.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              Text(
                item.content,
                maxLines: maxLines,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: AppTheme.cycleTextNavy,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Spacer(),
                  Text(
                    relativeTime(item.capturedAt),
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.black.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (selected)
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.cycleAccent,
                ),
                child: const Icon(Icons.check, size: 14, color: Colors.white),
              ),
            ),
        ],
      ),
      ),
      ),
    );
  }
}
