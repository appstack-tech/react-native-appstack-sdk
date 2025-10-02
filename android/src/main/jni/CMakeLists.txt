# CMakeLists.txt for AppstackReactNative codegen compatibility
# This ensures the SDK works with React Native 0.79+ and Expo 54+

cmake_minimum_required(VERSION 3.13)

# Create the codegen spec library for compatibility
add_library(
    react_codegen_AppstackReactNativeSpec
    SHARED
    AppstackReactNativeSpec.cpp
)

# Link dependencies if available
if(TARGET ReactAndroid::jsi)
    target_link_libraries(
        react_codegen_AppstackReactNativeSpec
        ReactAndroid::jsi
        ReactAndroid::turbomodulejsijni
        ReactAndroid::react_nativemodule_core
    )
else()
    # Fallback for older React Native versions
    target_link_libraries(
        react_codegen_AppstackReactNativeSpec
        android
        log
    )
endif()

# Include directories
target_include_directories(
    react_codegen_AppstackReactNativeSpec
    PRIVATE
    .
)
