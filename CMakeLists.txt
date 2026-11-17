cmake_minimum_required(VERSION 3.20)
project(OnLiveAudioEngine VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# Compiler optimization flags for Real-Time DSP Audio
if(CMAKE_CXX_COMPILER_ID MATCHES "Clang|AppleClang|GNU")
    add_compile_options(-O3 -ffast-math -Wall -Wextra -Wpedantic)
endif()

# Core DSP Static Library
add_library(onlive_dsp STATIC
    src/dsp/src/AudioEngine.cpp
)

target_include_directories(onlive_dsp PUBLIC
    src/dsp/include
)

# Test Executable
add_executable(test_dsp_engine
    src/tests/test_dsp_engine.cpp
)

target_link_libraries(test_dsp_engine PRIVATE
    onlive_dsp
)
