package com.floating.capture

import android.content.Context
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaRecorder
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import android.os.Handler
import android.os.Looper
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.ShortBuffer

class WhisperPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

    private var channel: MethodChannel? = null
    private var appContext: Context? = null
    private var modelLoaded = false
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        appContext = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "com.float.capture/whisper")
        channel?.setMethodCallHandler(this)

        // Pre-load native lib
        try { WhisperEngine.load() } catch (_: Exception) {}
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        WhisperEngine.nativeFree()
        modelLoaded = false
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "loadModel" -> {
                val path = resolveModelPath(call.argument<String>("path"))
                try {
                    WhisperEngine.load()
                    val ok = WhisperEngine.nativeInit(path)
                    modelLoaded = ok
                    result.success(ok)
                } catch (e: Exception) {
                    result.error("WHISPER", e.message, null)
                }
            }
            "isLoaded" -> result.success(modelLoaded)
            "transcribeFile" -> {
                val filePath = call.argument<String>("filePath") ?: run {
                    result.error("ARG", "filePath required", null)
                    return
                }
                val language = call.argument<String>("language") ?: "zh"
                Thread {
                    try {
                        val text = transcribeFile(filePath, language)
                        mainHandler.post {
                            channel?.invokeMethod("onResult", text)
                        }
                    } catch (e: Exception) {
                        mainHandler.post {
                            channel?.invokeMethod("onError", e.message)
                        }
                    }
                }.start()
                result.success(null) // async, result comes via channel
            }
            "free" -> {
                WhisperEngine.nativeFree()
                modelLoaded = false
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    /** 若指定路径不存在则回退到默认路径（首次启动会从 assets 拷贝模型）。 */
    private fun resolveModelPath(requested: String?): String {
        if (requested != null && File(requested).exists()) return requested
        return getDefaultModelPath()
    }

    /** Get or create the default model path. Copies from assets on first launch if needed. */
    private fun getDefaultModelPath(): String {        val dir = File(appContext?.filesDir, "models")
        dir.mkdirs()
        val modelFile = File(dir, "ggml-tiny.bin")

        if (!modelFile.exists()) {
            // Try copying from assets
            try {
                appContext?.assets?.open("models/ggml-tiny.bin")?.use { input ->
                    modelFile.outputStream().use { output ->
                        input.copyTo(output)
                    }
                }
            } catch (_: Exception) {}
        }

        // Fallback: check external storage
        if (!modelFile.exists()) {
            val extDir = appContext?.getExternalFilesDir(null)
            val extFile = File(extDir, "models/ggml-tiny.bin")
            if (extFile.exists()) return extFile.absolutePath
        }

        return modelFile.absolutePath
    }

    /** Decode an AMR audio file to 16kHz mono PCM float samples, then run whisper. */
    private fun transcribeFile(filePath: String, language: String): String {
        val samples = decodeToPcmFloat(filePath) ?: return ""
        return WhisperEngine.nativeTranscribe(samples, samples.size, language)
    }

    /** Decode AMR file to 16kHz mono PCM float array [-1..1]. */
    private fun decodeToPcmFloat(filePath: String): FloatArray? {
        try {
            val extractor = MediaExtractor()
            extractor.setDataSource(filePath)

            var trackIndex = -1
            for (i in 0 until extractor.trackCount) {
                val mime = extractor.getTrackFormat(i).getString(MediaFormat.KEY_MIME) ?: ""
                if (mime == "audio/3gpp" || mime == "audio/amr-wb" || mime == "audio/amr") {
                    trackIndex = i
                    break
                }
            }
            if (trackIndex < 0) return null
            extractor.selectTrack(trackIndex)

            val format = extractor.getTrackFormat(trackIndex)
            val mime = format.getString(MediaFormat.KEY_MIME) ?: return null

            // Create decoder
            val decoder = MediaCodec.createDecoderByType(mime)
            decoder.configure(format, null, null, 0)
            decoder.start()

            val pcmFloats = mutableListOf<Float>()
            var inputDone = false
            val bufferInfo = android.media.MediaCodec.BufferInfo()

            while (!inputDone || decoder.outputBuffers.isNotEmpty()) {
                if (!inputDone) {
                    val inIdx = decoder.dequeueInputBuffer(10000)
                    if (inIdx >= 0) {
                        val buf = decoder.getInputBuffer(inIdx)!!
                        val size = extractor.readSampleData(buf, 0)
                        if (size < 0) {
                            decoder.queueInputBuffer(inIdx, 0, 0, 0,
                                MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                            inputDone = true
                        } else {
                            decoder.queueInputBuffer(inIdx, 0, size,
                                extractor.sampleTime, 0)
                            extractor.advance()
                        }
                    }
                }

                val outIdx = decoder.dequeueOutputBuffer(bufferInfo, 10000)
                if (outIdx >= 0) {
                    val outBuf = decoder.getOutputBuffer(outIdx)!!
                    if (bufferInfo.size > 0) {
                        // Convert PCM bytes to float samples
                        val bytes = ByteArray(bufferInfo.size)
                        outBuf.position(bufferInfo.offset)
                        outBuf.get(bytes, 0, bufferInfo.size)

                        // AMR decoder output is 16-bit PCM
                        val shortBuf = ByteBuffer.wrap(bytes)
                            .order(ByteOrder.nativeOrder())
                            .asShortBuffer()
                        val shorts = ShortArray(shortBuf.remaining())
                        shortBuf.get(shorts)

                        for (s in shorts) {
                            pcmFloats.add(s.toFloat() / 32768f)
                        }
                    }
                    decoder.releaseOutputBuffer(outIdx, false)
                    if (bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) break
                }
            }
            decoder.stop()
            decoder.release()
            extractor.release()

            return if (pcmFloats.isNotEmpty()) pcmFloats.toFloatArray() else null
        } catch (e: Exception) {
            return null
        }
    }
}
