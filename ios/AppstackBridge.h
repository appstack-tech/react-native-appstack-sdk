//
//  AppstackBridge.h
//  react-native-appstack-sdk
//
//  Created by React Native Appstack SDK
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface AppstackBridge : NSObject

+ (void)configureWithApiKey:(NSString *)apiKey 
                    isDebug:(BOOL)isDebug 
            endpointBaseUrl:(NSString * _Nullable)endpointBaseUrl 
                   logLevel:(NSInteger)logLevel
             customerUserId:(NSString * _Nullable)customerUserId;

+ (void)sendEvent:(NSString * _Nullable)eventType 
        eventName:(NSString * _Nullable)eventName 
       parameters:(NSDictionary * _Nullable)parameters;

+ (void)enableAppleAdsAttribution;

+ (void)disableASAAttributionTracking;

+ (NSString *)getAppstackId;

+ (BOOL)isSdkDisabled;

+ (NSDictionary *)getAttributionParams;

@end

NS_ASSUME_NONNULL_END

