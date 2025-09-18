import type { TurboModule } from 'react-native';
import { TurboModuleRegistry } from 'react-native';

export interface Spec extends TurboModule {
  configure(apiKey: string, isDebug?: boolean, endpointBaseUrl?: string, logLevel?: number): Promise<boolean>;
  sendEvent(eventName: string | null, eventType: string | null, revenue?: number | null): Promise<boolean>;
  enableAppleAdsAttribution(): Promise<boolean>;
}

export default TurboModuleRegistry.getEnforcing<Spec>('AppstackReactNative');
