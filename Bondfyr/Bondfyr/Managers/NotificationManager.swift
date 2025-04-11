//
//  NotificationManager.swift
//  Bondfyr
//
//  Created by Arjun Varma on 31/03/25.
//

import Foundation
import UserNotifications
import Firebase
import FirebaseFirestore
import FirebaseMessaging
import FirebaseAuth

enum NotificationType {
    case photoContestUnlocked(eventId: String, eventName: String)
    case newEventAnnouncement(eventId: String, eventName: String)
    case ticketPurchaseConfirmation(eventId: String, eventName: String, ticketId: String)
    case upcomingEvent(eventId: String, eventName: String, daysUntilEvent: Int)
    
    var title: String {
        switch self {
        case .photoContestUnlocked(_, let eventName):
            return "Photo Contest Unlocked! 📸"
        case .newEventAnnouncement(_, let eventName):
            return "New Event: \(eventName)"
        case .ticketPurchaseConfirmation(_, let eventName, _):
            return "Ticket Confirmed for \(eventName)"
        case .upcomingEvent(_, let eventName, let days):
            return "\(eventName) is in \(days) days!"
        }
    }
    
    var body: String {
        switch self {
        case .photoContestUnlocked(_, let eventName):
            return "You can now share photos at \(eventName)! Your photos will be visible to all attendees."
        case .newEventAnnouncement(_, let eventName):
            return "We just announced a new event: \(eventName). Check it out!"
        case .ticketPurchaseConfirmation(_, let eventName, _):
            return "Your ticket for \(eventName) has been confirmed. It's available in the app."
        case .upcomingEvent(_, let eventName, let days):
            return "Get ready! \(eventName) is coming up in \(days) days."
        }
    }
    
    var identifier: String {
        switch self {
        case .photoContestUnlocked(let eventId, _):
            return "photo-contest-unlocked-\(eventId)"
        case .newEventAnnouncement(let eventId, _):
            return "new-event-\(eventId)"
        case .ticketPurchaseConfirmation(_, _, let ticketId):
            return "ticket-confirmation-\(ticketId)"
        case .upcomingEvent(let eventId, _, _):
            return "upcoming-event-\(eventId)"
        }
    }
    
    var userInfo: [AnyHashable: Any] {
        switch self {
        case .photoContestUnlocked(let eventId, let eventName):
            return [
                "type": "photo_contest_unlocked",
                "eventId": eventId,
                "eventName": eventName
            ]
        case .newEventAnnouncement(let eventId, let eventName):
            return [
                "type": "new_event",
                "eventId": eventId,
                "eventName": eventName
            ]
        case .ticketPurchaseConfirmation(let eventId, let eventName, let ticketId):
            return [
                "type": "ticket_confirmation",
                "eventId": eventId,
                "eventName": eventName,
                "ticketId": ticketId
            ]
        case .upcomingEvent(let eventId, let eventName, let daysUntilEvent):
            return [
                "type": "upcoming_event",
                "eventId": eventId,
                "eventName": eventName,
                "daysUntilEvent": daysUntilEvent
            ]
        }
    }
}

class NotificationManager: NSObject {
    static let shared = NotificationManager()

    private let notificationCenter = UNUserNotificationCenter.current()
    
    override init() {
        super.init()
        self.notificationCenter.delegate = self
        
        // Check authorization status on initialization
        checkNotificationStatus()
    }
    
    private func checkNotificationStatus() {
        self.notificationCenter.getNotificationSettings { settings in
            if settings.authorizationStatus != .authorized {
                print("Notifications not authorized, will request permission")
                DispatchQueue.main.async {
                    self.requestAuthorization()
                }
            } else {
                print("Notification permissions already granted")
            }
        }
    }

    func requestAuthorization() {
        print("Requesting notification permission with alert, sound, badge")
        self.notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("✅ Notification permission granted")
                
                // Register for remote notifications on main thread
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            } else if let error = error {
                print("❌ Notification permission error: \(error.localizedDescription)")
            } else {
                print("❌ Notification permission denied by user")
            }
        }
    }
    
    // Add requestPermission for backward compatibility
    func requestPermission() {
        requestAuthorization()
    }

    // Test function to send a notification immediately
    func sendTestNotification() {
        let content = UNMutableNotificationContent()
        content.title = "📸 Contest Photo Opportunity!"
        content.body = "Take your best retro-filtered shot now - no retakes allowed!"
        content.sound = .default
        content.userInfo = [
            "eventId": "test-event-id", 
            "eventName": "Retro Night", 
            "type": "contest_active",
            "direct_to_camera": "true"  // Add this to indicate we want to go directly to the camera
        ]
        
        // Trigger after 3 seconds
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "testNotification_\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        
        self.notificationCenter.add(request) { error in
            if let error = error {
                print("❌ Error sending test notification: \(error.localizedDescription)")
            } else {
                print("✅ Test notification scheduled successfully")
            }
        }
    }

    func schedulePhotoNotification(forEvent eventName: String) {
        let content = UNMutableNotificationContent()
        content.title = "Time to Capture the Moment!"
        content.body = "You have 3 minutes to capture and upload a photo for \(eventName)."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 10, repeats: false) // 10 sec for testing

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        self.notificationCenter.add(request) { error in
            if let error = error {
                print("Failed to schedule notification: \(error)")
            }
        }
    }

    func scheduleContestNotification(forEvent eventId: String) {
        // Get event details
        let db = Firestore.firestore()
        db.collection("events").document(eventId).getDocument { snapshot, error in
            guard let data = snapshot?.data(),
                  let eventName = data["name"] as? String else {
                return
            }
            
            // Create contest photo notification for checked-in users
            let content = UNMutableNotificationContent()
            content.title = "Photo Contest at \(eventName)!"
            content.body = "The photo contest is now active! Take a retro-filtered photo to win - no retakes allowed."
            content.sound = .default
            content.userInfo = ["eventId": eventId, "type": "contest_active"]
            
            // Trigger the notification immediately
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            let request = UNNotificationRequest(
                identifier: "contest_notification_\(eventId)_\(UUID().uuidString)",
                content: content,
                trigger: trigger
            )
            
            self.notificationCenter.add(request) { error in
                if let error = error {
                    print("Error scheduling contest notification: \(error.localizedDescription)")
                }
            }
        }
    }

    // Schedule a notification for new contest photos for all users who are not checked in
    func notifyUsersAboutNewContestPhotos(forEvent eventId: String, venueName: String) {
        // Create notification about new contest photos
        let content = UNMutableNotificationContent()
        content.title = "New Retro Contest Photos at \(venueName)"
        content.body = "Check out the latest retro-filtered contest photos and vote for your favorites!"
        content.sound = .default
        content.userInfo = ["eventId": eventId, "type": "new_contest_photos"]
        
        // Trigger the notification immediately
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "new_photos_notification_\(eventId)_\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        
        self.notificationCenter.add(request) { error in
            if let error = error {
                print("Error scheduling new photos notification: \(error.localizedDescription)")
            }
        }
    }

    // Schedule reminder notification
    func scheduleEventReminder(for event: Event, hoursInAdvance: Int = 2) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM d, yyyy HH:mm"
        
        guard let eventDate = dateFormatter.date(from: "\(event.date) \(event.time)") else {
            print("Failed to parse event date")
            return
        }
        
        let reminderTime = eventDate.addingTimeInterval(-Double(hoursInAdvance * 3600))
        
        // Only schedule if reminder time is in the future
        guard reminderTime > Date() else {
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = "Event Reminder: \(event.name)"
        content.body = "Your event at \(event.location) starts in \(hoursInAdvance) hours!"
        content.sound = .default
        content.userInfo = ["eventId": event.id.uuidString]
        
        let triggerDate = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: reminderTime
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
        let request = UNNotificationRequest(
            identifier: "event_reminder_\(event.id.uuidString)",
            content: content,
            trigger: trigger
        )
        
        self.notificationCenter.add(request) { error in
            if let error = error {
                print("Error scheduling event reminder: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Local Notifications
    
    func scheduleLocalNotification(for notificationType: NotificationType, delaySeconds: TimeInterval = 0) {
        // Check if notifications are authorized
        self.notificationCenter.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else {
                print("Notifications not authorized")
                return
            }
            
            // Create the notification content
            let content = UNMutableNotificationContent()
            content.title = notificationType.title
            content.body = notificationType.body
            content.sound = .default
            content.userInfo = notificationType.userInfo
            
            // Create the trigger (time-based)
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, delaySeconds), repeats: false)
            
            // Create the notification request
            let request = UNNotificationRequest(
                identifier: notificationType.identifier,
                content: content,
                trigger: trigger
            )
            
            // Schedule the notification
            self.notificationCenter.add(request) { error in
                if let error = error {
                    print("Error scheduling notification: \(error)")
                }
            }
        }
    }
    
    // MARK: - Remote Notifications
    
    func registerDeviceToken(_ deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
        
        // Get the FCM token
        Messaging.messaging().token { token, error in
            if let error = error {
                print("Error getting FCM token: \(error)")
                return
            }
            
            if let token = token {
                self.saveTokenToFirestore(token)
            }
        }
    }
    
    private func saveTokenToFirestore(_ token: String) {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("User not logged in, can't save device token")
            return
        }
        
        let db = Firestore.firestore()
        let tokenData: [String: Any] = [
            "token": token,
            "device": "iOS",
            "lastUpdated": FieldValue.serverTimestamp()
        ]
        
        db.collection("users").document(userId).collection("deviceTokens").document(token).setData(tokenData) { error in
            if let error = error {
                print("Error saving device token: \(error)")
            }
        }
    }
    
    // MARK: - Photo Contest Specific
    
    func sendPhotoContestUnlockedNotification(eventId: String, eventName: String) {
        let notificationType = NotificationType.photoContestUnlocked(eventId: eventId, eventName: eventName)
        scheduleLocalNotification(for: notificationType, delaySeconds: 2)
    }
    
    // Vendor-triggered photo contest notification
    func triggerPhotoContestForEvent(eventId: String) {
        // Get event details
        let db = Firestore.firestore()
        db.collection("events").document(eventId).getDocument { [weak self] snapshot, error in
            guard let self = self,
                  let data = snapshot?.data(),
                  let eventName = data["name"] as? String else {
                print("Error getting event data for contest notification")
                return
            }
            
            // 1. Send notification to all users with tickets for this event
            self.notifyCheckedInUsersAboutPhotoContest(eventId: eventId, eventName: eventName)
            
            // 2. Update event's contest status in Firestore
            EventService.shared.togglePhotoContest(eventId: eventId, active: true) { success, error in
                if let error = error {
                    print("Error updating contest status: \(error.localizedDescription)")
                } else {
                    print("Contest status updated successfully")
                }
            }
        }
    }
    
    private func notifyCheckedInUsersAboutPhotoContest(eventId: String, eventName: String) {
        // Create notification content
        let content = UNMutableNotificationContent()
        content.title = "📸 Photo Contest Now Live!"
        content.body = "Take your best photo at \(eventName) - you have 12 hours to participate!"
        content.sound = .default
        content.userInfo = [
            "eventId": eventId,
            "eventName": eventName,
            "type": "vendor_triggered_contest"
        ]
        
        // Trigger notification immediately
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        
        // Create request with unique identifier 
        let request = UNNotificationRequest(
            identifier: "vendor_photo_contest_\(eventId)_\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        
        // Schedule notification
        self.notificationCenter.add(request) { error in
            if let error = error {
                print("Error scheduling vendor-triggered contest notification: \(error)")
            } else {
                print("Vendor-triggered contest notification scheduled successfully")
            }
        }
        
        // For FCM, we would typically send to all users with tokens registered for this event
        // This would be handled by a Cloud Function in a real implementation
    }
    
    // End photo contest for an event
    func endPhotoContestForEvent(eventId: String) {
        // Update event's contest status in Firestore
        let db = Firestore.firestore()
        db.collection("events").document(eventId).updateData([
            "photoContestActive": false,
            "photoContestEndTime": FieldValue.serverTimestamp()
        ]) { error in
            if let error = error {
                print("Error ending event contest: \(error)")
            } else {
                print("Event contest ended successfully")
            }
        }
    }
    
    // MARK: - Notification Management
    
    func cancelNotification(identifier: String) {
        self.notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])
        self.notificationCenter.removeDeliveredNotifications(withIdentifiers: [identifier])
    }
    
    func cancelAllNotifications() {
        self.notificationCenter.removeAllPendingNotificationRequests()
        self.notificationCenter.removeAllDeliveredNotifications()
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationManager: UNUserNotificationCenterDelegate {
    // Called when a notification is displayed and the app is in the foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show the notification even when the app is in the foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    // Called when a user interacts with a notification
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        
        // Handle navigation based on notification type
        if let type = userInfo["type"] as? String {
            switch type {
            case "photo_contest_unlocked":
                if let eventId = userInfo["eventId"] as? String {
                    // Handle navigation to photo contest (this would be implemented by the app's navigation system)
                    print("Should navigate to photo contest for event \(eventId)")
                    
                    // Post a notification that can be observed by the app to navigate
                    NotificationCenter.default.post(
                        name: Notification.Name("NavigateToPhotoContest"),
                        object: nil,
                        userInfo: userInfo
                    )
                }
            case "new_event", "upcoming_event":
                if let eventId = userInfo["eventId"] as? String {
                    // Handle navigation to event details
                    NotificationCenter.default.post(
                        name: Notification.Name("NavigateToEvent"),
                        object: nil,
                        userInfo: userInfo
                    )
                }
            case "ticket_confirmation":
                if let ticketId = userInfo["ticketId"] as? String {
                    // Handle navigation to ticket details
                    NotificationCenter.default.post(
                        name: Notification.Name("NavigateToTicket"),
                        object: nil,
                        userInfo: userInfo
                    )
                }
            default:
                break
            }
        }
        
        completionHandler()
    }
}


