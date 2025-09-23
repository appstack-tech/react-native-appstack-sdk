#import "AppstackReactNative.h"
#import "AppstackBridge.h"

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
            NSLog(@"[AppstackReactNative] Calling AppstackBridge.configure directly...");
            
            // Call the Swift bridge method directly
            [AppstackBridge configureWithApiKey:apiKey isDebug:isDebug endpointBaseUrl:endpointBaseUrl logLevel:logLevel];
            
            NSLog(@"[AppstackReactNative] configure method called successfully via bridge");
            
            NSLog(@"[AppstackReactNative] configure completed, resolving promise");
            resolve(@(YES));
        } @catch (NSException *exception) {
            NSLog(@"[AppstackReactNative] configure failed with exception: %@", exception.reason);
            reject(@"CONFIGURATION_ERROR", exception.reason, nil);
        }
    });
}

#pragma mark - Event Tracking

RCT_EXPORT_METHOD(sendEvent:(NSString *)eventType
                 eventName:(NSString *)eventName
                 revenue:(id _Nullable)revenue
                 resolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
    NSLog(@"[AppstackReactNative] sendEvent called with eventType: %@, eventName: %@, revenue: %@", eventType, eventName, revenue);
    
    // At least one of eventName or eventType should be provided
    if ((!eventName || [eventName length] == 0) && (!eventType || [eventType length] == 0)) {
        NSLog(@"[AppstackReactNative] sendEvent failed: Both eventName and eventType are empty");
        reject(@"INVALID_EVENT_NAME", @"Either eventName or eventType must be provided", nil);
        return;
    }
    
    // If eventType is CUSTOM, eventName is required
    if (eventType && [eventType length] > 0 && [eventType.uppercaseString isEqualToString:@"CUSTOM"]) {
        if (!eventName || [eventName length] == 0) {
            NSLog(@"[AppstackReactNative] sendEvent failed: eventName is required when eventType is CUSTOM");
            reject(@"INVALID_EVENT_NAME", @"eventName is required when eventType is CUSTOM", nil);
            return;
        }
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
        
        NSLog(@"[AppstackReactNative] Calling AppstackBridge.sendEvent directly...");
        
        // Call the Swift bridge method directly
        [AppstackBridge sendEvent:eventType eventName:eventName revenue:revenueDecimal];
        
        NSLog(@"[AppstackReactNative] sendEvent method called successfully via bridge");
        
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
            NSLog(@"[AppstackReactNative] Calling AppstackBridge.enableAppleAdsAttribution directly...");
            
            // Call the Swift bridge method directly
            [AppstackBridge enableAppleAdsAttribution];
            
            NSLog(@"[AppstackReactNative] enableAppleAdsAttribution method called successfully via bridge");
            
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
            NSLog(@"[AppstackReactNative] Calling AppstackBridge.disableASAAttributionTracking directly...");
            
            // Call the Swift bridge method directly
            [AppstackBridge disableASAAttributionTracking];
            
            NSLog(@"[AppstackReactNative] disableASAAttributionTracking method called successfully via bridge");
            
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
