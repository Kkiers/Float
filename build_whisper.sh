#!/bin/bash
# Build whisper.cpp for Android ARM64 and copy .so to the Flutter project.
#
# Prerequisites:
#   - Git
#   - CMake + Ninja
#   - Android NDK (will auto-detect from $ANDROID_SDK_ROOT or default location)
#
# Usage: bash build_whisper.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
JNILIBS="$SCRIPT_DIR/android/app/src/main/jniLibs/arm64-v8a"
CPP_DIR="$SCRIPT_DIR/android/app/src/main/cpp"
WHISPER_DIR="$SCRIPT_DIR/whisper.cpp"

# Find NDK
if [ -d "$ANDROID_SDK_ROOT/ndk" ]; then
    NDK=$(ls -d "$ANDROID_SDK_ROOT/ndk"/*/ 2>/dev/null | tail -1)
elif [ -d "D:/Android/Sdk/ndk" ]; then
    NDK=$(ls -d "D:/Android/Sdk/ndk"/*/ 2>/dev/null | tail -1)
else
    echo "ERROR: Cannot find Android NDK. Set ANDROID_SDK_ROOT."
    exit 1
fi
NDK="${NDK%/}"
echo "Using NDK: $NDK"

TOOLCHAIN="$NDK/build/cmake/android.toolchain.cmake"

# Clone whisper.cpp if missing
if [ ! -d "$WHISPER_DIR" ]; then
    echo "Cloning whisper.cpp..."
    git clone --depth 1 https://github.com/ggerganov/whisper.cpp.git "$WHISPER_DIR"
fi

# Build
BUILD_DIR="$WHISPER_DIR/build-android"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

cmake .. \
    -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN" \
    -DANDROID_ABI=arm64-v8a \
    -DANDROID_PLATFORM=android-24 \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_SHARED_LIBS=OFF \
    -DWHISPER_BUILD_EXAMPLES=OFF \
    -DWHISPER_BUILD_TESTS=OFF \
    -G "Ninja"

cmake --build . --target whisper -j4

# Build JNI wrapper
JNI_BUILD="$WHISPER_DIR/build-jni"
mkdir -p "$JNI_BUILD"
cd "$JNI_BUILD"

cmake "$CPP_DIR" \
    -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN" \
    -DANDROID_ABI=arm64-v8a \
    -DANDROID_PLATFORM=android-24 \
    -DCMAKE_BUILD_TYPE=Release \
    -G "Ninja"

cmake --build . -j4

# Copy output
mkdir -p "$JNILIBS"
cp "$JNI_BUILD/libwhisper_jni.so" "$JNILIBS/"
echo "✓ libwhisper_jni.so copied to $JNILIBS"

# Download model
MODEL_DIR="$SCRIPT_DIR/android/app/src/main/assets/models"
mkdir -p "$MODEL_DIR"
MODEL_FILE="$MODEL_DIR/ggml-tiny.bin"

if [ ! -f "$MODEL_FILE" ]; then
    echo "Downloading whisper tiny model..."
    MODEL_URL="https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.bin"
    if command -v curl &>/dev/null; then
        curl -L -o "$MODEL_FILE" "$MODEL_URL"
    elif command -v wget &>/dev/null; then
        wget -O "$MODEL_FILE" "$MODEL_URL"
    else
        echo "WARNING: curl/wget not found. Download model manually:"
        echo "  $MODEL_URL"
        echo "  Save to: $MODEL_FILE"
    fi
fi

echo ""
echo "=== Done ==="
if [ -f "$JNILIBS/libwhisper_jni.so" ]; then
    echo "✓ Native library ready"
fi
if [ -f "$MODEL_FILE" ]; then
    MODEL_SIZE=$(du -h "$MODEL_FILE" | cut -f1)
    echo "✓ Model ready (ggml-tiny.bin, $MODEL_SIZE)"
fi
echo ""
echo "Next: flutter build apk --debug"
