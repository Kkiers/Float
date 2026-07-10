package com.floating.capture

import android.Manifest
import android.content.pm.PackageManager
import android.media.MediaRecorder
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

class AudioRecorderPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

    private var channel: MethodChannel? = null
    private var recorder: MediaRecorder? = null
    private var outputPath: String? = null
    private var appContext: android.content.Context? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        appContext = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "com.float.capture/audio_recorder")
        channel?.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        appContext = null
        stopRecording()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "start" -> {
                val path = call.argument<String>("path")
                if (path != null) {
                    startRecording(path, result)
                } else {
                    result.error("ARG", "path required", null)
                }
            }
            "stop" -> stopRecording(result)
            "isRecording" -> result.success(recorder != null)
            else -> result.notImplemented()
        }
    }

    private fun startRecording(path: String, result: MethodChannel.Result) {
        try {
            stopRecording() // ensure clean state

            val dir = File(path).parentFile
            if (dir != null && !dir.exists()) dir.mkdirs()

            outputPath = path
            recorder = MediaRecorder().apply {
                setAudioSource(MediaRecorder.AudioSource.MIC)
                setOutputFormat(MediaRecorder.OutputFormat.THREE_GPP)
                setAudioEncoder(MediaRecorder.AudioEncoder.AMR_WB) // 16kHz for Whisper
                setOutputFile(path)
                prepare()
                start()
            }
            result.success(true)
        } catch (e: Exception) {
            recorder?.release()
            recorder = null
            result.error("RECORD", e.message, null)
        }
    }

    private fun stopRecording(result: MethodChannel.Result? = null) {
        try {
            recorder?.apply {
                stop()
                release()
            }
            recorder = null
            result?.success(outputPath)
        } catch (e: Exception) {
            recorder = null
            result?.error("STOP", e.message, null)
        }
    }
}
