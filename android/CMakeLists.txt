cmake_minimum_required(VERSION 3.13)

# Define the library name
set(PACKAGE_NAME "AppstackReactNative")

# Check if the codegen directory exists
set(CODEGEN_JNI_DIR "${CMAKE_CURRENT_SOURCE_DIR}/build/generated/source/codegen/jni")

# Always create the main library first
add_library(
    ${PACKAGE_NAME}
    SHARED
    src/main/cpp/AppstackReactNative.cpp
)

# Check if codegen directory exists and include it
if(EXISTS "${CODEGEN_JNI_DIR}/CMakeLists.txt")
    # New architecture: include codegen
    add_subdirectory("${CODEGEN_JNI_DIR}")
    
    # Link against the codegen library
    target_link_libraries(
        ${PACKAGE_NAME}
        react_codegen_AppstackReactNativeSpec
        android
        log
    )
    
    message(STATUS "AppstackReactNative: Building with New Architecture (TurboModules) support")
else()
    # Old architecture: minimal dependencies only
    target_link_libraries(
        ${PACKAGE_NAME}
        android
        log
    )
    
    message(STATUS "AppstackReactNative: Building with Old Architecture support")
endif()

# Include directories
target_include_directories(
    ${PACKAGE_NAME}
    PRIVATE
    src/main/cpp
)

# Set C++ standard
target_compile_features(${PACKAGE_NAME} PRIVATE cxx_std_17)
