# Placeholder ProGuard consumer rules – SDK exports no special keep rules 

# This file is packaged inside the AAR produced by the :sdk module.
# When an app (or another library) depends on this AAR, its contents
# are automatically merged into the final R8/ProGuard rules that are
# applied during the consumer app's minification/obfuscation phase.
#
# ⚠️  WHY THIS MATTERS
# --------------------
# • Without these keep-rules, any classes, methods, or annotations used
#   reflectively (e.g. via Retrofit, Moshi, WorkManager, or the Android
#   framework) risk being renamed or stripped out, leading to runtime
#   `ClassNotFoundException`, `NoSuchMethodException`, or hard-to-debug
#   crashes that *look* like dependency version conflicts.
# • Shipping the rules **with** the AAR means the SDK can evolve in a
#   backwards-compatible way—future updates can add new rules here and
#   they will be picked up automatically by all host apps without any
#   manual action on their side.
#
# This file serves as a single point of truth for all consumer-side ProGuard requirements.
#
# Add concrete -keep / -dontwarn directives below as they become necessary. 
# Example template:
#
#   -keep class com.appstack.attribution.** { <init>(...); *; } 