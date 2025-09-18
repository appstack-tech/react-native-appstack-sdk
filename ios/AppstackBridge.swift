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
    
    @objc public static func sendEvent(_ eventType: String?, eventName: String?, revenue: NSDecimalNumber?) {
        // Determine the EventType enum to use
        let finalEventType: EventType
        let finalEventName: String?
        
        if let eventTypeString = eventType, !eventTypeString.isEmpty {
            // Use provided event_type parameter
            if let enumEvent = EventType(rawValue: eventTypeString.uppercased()) {
                finalEventType = enumEvent
                if enumEvent == .CUSTOM {
                    // For CUSTOM event type, use the provided eventName
                    finalEventName = eventName
                } else {
                    // For non-CUSTOM event types, use eventType as eventName
                    finalEventName = eventTypeString
                }
            } else {
                // Invalid event type, fallback to CUSTOM
                finalEventType = .CUSTOM
                finalEventName = eventName ?? eventTypeString
            }
        } else if let eventNameString = eventName, !eventNameString.isEmpty {
            // Fallback to legacy behavior - try to parse eventName as EventType
            if let enumEvent = EventType(rawValue: eventNameString.uppercased()) {
                finalEventType = enumEvent
                if enumEvent == .CUSTOM {
                    // For CUSTOM event type, use the eventNameString as the name
                    finalEventName = eventNameString
                } else {
                    // For non-CUSTOM event types, use eventNameString as eventName
                    finalEventName = eventNameString
                }
            } else {
                // For custom events, use CUSTOM type
                finalEventType = .CUSTOM
                finalEventName = eventNameString
            }
        } else {
            // Neither event_type nor eventName provided, default to CUSTOM
            finalEventType = .CUSTOM
            finalEventName = "UNKNOWN_EVENT"
        }
        
        // Convert NSDecimalNumber to Double
        let revenueDouble = revenue?.doubleValue
        
        AppstackAttributionSdk.shared.sendEvent(
            event: finalEventType,
            name: finalEventName,
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
