import Foundation
@_spi(AppstackInternal) @preconcurrency import AppstackSDK

@objc(AppstackBridge)
public class AppstackBridge: NSObject {

    private static func eventTypeFromString(_ string: String) -> EventType? {
        return EventType.allCases.first { $0.rawValue == string.uppercased() }
    }

    private static let wrapperVersion = "react-native-1.0.0"

    @objc public static func configure(apiKey: String, logLevel: Int, customerUserId: String?) {
        // Translate the JS-side logLevel contract (0=DEBUG, 1=INFO, 2=WARN, 3=ERROR;
        // verbosity descending) into the native LogLevel enum (off/error/info/debug;
        // verbosity ascending). This keeps iOS consistent with Android and with the
        // documented JS values. iOS has no dedicated WARN tier, so WARN folds down to
        // .error — quieter than INFO, and there are no warn-level logs on iOS to lose.
        let logLevelEnum: LogLevel
        switch logLevel {
        case 0:
            logLevelEnum = .debug
        case 1:
            logLevelEnum = .info
        case 2, 3:
            logLevelEnum = .error
        default:
            logLevelEnum = .info
        }
        
        AppstackAttributionSdk.shared.configure(
            apiKey: apiKey,
            logLevel: logLevelEnum,
            customerUserId: customerUserId,
            wrapperVersion: AppstackBridge.wrapperVersion
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
    
    @objc(getAttributionParamsWithCompletion:)
    public static func getAttributionParams(
        completion: @escaping @Sendable (NSDictionary?, NSError?) -> Void
    ) {
        Task {
            let params = await AppstackAttributionSdk.shared.getAttributionParams()
            completion(params as NSDictionary? ?? [:], nil)
        }
    }
}
