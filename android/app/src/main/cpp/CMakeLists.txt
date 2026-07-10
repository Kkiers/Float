cmake_minimum_required(VERSION 3.18)
project(whisper_jni)

if(NOT DEFINED WHISPER_DIR)
    set(WHISPER_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../../../../whisper.cpp")
endif()
message(STATUS "WHISPER_DIR = ${WHISPER_DIR}")

# whisper.cpp static library
add_library(whisper STATIC
    ${WHISPER_DIR}/ggml/src/ggml.c
    ${WHISPER_DIR}/ggml/src/ggml-alloc.c
    ${WHISPER_DIR}/ggml/src/ggml-backend.cpp
    ${WHISPER_DIR}/ggml/src/ggml-backend-reg.cpp
    ${WHISPER_DIR}/ggml/src/ggml-backend-meta.cpp
    ${WHISPER_DIR}/ggml/src/ggml-backend-dl.cpp
    ${WHISPER_DIR}/ggml/src/ggml-quants.c
    ${WHISPER_DIR}/ggml/src/ggml-threading.cpp
    # ggml-cpu backend
    ${WHISPER_DIR}/ggml/src/ggml-cpu/ggml-cpu.c
    ${WHISPER_DIR}/ggml/src/ggml-cpu/ggml-cpu.cpp
    ${WHISPER_DIR}/ggml/src/ggml-cpu/repack.cpp
    ${WHISPER_DIR}/ggml/src/ggml-cpu/quants.c
    ${WHISPER_DIR}/ggml/src/ggml-cpu/traits.cpp
    ${WHISPER_DIR}/ggml/src/ggml-cpu/binary-ops.cpp
    ${WHISPER_DIR}/ggml/src/ggml-cpu/unary-ops.cpp
    ${WHISPER_DIR}/ggml/src/ggml-cpu/ops.cpp
    ${WHISPER_DIR}/ggml/src/ggml-cpu/vec.cpp
    ${WHISPER_DIR}/ggml/src/ggml-cpu/hbm.cpp
    # ARM arch
    ${WHISPER_DIR}/ggml/src/ggml-cpu/arch/arm/quants.c
    ${WHISPER_DIR}/ggml/src/ggml-cpu/arch/arm/repack.cpp
    ${WHISPER_DIR}/src/whisper.cpp
)

target_include_directories(whisper PRIVATE
    ${WHISPER_DIR}
    ${WHISPER_DIR}/include
    ${WHISPER_DIR}/ggml/include
    ${WHISPER_DIR}/ggml/src
    ${WHISPER_DIR}/ggml/src/ggml-cpu
)

# JNI shared library
add_library(whisper_jni SHARED whisper_jni.cc)
target_include_directories(whisper_jni PRIVATE ${WHISPER_DIR} ${WHISPER_DIR}/include ${WHISPER_DIR}/ggml/include)
target_link_libraries(whisper_jni whisper log dl)

target_compile_definitions(whisper PRIVATE GGML_USE_CPU)
target_compile_options(whisper PRIVATE -O3 -DNDEBUG -ffast-math -fno-finite-math-only -pthread -Wno-int-conversion -Wno-shift-sign-overflow -Wno-implicit-int-float-conversion -Wno-unused-function)
target_compile_options(whisper_jni PRIVATE -O3)
