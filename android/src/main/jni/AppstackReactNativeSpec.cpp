#include <jni.h>
#include <android/log.h>

// Minimal codegen spec implementation for AppstackReactNative
// This provides compatibility with React Native's new architecture

#define LOG_TAG "AppstackReactNativeSpec"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)

extern "C" JNIEXPORT jint JNICALL JNI_OnLoad(JavaVM *vm, void *reserved) {
    LOGI("AppstackReactNativeSpec codegen library loaded");
    return JNI_VERSION_1_6;
}

extern "C" JNIEXPORT void JNICALL JNI_OnUnload(JavaVM *vm, void *reserved) {
    LOGI("AppstackReactNativeSpec codegen library unloaded");
}
