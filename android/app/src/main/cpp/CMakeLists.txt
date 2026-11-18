cmake_minimum_required(VERSION 3.20)
project(onlive_jni LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(DSP_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../../../../src/dsp")

add_library(onlive_audio_jni SHARED
    jni_bridge.cpp
    ${DSP_DIR}/src/AudioEngine.cpp
)

target_include_directories(onlive_audio_jni PRIVATE
    ${DSP_DIR}/include
)

find_library(log-lib log)
find_library(android-lib android)

target_link_libraries(onlive_audio_jni
    ${log-lib}
    ${android-lib}
)

