import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'app_section.dart';

/// 左侧抽屉：头部 + 模块列表（Float / 月经周期）。
class AppDrawer extends StatelessWidget {
  const AppDrawer({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  final AppSection selected;
  final ValueChanged<AppSection> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Float',
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '灵感捕获 · 周期记录',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.outline),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            for (final section in AppSection.values)
              ListTile(
                leading: Icon(
                  section.icon,
                  color: section == selected
                      ? AppTheme.cycleAccent
                      : theme.colorScheme.outline,
                ),
                title: Text(
                  section.label,
                  style: TextStyle(
                    fontWeight:
                        section == selected ? FontWeight.w600 : FontWeight.w400,
                    color: section == selected ? AppTheme.cycleAccent : null,
                  ),
                ),
                selected: section == selected,
                onTap: () {
                  Navigator.of(context).pop();
                  onSelect(section);
                },
              ),
          ],
        ),
      ),
    );
  }
}
