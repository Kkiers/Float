/// 日志级别
enum LogLevel {
  debug('DEBUG'),
  info('INFO'),
  warning('WARN'),
  error('ERROR');

  final String label;
  const LogLevel(this.label);
}

/// 单条日志记录
class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final String tag;
  final String message;
  final Map<String, dynamic>? properties;

  LogEntry({
    required this.timestamp,
    required this.level,
    required this.tag,
    required this.message,
    this.properties,
  });
}

/// 埋点 & 日志服务
///
/// 职责：
/// 1. 输出带时间戳的结构化日志到控制台（debugPrint）
/// 2. 在内存中保留最近 [maxEntries] 条记录供实时查看
/// 3. 提供事件埋点接口（trackEvent）便于后续对接友盟/GrowingIO 等
///
/// 使用方式：
///   AnalyticsService.instance.trackEvent('capture_saved', properties: {...});
///   AnalyticsService.instance.log(LogLevel.info, 'CapturePanel', '面板已打开');
class AnalyticsService {
  AnalyticsService._();
  static final AnalyticsService instance = AnalyticsService._();

  /// 内存保留的最大日志条数
  static const int maxEntries = 500;

  final List<LogEntry> _logs = [];

  /// 是否输出到控制台（默认 true）
  bool consoleEnabled = true;

  /// 是否记录 debug 级别（默认 false，生产环境建议关闭）
  bool debugEnabled = false;

  // ---------------------------------------------------------------------------
  // 公开接口
  // ---------------------------------------------------------------------------

  /// 记录一条日志
  void log(
    LogLevel level,
    String tag,
    String message, {
    Map<String, dynamic>? properties,
  }) {
    if (level == LogLevel.debug && !debugEnabled) return;

    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: level,
      tag: tag,
      message: message,
      properties: properties,
    );

    _logs.add(entry);
    if (_logs.length > maxEntries) {
      _logs.removeAt(0);
    }

    if (consoleEnabled) {
      _printToConsole(entry);
    }
  }

  /// 快捷方法：记录一条事件埋点
  ///
  /// [eventName] 事件名，建议用 `模块_动作` 格式，如 `capture_saved`、`overlay_opened`
  /// [properties] 附加属性
  void trackEvent(
    String eventName, {
    Map<String, dynamic>? properties,
  }) {
    log(LogLevel.info, 'Event', eventName, properties: properties);
  }

  /// 快捷方法：debug 日志（仅在 debugEnabled=true 时输出）
  void debug(String tag, String message, {Map<String, dynamic>? properties}) {
    log(LogLevel.debug, tag, message, properties: properties);
  }

  /// 快捷方法：info 日志
  void info(String tag, String message, {Map<String, dynamic>? properties}) {
    log(LogLevel.info, tag, message, properties: properties);
  }

  /// 快捷方法：warning 日志
  void warning(String tag, String message, {Map<String, dynamic>? properties}) {
    log(LogLevel.warning, tag, message, properties: properties);
  }

  /// 快捷方法：error 日志
  void error(String tag, String message, {Map<String, dynamic>? properties}) {
    log(LogLevel.error, tag, message, properties: properties);
  }

  // ---------------------------------------------------------------------------
  // 日志查看
  // ---------------------------------------------------------------------------

  /// 获取所有缓存的日志（最新的在末尾）
  List<LogEntry> get allLogs => List.unmodifiable(_logs);

  /// 按级别过滤日志
  List<LogEntry> getLogsByLevel(LogLevel level) =>
      _logs.where((e) => e.level == level).toList();

  /// 按标签过滤日志
  List<LogEntry> getLogsByTag(String tag) =>
      _logs.where((e) => e.tag == tag).toList();

  /// 清空缓存
  void clear() => _logs.clear();

  /// 导出日志为文本（用于调试 / 分享）
  String export() {
    return _logs.map((e) {
      final ts = e.timestamp.toString().substring(0, 19);
      final props = e.properties != null && e.properties!.isNotEmpty
          ? '  ${e.properties}'
          : '';
      return '[${e.level.label}] $ts ${e.tag}: ${e.message}$props';
    }).join('\n');
  }

  // ---------------------------------------------------------------------------
  // 内部
  // ---------------------------------------------------------------------------

  void _printToConsole(LogEntry entry) {
    // ignore: avoid_print
    print(
      '[${entry.level.label}] ${entry.timestamp.toString().substring(0, 19)} '
      '${entry.tag}: ${entry.message}'
      '${entry.properties != null && entry.properties!.isNotEmpty ? ' ${entry.properties}' : ''}',
    );
  }
}
