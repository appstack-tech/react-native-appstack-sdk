import Foundation
import AppstackSDK

@objc public class AppstackBridge: NSObject {
    
    @objc public static func configure(apiKey: String, isDebug: Bool, endpointBaseUrl: String?, logLevel: Int) {
        // Convert Int logLevel to LogLevel enum
        let logLevelEnum: LogLevel
        switch logLevel {
        case 0:
            logLevelEnum = .off
        case 1:
            logLevelEnum = .error
        case 2:
            logLevelEnum = .debug
        case 3:
            logLevelEnum = .info
        default:
            logLevelEnum = .info
        }
        
        AppstackAttributionSdk.shared.configure(
            apiKey: apiKey,
            isDebug: isDebug,
            endpointBaseUrl: endpointBaseUrl,
            logLevel: logLevelEnum
        )
    }
    
    @objc public static func sendEvent(_ eventName: String, revenue: NSDecimalNumber?) {
        // Convert string event name to EventType enum
        let eventType: EventType
        if let enumEvent = EventType(rawValue: eventName.uppercased()) {
            eventType = enumEvent
        } else {
            // For custom events, use CUSTOM type
            eventType = .CUSTOM
        }
        
        // Convert NSDecimalNumber to Double
        let revenueDouble = revenue?.doubleValue
        
        AppstackAttributionSdk.shared.sendEvent(
            event: eventType,
            name: eventType == .CUSTOM ? eventName : nil,
            revenue: revenueDouble
        )
    }
    
    @objc public static func enableAppleAdsAttribution() {
        AppstackASAAttribution.shared.enableAppleAdsAttribution()
    }
    
    @objc public static func disableASAAttributionTracking() {
        AppstackASAAttribution.shared.disableASAAttributionTracking()
    }
}
