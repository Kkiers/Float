import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/ai_settings.dart';
import '../theme/app_theme.dart';

/// AI 设置页：配置 DeepSeek API Key + 模型。
class AiSettingsPage extends StatefulWidget {
  const AiSettingsPage({super.key});

  @override
  State<AiSettingsPage> createState() => _AiSettingsPageState();
}

class _AiSettingsPageState extends State<AiSettingsPage> {
  final TextEditingController _keyCtrl = TextEditingController();
  bool _obscure = true;
  String _model = 'deepseek-chat';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _keyCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final key = await AiSettings.instance.apiKey();
    final model = await AiSettings.instance.model();
    if (mounted) {
      setState(() {
        _keyCtrl.text = key ?? '';
        _model = model;
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    await AiSettings.instance.setApiKey(_keyCtrl.text);
    await AiSettings.instance.setModel(_model);
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _copyUrl() async {
    await Clipboard.setData(
      const ClipboardData(text: 'https://platform.deepseek.com'),
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已复制申请网址'), duration: Duration(seconds: 1)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('AI 设置'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _sectionTitle('DeepSeek API Key'),
                TextField(
                  controller: _keyCtrl,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    hintText: '粘贴你的 API Key（sk-…）',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '还没有 Key？到 DeepSeek 开放平台申请',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.outline),
                      ),
                    ),
                    TextButton(onPressed: _copyUrl, child: const Text('复制网址')),
                  ],
                ),
                const SizedBox(height: 20),
                _sectionTitle('模型'),
                _modelTile(
                  value: 'deepseek-chat',
                  title: 'DeepSeek 快模型',
                  subtitle: '响应快，适合日常对话与快速拓展',
                ),
                _modelTile(
                  value: 'deepseek-reasoner',
                  title: 'DeepSeek 深度推理',
                  subtitle: '推理更强、更慢，适合复杂问题',
                ),
                const SizedBox(height: 28),
                FilledButton(
                  onPressed: _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.cycleAccent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('保存'),
                ),
              ],
            ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppTheme.cycleTextNavy,
        ),
      ),
    );
  }

  Widget _modelTile({
    required String value,
    required String title,
    required String subtitle,
  }) {
    final selected = _model == value;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => setState(() => _model = value),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? AppTheme.cycleAccent
                  : Theme.of(context).colorScheme.outlineVariant,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                size: 20,
                color: selected
                    ? AppTheme.cycleAccent
                    : Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.outline)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
