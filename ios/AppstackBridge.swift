import Foundation
import AppstackSDK

@objc(AppstackBridge)
public class AppstackBridge: NSObject {

    private static func eventTypeFromString(_ string: String) -> EventType? {
        return EventType.allCases.first { $0.rawValue == string.uppercased() }
    }

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
    
    @objc public static func sendEvent(_ eventType: String?, eventName: String?, parameters: NSDictionary?) {
        // Determine the EventType enum to use
        let finalEventType: EventType
        let finalEventName: String?
        
        if let eventTypeString = eventType, !eventTypeString.isEmpty {
            // Use provided event_type parameter
            if let enumEvent = eventTypeFromString(eventTypeString) {
                finalEventType = enumEvent
                // For CUSTOM event type, eventName is required
                // For non-CUSTOM event types, name should be nil (SDK will use the event type)
                finalEventName = (enumEvent == .CUSTOM) ? eventName : nil
            } else {
                // Invalid event type, fallback to CUSTOM
                finalEventType = .CUSTOM
                finalEventName = eventName ?? eventTypeString
            }
        } else if let eventNameString = eventName, !eventNameString.isEmpty {
            // Fallback to legacy behavior - try to parse eventName as EventType
            if let enumEvent = eventTypeFromString(eventNameString) {
                finalEventType = enumEvent
                // For CUSTOM, use the name; for others, use nil
                finalEventName = (enumEvent == .CUSTOM) ? eventNameString : nil
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
        
        // Convert NSDictionary to Swift Dictionary
        let parametersDict = parameters as? [String: Any]
        
        AppstackAttributionSdk.shared.sendEvent(
            event: finalEventType,
            name: finalEventName,
            parameters: parametersDict
        )
    }
    
    @objc public static func enableAppleAdsAttribution() {
        AppstackASAAttribution.shared.enableAppleAdsAttribution()
    }
    
    @objc public static func disableASAAttributionTracking() {
        AppstackASAAttribution.shared.disableASAAttributionTracking()
    }
    
    @objc public static func getAppstackId() -> String {
        return AppstackAttributionSdk.shared.getAppstackId() ?? ""
    }

    @objc public static func isSdkDisabled() -> Bool {
        return AppstackAttributionSdk.shared.isSdkDisabled()
    }
    
    @objc public static func getAttributionParams() -> NSDictionary {
        let params = AppstackAttributionSdk.shared.getAttributionParams()
        return params as NSDictionary? ?? [:]
    }
}
