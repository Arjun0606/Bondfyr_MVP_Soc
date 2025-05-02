import SwiftUI

// Environment key for pending event navigation
struct PendingEventNavigationKey: EnvironmentKey {
    static let defaultValue: String? = nil
}

// Environment key for pending event action
struct PendingEventActionKey: EnvironmentKey {
    static let defaultValue: String? = nil
}

extension EnvironmentValues {
    var pendingEventNavigation: String? {
        get { self[PendingEventNavigationKey.self] }
        set { self[PendingEventNavigationKey.self] = newValue }
    }
    
    var pendingEventAction: String? {
        get { self[PendingEventActionKey.self] }
        set { self[PendingEventActionKey.self] = newValue }
    }
} 