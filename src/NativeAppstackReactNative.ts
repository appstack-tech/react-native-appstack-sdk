import type { TurboModule } from 'react-native';
import { TurboModuleRegistry } from 'react-native';

export interface Spec extends TurboModule {
  configure(apiKey: string): Promise<boolean>;
  sendEvent(eventName: string, revenue?: number | string): Promise<boolean>;
  enableAppleAdsAttribution(): Promise<boolean>;
}

export default TurboModuleRegistry.getEnforcing<Spec>('AppstackReactNative');
