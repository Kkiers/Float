import 'package:flutter/material.dart';

/// App 的顶层模块，用于侧边栏切换与 `IndexedStack` 索引。
enum AppSection { float, cycle }

extension AppSectionX on AppSection {
  String get label => switch (this) {
        AppSection.float => 'Float',
        AppSection.cycle => '月经周期',
      };

  IconData get icon => switch (this) {
        AppSection.float => Icons.bubble_chart_outlined,
        AppSection.cycle => Icons.auto_graph_outlined,
      };
}
