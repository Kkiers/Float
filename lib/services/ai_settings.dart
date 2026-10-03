import 'package:shared_preferences/shared_preferences.dart';

/// AI 相关设置：DeepSeek API Key、模型、遇见节奏。用 shared_preferences 持久化。
class AiSettings {
  AiSettings._();
  static final AiSettings instance = AiSettings._();

  static const _kApiKey = 'ai_api_key';
  static const _kModel = 'ai_model';
  static const _kMeetCadence = 'meet_cadence';

  Future<String?> apiKey() async =>
      (await SharedPreferences.getInstance()).getString(_kApiKey);

  Future<void> setApiKey(String key) async =>
      (await SharedPreferences.getInstance()).setString(_kApiKey, key.trim());

  Future<void> clearApiKey() async =>
      (await SharedPreferences.getInstance()).remove(_kApiKey);

  Future<bool> hasKey() async => (await apiKey())?.isNotEmpty ?? false;

  Future<String> model() async =>
      (await SharedPreferences.getInstance()).getString(_kModel) ??
      'deepseek-chat';

  Future<void> setModel(String model) async =>
      (await SharedPreferences.getInstance()).setString(_kModel, model);

  /// 'daily' | 'weekly'
  Future<String> meetCadence() async =>
      (await SharedPreferences.getInstance()).getString(_kMeetCadence) ??
      'daily';

  Future<void> setMeetCadence(String cadence) async =>
      (await SharedPreferences.getInstance()).setString(_kMeetCadence, cadence);
}
