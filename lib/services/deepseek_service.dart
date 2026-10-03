import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'ai_settings.dart';

/// DeepSeek 大模型客户端（OpenAI 兼容接口）。
class DeepSeekService {
  DeepSeekService._();
  static final DeepSeekService instance = DeepSeekService._();

  static const _endpoint = 'https://api.deepseek.com/chat/completions';

  /// 非流式对话。`messages` 为完整历史（含 system）。
  Future<String> chat({
    required List<Map<String, String>> messages,
    String? model,
  }) async {
    final key = await AiSettings.instance.apiKey();
    if (key == null || key.isEmpty) {
      throw const DeepSeekException('还没有配置 DeepSeek API Key，请先在设置里填写');
    }
    final m = model ?? await AiSettings.instance.model();

    final resp = await http
        .post(
          Uri.parse(_endpoint),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $key',
          },
          body: jsonEncode({
            'model': m,
            'messages': messages,
            'stream': false,
          }),
        )
        .timeout(const Duration(seconds: 60));

    if (resp.statusCode != 200) {
      throw DeepSeekException(_errorMessage(resp.statusCode));
    }

    final data = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    final choices = data['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) {
      throw const DeepSeekException('模型没有返回内容');
    }
    final message =
        (choices.first as Map<String, dynamic>)['message'] as Map<String, dynamic>?;
    final content = message?['content'] as String?;
    if (content == null || content.trim().isEmpty) {
      throw const DeepSeekException('模型返回为空，请再试一次');
    }
    return content.trim();
  }

  String _errorMessage(int status) {
    switch (status) {
      case 401:
        return 'API Key 无效，请检查设置里的密钥';
      case 429:
        return '请求太频繁了，稍等片刻再试';
      case 400:
        return '请求格式有误，请重试';
      default:
        if (status >= 500) return 'DeepSeek 服务暂时不可用，请稍后再试';
        return '请求失败（$status）';
    }
  }
}

class DeepSeekException implements Exception {
  const DeepSeekException(this.message);
  final String message;

  @override
  String toString() => message;
}
