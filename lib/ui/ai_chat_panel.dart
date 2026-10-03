import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../models/capture_item.dart';
import '../models/chat_session.dart';
import '../models/thinker_persona.dart';
import '../services/ai_settings.dart';
import '../services/capture_storage.dart';
import '../services/chat_storage.dart';
import '../services/deepseek_service.dart';
import '../theme/app_theme.dart';
import 'ai_settings_page.dart';

class _ChatMessage {
  const _ChatMessage({required this.role, required this.text});
  final String role; // 'user' | 'assistant'
  final String text;
}

/// 卡片流式追问面板：顶部一条背景卡片 + 交替的「模型 / 你」卡片 + 底部输入框。
/// [captureId] 非空时把对话持久化到 ChatStorage；[session] 用于恢复历史会话。
class AiChatPanel extends StatefulWidget {
  const AiChatPanel({
    super.key,
    required this.persona,
    required this.contextLabel,
    required this.initialContext,
    this.captureId,
    this.session,
  });

  final ThinkerPersona persona;
  final String contextLabel;
  final String initialContext;
  final int? captureId;
  final ChatSession? session;

  @override
  State<AiChatPanel> createState() => _AiChatPanelState();
}

class _AiChatPanelState extends State<AiChatPanel> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final List<_ChatMessage> _messages = [];
  int? _sessionId;
  bool _sending = false;
  bool _hasKey = false;
  String? _error;
  String _selectedText = '';

  @override
  void initState() {
    super.initState();
    _sessionId = widget.session?.id;
    for (final m in widget.session?.messages ?? const <ChatMessage>[]) {
      _messages.add(_ChatMessage(role: m.role, text: m.content));
    }
    _checkKey();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkKey() async {
    final has = await AiSettings.instance.hasKey();
    if (mounted) setState(() => _hasKey = has);
  }

  Future<void> _goSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AiSettingsPage()),
    );
    await _checkKey();
  }

  String _buildSystemPrompt() {
    return '${widget.persona.systemPrompt}\n\n'
        '下面是用户捕捉到的一段想法，请把它当作讨论背景，围绕它展开：\n'
        '"""${widget.initialContext}"""\n\n'
        '先给出你对这段想法的延展与洞察，再自然地和用户继续对话。'
        '用中文、口语化、有洞察地回答。';
  }

  Future<void> _persist(String role, String content) async {
    final captureId = widget.captureId;
    if (captureId == null) return;
    _sessionId ??= await ChatStorage.instance.createSession(captureId, widget.persona.id);
    await ChatStorage.instance.addMessage(_sessionId!, role, content);
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _controller.text).trim();
    if (text.isEmpty || _sending) return;
    if (!_hasKey) {
      _goSettings();
      return;
    }

    setState(() {
      _messages.add(_ChatMessage(role: 'user', text: text));
      _error = null;
      _sending = true;
    });
    _controller.clear();
    _scrollToBottom();
    await _persist('user', text);

    final apiMessages = <Map<String, String>>[
      {'role': 'system', 'content': _buildSystemPrompt()},
      for (final m in _messages) {'role': m.role, 'content': m.text},
    ];

    try {
      final reply = await DeepSeekService.instance.chat(messages: apiMessages);
      if (mounted) {
        setState(() {
          _messages.add(_ChatMessage(role: 'assistant', text: reply));
          _sending = false;
        });
      }
      await _persist('assistant', reply);
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _sending = false;
        });
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
      }
    });
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _saveSelection(String text) async {
    final t = text.trim();
    if (t.isEmpty) return;
    await CaptureStorage.instance.insert(CaptureItem(
      content: t,
      sourceHint: 'chat',
      capturedAt: DateTime.now(),
    ));
    if (mounted) _showSnack('已存为新想法');
  }

  Future<void> _appendSelection(String text) async {
    final captureId = widget.captureId;
    if (captureId == null) return;
    final t = text.trim();
    if (t.isEmpty) return;
    await CaptureStorage.instance.appendBlock(captureId, t);
    if (mounted) _showSnack('已追加到原想法');
  }

  Future<void> _copySelection(String text) async {
    final t = text.trim();
    if (t.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: t));
    if (mounted) _showSnack('已复制');
  }

  /// 选中文字后的菜单：复制 / 存为新想法 / 追加到原想法。
  Widget _buildContextMenu(BuildContext context, SelectableRegionState state) {
    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: state.contextMenuAnchors,
      buttonItems: [
        ContextMenuButtonItem(
          label: '复制',
          onPressed: () {
            ContextMenuController.removeAny();
            _copySelection(_selectedText);
          },
        ),
        ContextMenuButtonItem(
          label: '存为新想法',
          onPressed: () {
            ContextMenuController.removeAny();
            _saveSelection(_selectedText);
          },
        ),
        if (widget.captureId != null)
          ContextMenuButtonItem(
            label: '追加到原想法',
            onPressed: () {
              ContextMenuController.removeAny();
              _appendSelection(_selectedText);
            },
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Expanded(
          child: SelectionArea(
            onSelectionChanged: (content) => _selectedText = content?.plainText ?? '',
            contextMenuBuilder: _buildContextMenu,
            child: ListView(
              controller: _scrollCtrl,
              padding: const EdgeInsets.all(14),
              children: [
                _contextCard(theme),
                if (_messages.isEmpty) _hintCard(theme),
                for (var i = 0; i < _messages.length; i++)
                  _messageCard(_messages[i], theme),
                if (_sending) const _LoadingCard(),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
        if (_error != null) _errorBar(theme),
        _inputBar(theme),
      ],
    );
  }

  Widget _contextCard(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.orbCore.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.push_pin_outlined, size: 14, color: AppTheme.orbCore),
              const SizedBox(width: 5),
              Text(
                widget.contextLabel,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.orbCore,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            widget.initialContext,
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
              color: AppTheme.cycleTextNavy,
            ),
          ),
        ],
      ),
    );
  }

  Widget _hintCard(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '用「${widget.persona.name}」拓展这条想法',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.cycleTextNavy,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '也可以直接输入你的问题',
            style: TextStyle(fontSize: 12, color: theme.colorScheme.outline),
          ),
          const SizedBox(height: 10),
          if (_hasKey)
            FilledButton.icon(
              onPressed: () => _send('请用你的思维模型，帮我扩展、深化上面这段想法，并给出你的洞察。'),
              style: FilledButton.styleFrom(backgroundColor: AppTheme.cycleAccent),
              icon: const Icon(Icons.lightbulb_outline, size: 16),
              label: const Text('帮我拓展'),
            )
          else
            FilledButton(
              onPressed: _goSettings,
              style: FilledButton.styleFrom(backgroundColor: AppTheme.cycleAccent),
              child: const Text('去配置 Key'),
            ),
        ],
      ),
    );
  }

  Widget _messageCard(_ChatMessage m, ThemeData theme) {
    final isUser = m.role == 'user';
    final labelColor = isUser ? AppTheme.cycleAccent : AppTheme.orbCore;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isUser ? const Color(0xFFF2F4FF) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUser
              ? AppTheme.cycleAccent.withValues(alpha: 0.22)
              : theme.colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isUser ? Icons.person_outline : widget.persona.icon,
                size: 13,
                color: labelColor,
              ),
              const SizedBox(width: 5),
              Text(
                isUser ? '你' : widget.persona.name,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: labelColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (isUser)
            Text(
              m.text,
              style: const TextStyle(
                fontSize: 14,
                height: 1.55,
                color: AppTheme.cycleTextNavy,
              ),
            )
          else
            MarkdownBody(
              data: m.text,
              selectable: false,
              softLineBreak: true,
              styleSheet: _mdStyle(theme),
            ),
        ],
      ),
    );
  }

  MarkdownStyleSheet _mdStyle(ThemeData theme) {
    final base = MarkdownStyleSheet.fromTheme(theme);
    return base.copyWith(
      p: const TextStyle(fontSize: 14, height: 1.55, color: AppTheme.cycleTextNavy),
      a: const TextStyle(
        color: AppTheme.cycleAccent,
        decoration: TextDecoration.underline,
      ),
      code: const TextStyle(
        fontSize: 13,
        fontFamily: 'monospace',
        color: Color(0xFF4A4458),
        backgroundColor: Color(0xFFF1EFF5),
      ),
      codeblockDecoration: BoxDecoration(
        color: const Color(0xFFF6F5F1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE7E4DE)),
      ),
      blockquote: const TextStyle(
        fontSize: 14,
        height: 1.5,
        color: Color(0xFF6B675F),
      ),
      blockquoteDecoration: BoxDecoration(
        color: const Color(0xFFF6F6F3),
        border: const Border(left: BorderSide(color: AppTheme.cycleAccent, width: 3)),
        borderRadius: BorderRadius.circular(6),
      ),
      h1: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppTheme.cycleTextNavy,
      ),
      h2: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppTheme.cycleTextNavy,
      ),
      h3: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: AppTheme.cycleTextNavy,
      ),
      listBullet: const TextStyle(fontSize: 14, color: AppTheme.cycleTextNavy),
      tableBorder: TableBorder.all(color: const Color(0xFFE7E4DE), width: 0.5),
      tableHead: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppTheme.cycleTextNavy,
      ),
      tableBody: const TextStyle(fontSize: 13, color: AppTheme.cycleTextNavy),
      tableCellsPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      tableCellsDecoration: const BoxDecoration(color: Colors.white),
    );
  }

  Widget _errorBar(ThemeData theme) {
    return Container(
      width: double.infinity,
      color: theme.colorScheme.errorContainer,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 16, color: theme.colorScheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _error!,
              style: TextStyle(fontSize: 12, color: theme.colorScheme.error),
            ),
          ),
          TextButton(
            onPressed: () => _send(),
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }

  Widget _inputBar(ThemeData theme) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: _hasKey ? '继续追问…' : '先去配置 API Key',
                isDense: true,
                filled: true,
                fillColor: theme.colorScheme.surface,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: _sending ? null : () => _send(),
            style: IconButton.styleFrom(backgroundColor: AppTheme.cycleAccent),
            icon: Icon(
              _sending ? Icons.hourglass_top : Icons.arrow_upward,
              size: 20,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 12),
          Text('正在思考…', style: TextStyle(fontSize: 13, color: Color(0xFF9A968F))),
        ],
      ),
    );
  }
}
