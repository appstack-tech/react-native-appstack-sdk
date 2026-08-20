import type { TurboModule } from 'react-native';
import { TurboModuleRegistry } from 'react-native';

/**
 * TurboModule spec for the Appstack native module.
 *
 * This file is consumed by React Native's codegen (see `codegenConfig` in
 * package.json). Codegen derives the native names from this file, so do not
 * rename it: the filename produces the ObjC protocol / Java abstract class
 * `NativeAppstackReactNativeSpec` and the JS module name `AppstackReactNative`,
 * which must keep matching `RCT_EXPORT_MODULE()` on iOS and
 * `AppstackReactNativeModuleImpl.NAME` on Android.
 *
 * Codegen constraints that are easy to break:
 * - Parameters must be required and explicitly nullable (`string | null`), never
 *   optional (`string?`). Optional parameters are generated as boxed types
 *   (`NSNumber *` / `@Nullable Double`) instead of primitives.
 * - `Object` is the supported "arbitrary JSON object" annotation. `Record<K, V>`
 *   is not in the codegen type map and fails to parse.
 * - Exactly one `TurboModuleRegistry` call is allowed per spec file.
 *
 * `clearData`, `isEnabled` and `disableASAAttributionTracking` are intentionally
 * part of the spec but not part of the documented `AppstackSDK` API. They exist
 * natively on one platform each and are declared here so they stay reachable on
 * both the legacy and the new architecture (new-architecture dispatch is built
 * solely from this schema, so a native method missing from it is uncallable).
 *
 * `sendEvent` keeps three parameters even though the public JS API takes two. The
 * public `sendEvent(event, parameters)` resolves the pair in JavaScript and always
 * passes an explicit, unambiguous combination: either a standard event type with a
 * `null` name, or the `"CUSTOM"` category with a non-null name. Both native wrappers
 * still contain fallback branches that guess when the type is unrecognised or the
 * name is missing, and those branches used to disagree — an unknown type became a
 * custom event on iOS but was rejected with `INVALID_EVENT_NAME` on Android. Because
 * JS no longer emits either shape, those branches are unreachable. Preserve that
 * invariant when changing the public API: it is what keeps the two platforms
 * behaving identically without touching native code.
 */
export interface Spec extends TurboModule {
  configure(apiKey: string, logLevel: number, customerUserId: string | null): Promise<boolean>;
  setCustomerUserId(customerUserId: string | null): Promise<void>;
  sendEvent(
    eventType: string | null,
    eventName: string | null,
    parameters: Object | null
  ): Promise<boolean>;
  enableAppleAdsAttribution(): Promise<boolean>;
  /** iOS only; resolves `false` on Android. */
  disableASAAttributionTracking(): Promise<boolean>;
  /** Android only; resolves `false` on iOS. */
  clearData(): Promise<boolean>;
  isEnabled(): Promise<boolean>;
  getAppstackId(): Promise<string>;
  isSdkDisabled(): Promise<boolean>;
  getAttributionParams(): Promise<Object>;
}

// `get`, not `getEnforcing`: `getEnforcing` throws at import time when the
// package is not linked (for example under Expo Go), which would replace the
// actionable linking error built in src/index.ts with a stack trace from this
// module. On the legacy architecture `get` returns the entry from
// `NativeModules`, so this single call site works on both architectures.
export default TurboModuleRegistry.get<Spec>('AppstackReactNative');
