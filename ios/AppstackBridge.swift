import Foundation
import AppstackSDK

@objc public class AppstackBridge: NSObject {
    
    @objc public static func configure(apiKey: String, isDebug: Bool) {
        Appstack.shared.configure(apiKey, isDebug: isDebug)
    }
    
    @objc public static func sendEvent(_ eventName: String, revenue: Decimal) {
        if (revenue == 0.0) {
            Appstack.shared.sendEvent(event: eventName)
        } else {
            Appstack.shared.sendEvent(event: eventName, revenue: revenue)
        }
    }
    
    @objc public static func enableAppleAdsAttribution() {
        AppstackASAAttribution.shared.enableAppleAdsAttribution()
    }
}
