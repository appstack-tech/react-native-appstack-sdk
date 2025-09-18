#import "AppstackReactNative.h"

@implementation AppstackReactNative

RCT_EXPORT_MODULE()

+ (BOOL)requiresMainQueueSetup
{
    return NO;
}

- (NSArray<NSString *> *)supportedEvents
{
    return @[];
}

#pragma mark - SDK Configuration

RCT_EXPORT_METHOD(configure:(NSString *)apiKey
                 isDebug:(BOOL)isDebug
                 endpointBaseUrl:(NSString * _Nullable)endpointBaseUrl
                 logLevel:(NSInteger)logLevel
                 resolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
    NSLog(@"[AppstackReactNative] configure called with apiKey: %@, isDebug: %@, endpointBaseUrl: %@, logLevel: %ld", apiKey, isDebug ? @"YES" : @"NO", endpointBaseUrl ?: @"nil", (long)logLevel);
    
    if (!apiKey || [apiKey length] == 0) {
        NSLog(@"[AppstackReactNative] configure failed: Invalid API key");
        reject(@"INVALID_API_KEY", @"API key cannot be null or empty", nil);
        return;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            NSLog(@"[AppstackReactNative] Looking up AppstackBridge class...");
            // Use Swift bridge class
            Class BridgeClass = NSClassFromString(@"react_native_appstack_sdk.AppstackBridge");
            
            if (BridgeClass) {
                NSLog(@"[AppstackReactNative] AppstackBridge class found!");
                
                if ([BridgeClass respondsToSelector:@selector(configureWithApiKey:isDebug:endpointBaseUrl:logLevel:)]) {
                    NSLog(@"[AppstackReactNative] 'configureWithApiKey:isDebug:endpointBaseUrl:logLevel:' method found, calling with apiKey: %@, isDebug: %@, endpointBaseUrl: %@, logLevel: %ld", apiKey, isDebug ? @"YES" : @"NO", endpointBaseUrl ?: @"nil", (long)logLevel);
                    [BridgeClass performSelector:@selector(configureWithApiKey:isDebug:endpointBaseUrl:logLevel:) withObject:apiKey withObject:@(isDebug) withObject:endpointBaseUrl withObject:@(logLevel)];
                    NSLog(@"[AppstackReactNative] configure method called successfully via bridge");
                } else {
                    NSLog(@"[AppstackReactNative] ERROR: 'configureWithApiKey:isDebug:endpointBaseUrl:logLevel:' method not found on AppstackBridge");
                }
            } else {
                NSLog(@"[AppstackReactNative] ERROR: AppstackBridge class not found. Trying alternative class name...");
                
                // Try alternative Swift class name format
                Class AltBridgeClass = NSClassFromString(@"AppstackBridge");
                if (AltBridgeClass) {
                    NSLog(@"[AppstackReactNative] Alternative AppstackBridge class found!");
                    if ([AltBridgeClass respondsToSelector:@selector(configureWithApiKey:isDebug:endpointBaseUrl:logLevel:)]) {
                        NSLog(@"[AppstackReactNative] Calling configure via alternative bridge class");
                        [AltBridgeClass performSelector:@selector(configureWithApiKey:isDebug:endpointBaseUrl:logLevel:) withObject:apiKey withObject:@(isDebug) withObject:endpointBaseUrl withObject:@(logLevel)];
                        NSLog(@"[AppstackReactNative] configure method called successfully via alternative bridge");
                    } else {
                        NSLog(@"[AppstackReactNative] ERROR: 'configureWithApiKey:isDebug:endpointBaseUrl:logLevel:' method not found on alternative AppstackBridge");
                    }
                } else {
                    NSLog(@"[AppstackReactNative] ERROR: Neither AppstackBridge class variant found");
                }
            }
            
            NSLog(@"[AppstackReactNative] configure completed, resolving promise");
            resolve(@(YES));
        } @catch (NSException *exception) {
            NSLog(@"[AppstackReactNative] configure failed with exception: %@", exception.reason);
            reject(@"CONFIGURATION_ERROR", exception.reason, nil);
        }
    });
}

#pragma mark - Event Tracking

RCT_EXPORT_METHOD(sendEvent:(NSString *)eventName
                 revenue:(id _Nullable)revenue
                 resolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
    NSLog(@"[AppstackReactNative] sendEvent called with eventName: %@, revenue: %@", eventName, revenue);
    
    if (!eventName || [eventName length] == 0) {
        NSLog(@"[AppstackReactNative] sendEvent failed: Invalid event name");
        reject(@"INVALID_EVENT_NAME", @"Event name cannot be null or empty", nil);
        return;
    }
    
    @try {
        NSDecimalNumber *revenueDecimal = nil;
        
        if (revenue != nil && revenue != [NSNull null]) {
            NSLog(@"[AppstackReactNative] Processing revenue: %@ (class: %@)", revenue, NSStringFromClass([revenue class]));
            
            if ([revenue isKindOfClass:[NSNumber class]]) {
                // Handle number values
                revenueDecimal = [NSDecimalNumber decimalNumberWithDecimal:[revenue decimalValue]];
                NSLog(@"[AppstackReactNative] Revenue processed as NSNumber: %@", revenueDecimal);
            } else if ([revenue isKindOfClass:[NSString class]]) {
                // Handle string values
                NSString *revenueString = (NSString *)revenue;
                if ([revenueString length] > 0) {
                    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
                    formatter.numberStyle = NSNumberFormatterDecimalStyle;
                    NSNumber *revenueNumber = [formatter numberFromString:revenueString];
                    
                    if (revenueNumber != nil) {
                        revenueDecimal = [NSDecimalNumber decimalNumberWithDecimal:[revenueNumber decimalValue]];
                        NSLog(@"[AppstackReactNative] Revenue processed as NSString: %@", revenueDecimal);
                    } else {
                        NSLog(@"[AppstackReactNative] sendEvent failed: Invalid revenue string");
                        reject(@"INVALID_REVENUE", @"Revenue string must be a valid number", nil);
                        return;
                    }
                }
            } else {
                NSLog(@"[AppstackReactNative] sendEvent failed: Invalid revenue type");
                reject(@"INVALID_REVENUE", @"Revenue must be a number, string, or null", nil);
                return;
            }
        } else {
            NSLog(@"[AppstackReactNative] Revenue is null or NSNull, proceeding without revenue");
        }
        
        NSLog(@"[AppstackReactNative] Looking up AppstackBridge class for sendEvent...");
        // Use Swift bridge class for sendEvent
        Class BridgeClass = NSClassFromString(@"react_native_appstack_sdk.AppstackBridge");
        
        if (BridgeClass) {
            NSLog(@"[AppstackReactNative] AppstackBridge class found for sendEvent!");
            
            if ([BridgeClass respondsToSelector:@selector(sendEvent:revenue:)]) {
                NSLog(@"[AppstackReactNative] 'sendEvent:revenue:' method found, calling with eventName: %@, revenue: %@", eventName, revenueDecimal);
                [BridgeClass performSelector:@selector(sendEvent:revenue:) withObject:eventName withObject:revenueDecimal];
                NSLog(@"[AppstackReactNative] sendEvent method called successfully via bridge");
            } else {
                NSLog(@"[AppstackReactNative] ERROR: 'sendEvent:revenue:' method not found on AppstackBridge");
            }
        } else {
            NSLog(@"[AppstackReactNative] ERROR: AppstackBridge class not found for sendEvent. Trying alternative class name...");
            
            // Try alternative Swift class name format
            Class AltBridgeClass = NSClassFromString(@"AppstackBridge");
            if (AltBridgeClass) {
                NSLog(@"[AppstackReactNative] Alternative AppstackBridge class found for sendEvent!");
                if ([AltBridgeClass respondsToSelector:@selector(sendEvent:revenue:)]) {
                    NSLog(@"[AppstackReactNative] Calling sendEvent via alternative bridge class");
                    [AltBridgeClass performSelector:@selector(sendEvent:revenue:) withObject:eventName withObject:revenueDecimal];
                    NSLog(@"[AppstackReactNative] sendEvent method called successfully via alternative bridge");
                } else {
                    NSLog(@"[AppstackReactNative] ERROR: 'sendEvent:revenue:' method not found on alternative AppstackBridge");
                }
            } else {
                NSLog(@"[AppstackReactNative] ERROR: Neither AppstackBridge class variant found for sendEvent");
            }
        }
        
        NSLog(@"[AppstackReactNative] sendEvent completed, resolving promise");
        resolve(@(YES));
    } @catch (NSException *exception) {
        NSLog(@"[AppstackReactNative] sendEvent failed with exception: %@", exception.reason);
        reject(@"EVENT_SEND_ERROR", exception.reason, nil);
    }
}

#pragma mark - Apple Search Ads Attribution

RCT_EXPORT_METHOD(enableAppleAdsAttribution:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
    NSLog(@"[AppstackReactNative] enableAppleAdsAttribution called");
    
    if (@available(iOS 15.0, *)) {
        NSLog(@"[AppstackReactNative] iOS 15.0+ detected, proceeding with Apple Ads Attribution");
        @try {
            NSLog(@"[AppstackReactNative] Looking up AppstackBridge class for ASA...");
            // Use Swift bridge class for Apple Ads Attribution
            Class BridgeClass = NSClassFromString(@"react_native_appstack_sdk.AppstackBridge");
            
            if (BridgeClass) {
                NSLog(@"[AppstackReactNative] AppstackBridge class found for ASA!");
                
                if ([BridgeClass respondsToSelector:@selector(enableAppleAdsAttribution)]) {
                    NSLog(@"[AppstackReactNative] 'enableAppleAdsAttribution' method found, calling...");
                    [BridgeClass performSelector:@selector(enableAppleAdsAttribution)];
                    NSLog(@"[AppstackReactNative] enableAppleAdsAttribution method called successfully via bridge");
                } else {
                    NSLog(@"[AppstackReactNative] ERROR: 'enableAppleAdsAttribution' method not found on AppstackBridge");
                }
            } else {
                NSLog(@"[AppstackReactNative] ERROR: AppstackBridge class not found for ASA. Trying alternative class name...");
                
                // Try alternative Swift class name format
                Class AltBridgeClass = NSClassFromString(@"AppstackBridge");
                if (AltBridgeClass) {
                    NSLog(@"[AppstackReactNative] Alternative AppstackBridge class found for ASA!");
                    if ([AltBridgeClass respondsToSelector:@selector(enableAppleAdsAttribution)]) {
                        NSLog(@"[AppstackReactNative] Calling enableAppleAdsAttribution via alternative bridge class");
                        [AltBridgeClass performSelector:@selector(enableAppleAdsAttribution)];
                        NSLog(@"[AppstackReactNative] enableAppleAdsAttribution method called successfully via alternative bridge");
                    } else {
                        NSLog(@"[AppstackReactNative] ERROR: 'enableAppleAdsAttribution' method not found on alternative AppstackBridge");
                    }
                } else {
                    NSLog(@"[AppstackReactNative] ERROR: Neither AppstackBridge class variant found for ASA");
                }
            }
            
            NSLog(@"[AppstackReactNative] enableAppleAdsAttribution completed, resolving promise");
            resolve(@(YES));
        } @catch (NSException *exception) {
            NSLog(@"[AppstackReactNative] enableAppleAdsAttribution failed with exception: %@", exception.reason);
            reject(@"ASA_ATTRIBUTION_ERROR", exception.reason, nil);
        }
    } else {
        NSLog(@"[AppstackReactNative] ERROR: iOS version < 15.0, Apple Ads Attribution not supported");
        reject(@"UNSUPPORTED_IOS_VERSION", @"Apple Ads Attribution requires iOS 15.0 or later", nil);
    }
}

#pragma mark - Additional SDK Methods

RCT_EXPORT_METHOD(disableASAAttributionTracking:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
    NSLog(@"[AppstackReactNative] disableASAAttributionTracking called");
    
    if (@available(iOS 15.0, *)) {
        NSLog(@"[AppstackReactNative] iOS 15.0+ detected, proceeding with disable ASA Attribution");
        @try {
            NSLog(@"[AppstackReactNative] Looking up AppstackBridge class for disable ASA...");
            // Use Swift bridge class for disable ASA Attribution
            Class BridgeClass = NSClassFromString(@"react_native_appstack_sdk.AppstackBridge");
            
            if (BridgeClass) {
                NSLog(@"[AppstackReactNative] AppstackBridge class found for disable ASA!");
                
                if ([BridgeClass respondsToSelector:@selector(disableASAAttributionTracking)]) {
                    NSLog(@"[AppstackReactNative] 'disableASAAttributionTracking' method found, calling...");
                    [BridgeClass performSelector:@selector(disableASAAttributionTracking)];
                    NSLog(@"[AppstackReactNative] disableASAAttributionTracking method called successfully via bridge");
                } else {
                    NSLog(@"[AppstackReactNative] ERROR: 'disableASAAttributionTracking' method not found on AppstackBridge");
                }
            } else {
                NSLog(@"[AppstackReactNative] ERROR: AppstackBridge class not found for disable ASA. Trying alternative class name...");
                
                // Try alternative Swift class name format
                Class AltBridgeClass = NSClassFromString(@"AppstackBridge");
                if (AltBridgeClass) {
                    NSLog(@"[AppstackReactNative] Alternative AppstackBridge class found for disable ASA!");
                    if ([AltBridgeClass respondsToSelector:@selector(disableASAAttributionTracking)]) {
                        NSLog(@"[AppstackReactNative] Calling disableASAAttributionTracking via alternative bridge class");
                        [AltBridgeClass performSelector:@selector(disableASAAttributionTracking)];
                        NSLog(@"[AppstackReactNative] disableASAAttributionTracking method called successfully via alternative bridge");
                    } else {
                        NSLog(@"[AppstackReactNative] ERROR: 'disableASAAttributionTracking' method not found on alternative AppstackBridge");
                    }
                } else {
                    NSLog(@"[AppstackReactNative] ERROR: Neither AppstackBridge class variant found for disable ASA");
                }
            }
            
            NSLog(@"[AppstackReactNative] disableASAAttributionTracking completed, resolving promise");
            resolve(@(YES));
        } @catch (NSException *exception) {
            NSLog(@"[AppstackReactNative] disableASAAttributionTracking failed with exception: %@", exception.reason);
            reject(@"ASA_DISABLE_ERROR", exception.reason, nil);
        }
    } else {
        NSLog(@"[AppstackReactNative] ERROR: iOS version < 15.0, Apple Ads Attribution not supported");
        reject(@"UNSUPPORTED_IOS_VERSION", @"Apple Ads Attribution requires iOS 15.0 or later", nil);
    }
}

@end
