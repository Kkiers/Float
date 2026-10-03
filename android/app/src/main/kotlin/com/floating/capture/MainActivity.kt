package com.floating.capture

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngineCache

class MainActivity : FlutterActivity() {

    private var overlayPluginsRegistered = false

    /**
     * 悬浮窗跑在独立的 Flutter 引擎里（flutter_overlay_window 固定把缓存 tag 写死为
     * "myCachedEngine"），该引擎只通过 GeneratedPluginRegistrant 自动注册 pubspec 里的插件，
     * 拿不到 App 里手写的 AudioRecorderPlugin / WhisperPlugin。
     *
     * 这里在悬浮窗引擎创建之后（onAttachedToActivity 早于 onPostResume）补注册这两个插件，
     * 保证「录音 → 转写」的方法通道在悬浮窗引擎里也能响应。
     */
    override fun onPostResume() {
        super.onPostResume()
        if (overlayPluginsRegistered) return
        val overlayEngine = FlutterEngineCache.getInstance().get("myCachedEngine") ?: return
        overlayEngine.plugins.add(AudioRecorderPlugin())
        overlayEngine.plugins.add(WhisperPlugin())
        overlayPluginsRegistered = true
    }
}
