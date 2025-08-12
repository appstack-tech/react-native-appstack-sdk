# AppStack Attribution SDK (Android)

This directory contains the **multi-module Android implementation** of the AppStack Attribution SDK.
The structure mirrors the architecture defined in *implementation_plan.md*.

```
:attribution-sdk/
├── core/      # Public API + shared interfaces & data models
├── storage/   # Thread-safe SharedPreferences persistence
├── network/   # Retrofit/OkHttp HTTP client
├── queue/     # Event batching / offline queue (placeholder for now)
└── config/    # Remote config fetcher (placeholder for now)
```

## Build & Test

```
./gradlew :core:test        # Run JVM tests for `core`
./gradlew :storage:test     # Run Robolectric concurrency test
```

Gradle wrapper not committed (to keep repo slim). Use Android Studio to import the directory; the IDE will download wrappers & sync.