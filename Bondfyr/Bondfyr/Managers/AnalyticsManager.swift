import Foundation
import FirebaseAnalytics
import Mixpanel

final class AnalyticsManager {
    static let shared = AnalyticsManager()
    private init() {}

    func setUser(id: String?, email: String? = nil, city: String? = nil, isDemo: Bool? = nil) {
        if let id = id {
            Analytics.setUserID(id)
            Mixpanel.mainInstance().identify(distinctId: id)
        }
        var props: [String: Any] = [:]
        if let email = email { props["email"] = email }
        if let city = city { props["city"] = city }
        if let isDemo = isDemo { props["is_demo"] = isDemo }
        if !props.isEmpty {
            Mixpanel.mainInstance().people.set(properties: (props as? [String: MixpanelType]) ?? [:])
        }
    }

    func reset() {
        Analytics.setUserID(nil)
        Mixpanel.mainInstance().reset()
    }

    func track(_ name: String, _ props: [String: Any] = [:]) {
        Analytics.logEvent(name, parameters: props)
        Mixpanel.mainInstance().track(event: name, properties: (props as? [String: MixpanelType]) ?? [:])
    }
}


