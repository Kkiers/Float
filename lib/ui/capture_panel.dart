import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/capture_item.dart';
import '../services/capture_storage.dart';

/// List of captured items used by the main app home page.
class CaptureListPage extends StatefulWidget {
  const CaptureListPage({super.key});

  @override
  State<CaptureListPage> createState() => _CaptureListPageState();
}

class _CaptureListPageState extends State<CaptureListPage> {
  List<CaptureItem> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final items = await CaptureStorage.instance.getAll();
    if (mounted) {
      setState(() {
        _items = items;
        _loading = false;
      });
    }
  }

  Future<void> _delete(CaptureItem item) async {
    if (item.id == null) return;
    await CaptureStorage.instance.delete(item.id!);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFmt = DateFormat('M月d日 HH:mm');

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined,
                size: 48, color: theme.colorScheme.outline),
            const SizedBox(height: 12),
            Text('还没有捕获', style: theme.textTheme.bodyLarge),
            const SizedBox(height: 4),
            Text(
              '开启浮球，灵感来了长按它',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final item = _items[index];
          return Dismissible(
            key: ValueKey(item.id),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.delete_outline,
                  color: theme.colorScheme.onErrorContainer),
            ),
            onDismissed: (_) => _delete(item),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.content,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        height: 1.45,
                      ),
                    ),
                    if (item.reaction != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer
                              .withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          item.reaction!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      dateFmt.format(item.capturedAt),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
