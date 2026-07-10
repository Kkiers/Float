import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/analytics_service.dart';

/// 埋点日志查看器 — 调试用
///
/// 摇一摇或在代码中调 [LogViewer.show(context)] 打开。
class LogViewer extends StatefulWidget {
  const LogViewer({super.key});

  static Future<void> show(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LogViewer()),
    );
  }

  @override
  State<LogViewer> createState() => _LogViewerState();
}

class _LogViewerState extends State<LogViewer> {
  final _analytics = AnalyticsService.instance;
  LogLevel? _filterLevel;
  String _searchTag = '';
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  List<LogEntry> get _filteredLogs {
    var logs = _analytics.allLogs.reversed.toList();
    if (_filterLevel != null) {
      logs = logs.where((e) => e.level == _filterLevel).toList();
    }
    if (_searchTag.isNotEmpty) {
      logs = logs
          .where((e) => e.tag.toLowerCase().contains(_searchTag.toLowerCase()))
          .toList();
    }
    return logs;
  }

  Color _colorForLevel(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return Colors.grey;
      case LogLevel.info:
        return Colors.blue;
      case LogLevel.warning:
        return Colors.orange;
      case LogLevel.error:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    final logs = _filteredLogs;

    return Theme(
      data: ThemeData.dark(useMaterial3: true),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('📊 埋点日志'),
          actions: [
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: '清空',
              onPressed: () {
                setState(() {
                  _analytics.clear();
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.share),
              tooltip: '导出',
              onPressed: () {
                ClipboardService.copy(_analytics.export());
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('日志已复制到剪贴板')),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(80),
            child: Column(
              children: [
                // 级别过滤
                SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      _filterChip(null, '全部'),
                      _filterChip(LogLevel.debug, 'DEBUG'),
                      _filterChip(LogLevel.info, 'INFO'),
                      _filterChip(LogLevel.warning, 'WARN'),
                      _filterChip(LogLevel.error, 'ERROR'),
                    ],
                  ),
                ),
                // 标签搜索
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                  child: TextField(
                    style: const TextStyle(fontSize: 13),
                    decoration: const InputDecoration(
                      hintText: '按标签搜索…',
                      hintStyle: TextStyle(color: Colors.grey),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) => setState(() => _searchTag = v),
                  ),
                ),
              ],
            ),
          ),
        ),
        body: logs.isEmpty
            ? const Center(
                child: Text('暂无日志', style: TextStyle(color: Colors.grey)),
              )
            : ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(8),
                itemCount: logs.length,
                itemBuilder: (context, index) {
                  final entry = logs[index];
                  final ts =
                      entry.timestamp.toString().substring(11, 19);
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 1,
                      horizontal: 4,
                    ),
                    child: InkWell(
                      onTap: () => _showDetail(context, entry),
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '[$ts]',
                              style: TextStyle(
                                fontSize: 11,
                                color: _colorForLevel(entry.level),
                                fontFamily: 'monospace',
                              ),
                            ),
                            const TextSpan(text: ' '),
                            TextSpan(
                              text: '[${entry.level.label}]',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: _colorForLevel(entry.level),
                                fontFamily: 'monospace',
                              ),
                            ),
                            const TextSpan(text: ' '),
                            TextSpan(
                              text: '${entry.tag}: ',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.cyan,
                                fontFamily: 'monospace',
                              ),
                            ),
                            TextSpan(
                              text: entry.message,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.white70,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _filterChip(LogLevel? level, String label) {
    final active = _filterLevel == level;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: active,
        onSelected: (_) => setState(() => _filterLevel = level),
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  void _showDetail(BuildContext context, LogEntry entry) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${entry.level.label}: ${entry.tag}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('时间: ${entry.timestamp}'),
              Text('级别: ${entry.level.label}'),
              Text('标签: ${entry.tag}'),
              Text('消息: ${entry.message}'),
              if (entry.properties != null && entry.properties!.isNotEmpty)
                Text('属性: ${entry.properties}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
}

/// 简单的剪贴板操作
class ClipboardService {
  static void copy(String text) {
    try {
      Clipboard.setData(ClipboardData(text: text));
    } catch (_) {
      // 静默失败
    }
  }
}
