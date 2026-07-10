#include <jni.h>
#include <android/log.h>
#include <string>
#include <vector>

#define TAG "WhisperJNI"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, TAG, __VA_ARGS__)

#include "whisper.h"
#include "ggml.h"

static whisper_context* g_ctx = nullptr;

// Custom abort handler — log instead of crashing
static void whisper_abort_handler(const char* msg) {
    LOGE("GGML ABORT: %s", msg ? msg : "unknown");
    // Don't call abort() — let the caller handle the error
}

extern "C" JNIEXPORT jboolean JNICALL
Java_com_floating_capture_WhisperEngine_nativeInit(
    JNIEnv* env, jobject /* this */, jstring modelPath) {

    const char* path = env->GetStringUTFChars(modelPath, nullptr);
    LOGI("Loading whisper model from: %s", path);

    if (g_ctx) {
        whisper_free(g_ctx);
        g_ctx = nullptr;
    }

    // Override abort to prevent native crash
    ggml_set_abort_callback(whisper_abort_handler);

    whisper_context_params cparams = whisper_context_default_params();
    cparams.use_gpu = false;
    cparams.flash_attn = false;
    g_ctx = whisper_init_from_file_with_params(path, cparams);
    env->ReleaseStringUTFChars(modelPath, path);

    if (g_ctx) {
        LOGI("Whisper model loaded successfully");
        return JNI_TRUE;
    } else {
        LOGE("Failed to load whisper model at %s", path);
        return JNI_FALSE;
    }
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_floating_capture_WhisperEngine_nativeTranscribe(
    JNIEnv* env, jobject /* this */, jfloatArray samples, jint nSamples, jstring language) {

    if (!g_ctx) {
        LOGE("Whisper not initialized");
        return env->NewStringUTF("");
    }

    jfloat* data = env->GetFloatArrayElements(samples, nullptr);
    const char* lang = env->GetStringUTFChars(language, nullptr);

    whisper_full_params params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY);
    params.print_progress = false;
    params.print_realtime = false;
    params.print_timestamps = false;
    params.no_timestamps = true;
    params.translate = false;
    params.language = lang;
    params.n_threads = 4;
    params.offset_ms = 0;

    int ret = whisper_full(g_ctx, params, data, nSamples);

    std::string result;
    if (ret == 0) {
        int n_segments = whisper_full_n_segments(g_ctx);
        for (int i = 0; i < n_segments; ++i) {
            const char* text = whisper_full_get_segment_text(g_ctx, i);
            if (text && strlen(text) > 0) {
                if (!result.empty()) result += " ";
                result += text;
            }
        }
    }

    env->ReleaseFloatArrayElements(samples, data, JNI_ABORT);
    env->ReleaseStringUTFChars(language, lang);

    LOGI("Transcription result: %s", result.c_str());
    return env->NewStringUTF(result.c_str());
}

extern "C" JNIEXPORT void JNICALL
Java_com_floating_capture_WhisperEngine_nativeFree(
    JNIEnv* /* env */, jobject /* this */) {
    if (g_ctx) {
        whisper_free(g_ctx);
        g_ctx = nullptr;
    }
}
