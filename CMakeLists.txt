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

# Stress & Benchmark Executable
add_executable(stress_and_benchmark_test
    src/tests/stress_and_benchmark_test.cpp
)

target_link_libraries(stress_and_benchmark_test PRIVATE
    onlive_dsp
)

# ========================================================
# macOS DESKTOP BUNDLE TARGET
# ========================================================
if(APPLE)
    if(NOT CMAKE_OSX_DEPLOYMENT_TARGET)
        set(CMAKE_OSX_DEPLOYMENT_TARGET "12.0" CACHE STRING "Minimum OS X version")
    endif()
    if(NOT CMAKE_OSX_ARCHITECTURES)
        set(CMAKE_OSX_ARCHITECTURES "x86_64;arm64" CACHE STRING "Universal architectures")
    endif()

    enable_language(OBJCXX)

    set(MACOS_SOURCES
        macos/src/main.mm
        macos/src/AppDelegate.mm
        macos/src/MainWindowController.mm
        macos/src/CoreAudioHALManager.mm
        macos/src/ConsoleFaderView.mm
    )

    add_executable(PandaQQ MACOSX_BUNDLE
        ${MACOS_SOURCES}
    )

    set_target_properties(PandaQQ PROPERTIES
        MACOSX_BUNDLE_INFO_PLIST "${CMAKE_CURRENT_SOURCE_DIR}/macos/Info.plist"
        MACOSX_BUNDLE_BUNDLE_NAME "Panda QQ"
        MACOSX_BUNDLE_GUI_IDENTIFIER "com.pandaqq.desktop"
        MACOSX_BUNDLE_BUNDLE_VERSION "1.0.0"
        MACOSX_BUNDLE_SHORT_VERSION_STRING "1.0.0"
    )

    target_include_directories(PandaQQ PRIVATE
        macos/src
        src/dsp/include
    )

    target_compile_options(PandaQQ PRIVATE
        -fobjc-arc
    )

    target_link_libraries(PandaQQ PRIVATE
        onlive_dsp
        "-framework Cocoa"
        "-framework WebKit"
        "-framework CoreAudio"
        "-framework AudioToolbox"
    )
endif()
