#include <jni.h>
#include <android/log.h>

// Main C++ implementation for AppstackReactNative
// This provides compatibility with both old and new React Native architectures

#define LOG_TAG "AppstackReactNative"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)

extern "C" JNIEXPORT jint JNICALL JNI_OnLoad(JavaVM *vm, void *reserved) {
    LOGI("AppstackReactNative native library loaded");
    return JNI_VERSION_1_6;
}

extern "C" JNIEXPORT void JNICALL JNI_OnUnload(JavaVM *vm, void *reserved) {
    LOGI("AppstackReactNative native library unloaded");
}
