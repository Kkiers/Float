package com.floating.capture

/// JNI bridge to whisper.cpp native library.
object WhisperEngine {
    private var loaded = false

    fun load() {
        if (!loaded) {
            System.loadLibrary("whisper_jni")
            loaded = true
        }
    }

    /** Load the whisper model. Returns true on success. */
    external fun nativeInit(modelPath: String): Boolean

    /** Transcribe PCM 16kHz mono float samples. Returns recognized text. */
    external fun nativeTranscribe(samples: FloatArray, nSamples: Int, language: String): String

    /** Free the model from memory. */
    external fun nativeFree()
}
