cmake_minimum_required(VERSION 3.13)

# Define the library name
set(PACKAGE_NAME "AppstackReactNative")

# Create the main library
add_library(
    ${PACKAGE_NAME}
    SHARED
    src/main/cpp/AppstackReactNative.cpp
)

# Set target properties for 16KB page size compatibility
# This is required for Google Play's 16KB page size requirement
# https://developer.android.com/guide/practices/page-sizes
set_target_properties(${PACKAGE_NAME} PROPERTIES
    # Ensure 16KB alignment for LOAD segments
    ANDROID_NO_UNDEFINED NO
    # Set minimum alignment for better compatibility
    POSITION_INDEPENDENT_CODE ON
)

# Add linker flags for 16KB page size support
# This ensures the native library is properly aligned for devices with 16KB pages
target_link_options(${PACKAGE_NAME} PRIVATE
    -Wl,-z,max-page-size=16384
)

# Include directories
target_include_directories(
    ${PACKAGE_NAME}
    PRIVATE
    src/main/cpp
)

# Set C++ standard
target_compile_features(${PACKAGE_NAME} PRIVATE cxx_std_17)

# Link against system libraries
target_link_libraries(
    ${PACKAGE_NAME}
    android
    log
)
