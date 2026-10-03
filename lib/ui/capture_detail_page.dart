import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/capture_append.dart';
import '../models/capture_item.dart';
import '../models/chat_session.dart';
import '../models/thinker_persona.dart';
import '../services/capture_storage.dart';
import '../services/chat_storage.dart';
import '../theme/app_theme.dart';
import 'ai_chat_page.dart';
import 'capture_card.dart';
import 'capture_card_deck.dart';
import 'model_picker_sheet.dart';

/// 详情页：全屏 PageView 左右滑切换；三层分离——看想法（全屏）/ 选模型（半屏）/ 卡片流对话（全屏）。
class CaptureDetailPage extends StatefulWidget {
  const CaptureDetailPage({
    super.key,
    required this.items,
    required this.initialIndex,
  });

  final List<CaptureItem> items;
  final int initialIndex;

  @override
  State<CaptureDetailPage> createState() => _CaptureDetailPageState();
}

class _CaptureDetailPageState extends State<CaptureDetailPage> {
  late int _index;
  late final List<CaptureItem> _items;

  /// 每条想法各自的追问会话缓存（key = capture id）。
  final Map<int, List<ChatSession>> _sessions = {};

  /// 每条想法各自的「追加块」缓存（key = capture id）。
  final Map<int, List<CaptureAppend>> _appends = {};

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _items = List.of(widget.items);
    _ensureSessions(_items[widget.initialIndex]);
    _ensureAppends(_items[widget.initialIndex]);
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _ensureSessions(CaptureItem item) async {
    final id = item.id;
    if (id == null || _sessions.containsKey(id)) return;
    final list = await ChatStorage.instance.getSessions(id);
    if (mounted) setState(() => _sessions[id] = list);
  }

  Future<void> _reloadSessions(CaptureItem item) async {
    final id = item.id;
    if (id == null) return;
    final list = await ChatStorage.instance.getSessions(id);
    if (mounted) setState(() => _sessions[id] = list);
  }

  Future<void> _ensureAppends(CaptureItem item) async {
    final id = item.id;
    if (id == null || _appends.containsKey(id)) return;
    final list = await CaptureStorage.instance.getAppends(id);
    if (mounted) setState(() => _appends[id] = list);
  }

  Future<void> _reloadAppends(CaptureItem item) async {
    final id = item.id;
    if (id == null) return;
    final list = await CaptureStorage.instance.getAppends(id);
    if (mounted) setState(() => _appends[id] = list);
  }

  /// 从数据库重取某条想法的最新正文（「追加到原想法」后刷新显示）。
  Future<void> _refreshItem(CaptureItem item) async {
    final id = item.id;
    if (id == null) return;
    final updated = await CaptureStorage.instance.getById(id);
    if (updated == null || !mounted) return;
    setState(() {
      final i = _items.indexWhere((e) => e.id == id);
      if (i >= 0) _items[i] = updated;
    });
  }

  Future<void> _copy(CaptureItem item) async {
    await Clipboard.setData(ClipboardData(text: item.content));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('已复制到剪贴板'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _edit(CaptureItem item) async {
    final id = item.id;
    if (id == null) return;
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (_) => _EditSheet(initialText: item.content),
    );
    if (result == null || !mounted) return;
    final newText = result.trim();
    if (newText.isEmpty) return;
    await CaptureStorage.instance.updateContent(id, newText);
    await _refreshItem(item);
  }

  Future<void> _delete(CaptureItem item) async {
    final id = item.id;
    if (id == null) return;
    await CaptureStorage.instance.delete(id);
    await ChatStorage.instance.deleteForCapture(id);
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _askAi(CaptureItem item) async {
    final persona = await showModelPicker(context);
    if (persona == null || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AiChatPage(
          persona: persona,
          contextLabel: '你的想法',
          initialContext: item.content,
          captureId: item.id,
        ),
      ),
    );
    await _reloadSessions(item);
    await _reloadAppends(item);
    await _refreshItem(item);
  }

  Future<void> _more(CaptureItem item) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                '更多',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.cycleTextNavy,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('编辑'),
              onTap: () => Navigator.of(ctx).pop('edit'),
            ),
            ListTile(
              leading: const Icon(Icons.copy_outlined),
              title: const Text('复制'),
              onTap: () => Navigator.of(ctx).pop('copy'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Color(0xFFE5484D)),
              title: const Text('删除', style: TextStyle(color: Color(0xFFE5484D))),
              onTap: () => Navigator.of(ctx).pop('delete'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'copy') {
      _copy(item);
    } else if (action == 'edit') {
      _edit(item);
    } else if (action == 'delete') {
      _delete(item);
    }
  }

  Future<void> _showHistory(CaptureItem item, List<ChatSession> sessions) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                '追问历史',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.cycleTextNavy,
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Text(
                '每一次追问都是一圈年轮，点开可继续聊',
                style: TextStyle(fontSize: 12, color: Color(0xFF9A968F)),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final s in sessions)
                    ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppTheme.cycleAccent.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          ThinkerPersonas.byId(s.personaId).icon,
                          size: 20,
                          color: AppTheme.cycleAccent,
                        ),
                      ),
                      title: Text(ThinkerPersonas.byId(s.personaId).name),
                      subtitle: Text('${_sessionDate(s.createdAt)} · ${s.messages.length} 条消息'),
                      trailing: const Icon(Icons.chevron_right, size: 20, color: Color(0xFFC7C3BC)),
                      onTap: () {
                        Navigator.of(ctx).pop();
                        _resumeSession(item, s);
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _resumeSession(CaptureItem item, ChatSession s) async {
    final persona = ThinkerPersonas.byId(s.personaId);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AiChatPage(
          persona: persona,
          contextLabel: '你的想法',
          initialContext: item.content,
          captureId: item.id,
          session: s,
        ),
      ),
    );
    await _reloadSessions(item);
    await _reloadAppends(item);
    await _refreshItem(item);
  }

  @override
  Widget build(BuildContext context) {
    final current = _items[_index];
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F3),
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(
          '${_index + 1} / ${_items.length}',
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: CaptureCardDeck(
              items: _items,
              index: _index,
              onIndexChanged: _onIndexChanged,
              cardBuilder: _cardContent,
            ),
          ),
          if (_sessionsOf(current).isNotEmpty)
            _historySummary(current, _sessionsOf(current)),
          _bottomBar(current),
        ],
      ),
    );
  }

  void _onIndexChanged(int i) {
    if (i == _index) return;
    setState(() => _index = i);
    _ensureSessions(_items[i]);
    _ensureAppends(_items[i]);
  }

  List<ChatSession> _sessionsOf(CaptureItem item) => item.id == null
      ? const <ChatSession>[]
      : _sessions[item.id] ?? const <ChatSession>[];

  List<CaptureAppend> _appendsOf(CaptureItem item) => item.id == null
      ? const <CaptureAppend>[]
      : _appends[item.id] ?? const <CaptureAppend>[];

  /// 卡片内容：类型徽标 + 大字正文 + 时间 + 追加块（整块随卡片滑动）。
  Widget _cardContent(CaptureItem item) {
    final type = captureTypeOf(item);
    final style = styleOf(type);
    final appends = _appendsOf(item);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: style.bg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(style.icon, size: 13, color: style.accent),
                    const SizedBox(width: 5),
                    Text(
                      style.label,
                      style: TextStyle(
                        fontSize: 12,
                        color: style.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _originalCard(item),
          const SizedBox(height: 12),
          Text(
            captureFullTime(item.capturedAt),
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          if (appends.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Row(
              children: [
                Icon(Icons.add_circle_outline, size: 15, color: Color(0xFF9A968F)),
                SizedBox(width: 6),
                Text(
                  '追加记录',
                  style: TextStyle(fontSize: 13, color: Color(0xFF9A968F)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (final a in appends) _appendCard(a),
          ],
        ],
      ),
    );
  }

  Widget _originalCard(CaptureItem item) {
    return Text(
      item.content,
      style: const TextStyle(
        fontSize: 18,
        height: 1.6,
        color: AppTheme.cycleTextNavy,
      ),
    );
  }

  Widget _appendCard(CaptureAppend a) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F7FB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE7E4DE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.add_comment_outlined, size: 13, color: Color(0xFF9A968F)),
              const SizedBox(width: 5),
              Text(
                '追加 · ${relativeTime(a.createdAt)}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF9A968F)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            a.content,
            style: const TextStyle(
              fontSize: 15,
              height: 1.55,
              color: AppTheme.cycleTextNavy,
            ),
          ),
        ],
      ),
    );
  }

  Widget _historySummary(CaptureItem item, List<ChatSession> sessions) {
    final latest = sessions.first;
    final persona = ThinkerPersonas.byId(latest.personaId);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: InkWell(
        onTap: () => _showHistory(item, sessions),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE7E4DE)),
          ),
          child: Row(
            children: [
              const Icon(Icons.psychology_outlined, size: 20, color: AppTheme.cycleAccent),
              const SizedBox(width: 10),
              Text(
                '${sessions.length} 次追问',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.cycleTextNavy,
                ),
              ),
              Expanded(
                child: Text(
                  '${persona.name} · ${_sessionDate(latest.createdAt)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF9A968F)),
                ),
              ),
              const SizedBox(width: 2),
              const Icon(Icons.chevron_right, size: 20, color: Color(0xFFC7C3BC)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bottomBar(CaptureItem item) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: () => _askAi(item),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.cycleAccent,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: const Icon(Icons.auto_awesome, size: 18),
              label: const Text('追问'),
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton(
            onPressed: () => _more(item),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            ),
            child: const Text('更多'),
          ),
        ],
      ),
    );
  }
}

/// 编辑想法的半屏面板：自持 [TextEditingController] 与 [FocusNode]，
/// 关闭时先收起键盘/焦点再退出，避免 TextField 尚未卸载就被提前 dispose。
class _EditSheet extends StatefulWidget {
  const _EditSheet({required this.initialText});

  final String initialText;

  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
  late final TextEditingController _controller;
  late final FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
    _focus = FocusNode();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _save() {
    FocusScope.of(context).unfocus();
    Navigator.of(context).pop(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.7;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Row(
                children: [
                  const Text(
                    '编辑想法',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.cycleTextNavy,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('取消'),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _controller,
                  focusNode: _focus,
                  autofocus: true,
                  minLines: 4,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  decoration: InputDecoration(
                    hintText: '写下你的想法…',
                    filled: true,
                    fillColor: const Color(0xFFF6F6F3),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: FilledButton(
                onPressed: _save,
                style: FilledButton.styleFrom(backgroundColor: AppTheme.cycleAccent),
                child: const Text('保存'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _two(int n) => n.toString().padLeft(2, '0');

String _sessionDate(DateTime d) =>
    '${d.month}月${d.day}日 ${_two(d.hour)}:${_two(d.minute)}';
