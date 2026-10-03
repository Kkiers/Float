import 'package:flutter/material.dart';

import '../models/thinker_persona.dart';
import '../theme/app_theme.dart';

/// 半屏「选思维模型」面板：列出所有模型（名称 + 出处 + 一句说明），点选返回。
Future<ThinkerPersona?> showModelPicker(BuildContext context) {
  return showModalBottomSheet<ThinkerPersona>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 18, 20, 4),
              child: Text(
                '选一个思维模型',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.cycleTextNavy,
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                '它会用这套思维方式帮你拓展这条想法',
                style: TextStyle(fontSize: 12, color: Color(0xFF9A968F)),
              ),
            ),
            for (final p in ThinkerPersonas.all) _personaTile(ctx, p),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ),
  );
}

Widget _personaTile(BuildContext ctx, ThinkerPersona p) {
  return InkWell(
    onTap: () => Navigator.of(ctx).pop(p),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.cycleAccent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(p.icon, size: 22, color: AppTheme.cycleAccent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      p.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.cycleTextNavy,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      p.tagline,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF9A968F)),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  p.blurb,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF6B675F)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right, size: 20, color: Color(0xFFC7C3BC)),
        ],
      ),
    ),
  );
}
