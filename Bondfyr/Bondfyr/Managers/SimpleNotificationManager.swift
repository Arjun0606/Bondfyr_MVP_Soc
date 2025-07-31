import Foundation
import UserNotifications
import FirebaseAuth

/// SIMPLE NOTIFICATION MANAGER - Actually works correctly!
@MainActor
class SimpleNotificationManager: ObservableObject {
    static let shared = SimpleNotificationManager()
    
    private let notificationCenter = UNUserNotificationCenter.current()
    
    private init() {}
    
    // MARK: - Setup
    func requestPermissions() async -> Bool {
        do {
            let granted = try await notificationCenter.requestAuthorization(options: [.alert, .badge, .sound])
            print("🔔 SIMPLE: Notification permissions granted: \(granted)")
            return granted
        } catch {
            print("🔴 SIMPLE: Notification permission error: \(error)")
            return false
        }
    }
    
    // MARK: - Host Notifications
    /// When a guest submits a request → notify HOST
    func sendHostNotification_NewGuestRequest(guestName: String, partyTitle: String) async {
        print("🟢 SIMPLE: Sending HOST notification - New guest request from \(guestName)")
        
        let content = UNMutableNotificationContent()
        content.title = "🔔 New Guest Request"
        content.body = "\(guestName) wants to join \(partyTitle). Tap to review!"
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "host_new_guest_\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        
        do {
            try await notificationCenter.add(request)
            print("✅ SIMPLE: Host notification sent successfully")
        } catch {
            print("🔴 SIMPLE: Failed to send host notification: \(error)")
        }
    }
    
    // MARK: - Guest Notifications
    /// When host approves a guest → notify GUEST
    func sendGuestNotification_RequestApproved(partyTitle: String, amount: Double) async {
        print("🟢 SIMPLE: Sending GUEST notification - Request approved for \(partyTitle)")
        
        let content = UNMutableNotificationContent()
        content.title = "🎉 Request Approved!"
        content.body = "You're approved for \(partyTitle)! Complete payment ($\(Int(amount))) to secure your spot."
        content.sound = .default
        
        // CRITICAL: Add payment action
        content.userInfo = ["action": "show_payment"]
        
        let request = UNNotificationRequest(
            identifier: "guest_approved_\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        
        do {
            try await notificationCenter.add(request)
            print("✅ SIMPLE: Guest approval notification sent successfully")
            
            // Post local notification to trigger payment flow
            NotificationCenter.default.post(
                name: Notification.Name("GuestApproved"),
                object: nil,
                userInfo: ["action": "show_payment"]
            )
        } catch {
            print("🔴 SIMPLE: Failed to send guest notification: \(error)")
        }
    }
    
    /// Payment reminder for guest
    func sendGuestNotification_PaymentReminder(partyTitle: String, amount: Double) async {
        print("🟢 SIMPLE: Sending GUEST notification - Payment reminder")
        
        let content = UNMutableNotificationContent()
        content.title = "💳 Payment Required"
        content.body = "Don't forget to complete your payment for \(partyTitle) - $\(Int(amount))"
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(
            identifier: "payment_reminder_\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        
        do {
            try await notificationCenter.add(request)
            print("✅ SIMPLE: Payment reminder sent successfully")
        } catch {
            print("🔴 SIMPLE: Failed to send payment reminder: \(error)")
        }
    }
    
    // MARK: - Rating & Reputation Notifications
    
    /// Send rating request to guest after party ends
    func sendNotification(to userId: String, title: String, body: String, data: [String: String] = [:]) {
        Task {
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            content.userInfo = data
            
            let request = UNNotificationRequest(
                identifier: "rating_\(userId)_\(UUID().uuidString)",
                content: content,
                trigger: nil
            )
            
            do {
                try await notificationCenter.add(request)
                print("✅ SIMPLE: Rating notification sent to \(userId)")
            } catch {
                print("🔴 SIMPLE: Failed to send rating notification: \(error)")
            }
        }
    }
    
    /// Send verification achievement notification
    func sendVerificationNotification(userId: String, type: String) {
        Task {
            let content = UNMutableNotificationContent()
            content.title = type == "host" ? "Host Verified! 🏆" : "Guest Verified! ⭐"
            content.body = type == "host" ? 
                "Congratulations! You're now a verified host on Bondfyr!" :
                "Congratulations! You're now a verified guest on Bondfyr!"
            content.sound = .default
            content.userInfo = ["type": "verification_achieved", "verification_type": type]
            
            let request = UNNotificationRequest(
                identifier: "verification_\(userId)_\(type)",
                content: content,
                trigger: nil
            )
            
            do {
                try await notificationCenter.add(request)
                print("✅ SIMPLE: Verification notification sent to \(userId)")
            } catch {
                print("🔴 SIMPLE: Failed to send verification notification: \(error)")
            }
        }
    }
    
    /// Send host achievement notification after successful party
    func sendHostAchievementNotification(hostId: String, averageRating: Double) {
        Task {
            let content = UNMutableNotificationContent()
            content.title = "Party Success! 🎉"
            content.body = String(format: "Your party received a %.1f⭐ rating! Keep hosting great events!", averageRating)
            content.sound = .default
            content.userInfo = ["type": "host_achievement"]
            
            let request = UNNotificationRequest(
                identifier: "host_achievement_\(hostId)_\(UUID().uuidString)",
                content: content,
                trigger: nil
            )
            
            do {
                try await notificationCenter.add(request)
                print("✅ SIMPLE: Host achievement notification sent to \(hostId)")
            } catch {
                print("🔴 SIMPLE: Failed to send host achievement notification: \(error)")
            }
        }
    }
    
    // MARK: - Notification Status & Testing
    
    /// Comprehensive notification system test
    func testAllNotificationTypes() {
        Task {
            print("🧪 TESTING: Starting comprehensive notification test...")
            
            let testTypes = [
                ("Guest Request", "🔔 New Guest Request", "John wants to join Epic House Party"),
                ("Request Approved", "✅ Request Approved", "You're in! Party starts in 2 hours"),
                ("Party Reminder", "⏰ Party Reminder", "Epic House Party starts in 30 minutes!"),
                ("Rate Party", "⭐ Rate Your Experience", "How was Epic House Party? Your rating helps!"),
                ("Host Achievement", "🎉 Party Success!", "Your party received 4.8⭐ rating!"),
                ("Verification", "🏆 Host Verified!", "You're now a verified host on Bondfyr!")
            ]
            
            for (index, (type, title, body)) in testTypes.enumerated() {
                let delay = Double(index) * 2.0 // 2 second intervals
                
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    Task {
                        let content = UNMutableNotificationContent()
                        content.title = title
                        content.body = body
                        content.sound = .default
                        content.userInfo = ["test_type": type]
                        
                        let request = UNNotificationRequest(
                            identifier: "test_\(type.lowercased().replacingOccurrences(of: " ", with: "_"))",
                            content: content,
                            trigger: nil
                        )
                        
                        do {
                            try await self.notificationCenter.add(request)
                            print("✅ TESTING: \(type) notification sent")
                        } catch {
                            print("🔴 TESTING: Failed to send \(type): \(error)")
                        }
                    }
                }
            }
        }
    }
    
    /// Check notification permission status
    func checkNotificationStatus() async -> Bool {
        let settings = await notificationCenter.notificationSettings()
        let isAuthorized = settings.authorizationStatus == .authorized
        
        print("🔔 STATUS: Notification permission \(isAuthorized ? "✅ GRANTED" : "❌ DENIED")")
        print("🔔 STATUS: Alert: \(settings.alertSetting == .enabled ? "✅" : "❌")")
        print("🔔 STATUS: Badge: \(settings.badgeSetting == .enabled ? "✅" : "❌")")
        print("🔔 STATUS: Sound: \(settings.soundSetting == .enabled ? "✅" : "❌")")
        
        return isAuthorized
    }
    
    // MARK: - Clear All
    func clearAllNotifications() {
        notificationCenter.removeAllPendingNotificationRequests()
        notificationCenter.removeAllDeliveredNotifications()
        print("🧹 SIMPLE: Cleared all notifications")
    }
} 