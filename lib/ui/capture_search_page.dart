import 'dart:async';

import 'package:flutter/material.dart';

import '../models/capture_item.dart';
import '../services/capture_storage.dart';
import 'capture_card.dart';
import 'capture_detail_page.dart';

/// 搜索页：顶部自动聚焦，输入即搜索，单列结果。
class CaptureSearchPage extends StatefulWidget {
  const CaptureSearchPage({super.key});

  @override
  State<CaptureSearchPage> createState() => _CaptureSearchPageState();
}

class _CaptureSearchPageState extends State<CaptureSearchPage> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  List<CaptureItem> _results = const [];
  bool _searching = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    final query = q.trim();
    if (query.isEmpty) {
      setState(() {
        _results = const [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 200), () async {
      final r = await CaptureStorage.instance.search(query);
      if (mounted) {
        setState(() {
          _results = r;
          _searching = false;
        });
      }
    });
  }

  void _openDetail(int index) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CaptureDetailPage(items: _results, initialIndex: index),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget body;
    if (_searching) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_results.isEmpty) {
      body = Center(
        child: Text(
          _controller.text.trim().isEmpty ? '输入关键词搜索' : '没有匹配的结果',
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.outline),
        ),
      );
    } else {
      body = ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          for (var i = 0; i < _results.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: CaptureCard(
                item: _results[i],
                onTap: () => _openDetail(i),
              ),
            ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: TextField(
          controller: _controller,
          autofocus: true,
          onChanged: _onChanged,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: '搜想法、语音、剪贴板…',
            border: InputBorder.none,
            hintStyle: TextStyle(color: theme.colorScheme.outline),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: '关闭',
          ),
        ],
      ),
      body: body,
    );
  }
}
