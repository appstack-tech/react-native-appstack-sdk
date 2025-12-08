import type { TurboModule } from 'react-native';
import { TurboModuleRegistry, NativeModules } from 'react-native';

export interface Spec extends TurboModule {
  configure(apiKey: string, isDebug?: boolean, endpointBaseUrl?: string, logLevel?: number): Promise<boolean>;
  sendEvent(eventType: string | null, eventName: string | null, parameters?: Record<string, any> | null): Promise<boolean>;
  enableAppleAdsAttribution(): Promise<boolean>;
  getAppstackId(): Promise<string>;
  isSdkDisabled(): Promise<boolean>;
  getAttributionParams(): Promise<Record<string, any>>;
}

// Support both old and new architecture
const AppstackReactNativeModule = TurboModuleRegistry.getEnforcing<Spec>('AppstackReactNative');

export default AppstackReactNativeModule || NativeModules.AppstackReactNative;
