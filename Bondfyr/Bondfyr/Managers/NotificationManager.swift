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
    // Event notifications
    case photoContestUnlocked(eventId: String, eventName: String)
    case newEventAnnouncement(eventId: String, eventName: String)
    case ticketPurchaseConfirmation(eventId: String, eventName: String, ticketId: String)
    case upcomingEvent(eventId: String, eventName: String, daysUntilEvent: Int)
    
    // Party notifications - For Hosts
    case guestRequestReceived(partyId: String, partyTitle: String, guestName: String)
    case guestApprovalDeadline(partyId: String, partyTitle: String, pendingCount: Int)
    case partyCapacityAlert(partyId: String, partyTitle: String, currentCount: Int, maxCount: Int)
    case partyStartReminder(partyId: String, partyTitle: String, hoursUntil: Int)
    case paymentReceived(partyId: String, partyTitle: String, guestName: String, amount: String)
    
    // Party notifications - For Guests
    case requestApproved(partyId: String, partyTitle: String, hostName: String)
    case requestDenied(partyId: String, partyTitle: String, hostName: String)
    case partyLocationUpdate(partyId: String, partyTitle: String, newLocation: String)
    case partyTimeUpdate(partyId: String, partyTitle: String, newTime: String)
    case hostMessage(partyId: String, partyTitle: String, hostName: String, message: String)
    case partyStartingSoon(partyId: String, partyTitle: String, minutesUntil: Int)
    case partyEnding(partyId: String, partyTitle: String, minutesLeft: Int)
    
    // System notifications
    case systemMaintenance(scheduledTime: Date)
    case newFeatureAvailable(featureName: String)
    
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
        // Host notifications
        case .guestRequestReceived(_, let partyTitle, let guestName):
            return "New Guest Request 👋"
        case .guestApprovalDeadline(_, let partyTitle, let pendingCount):
            return "Approval Deadline Approaching ⏰"
        case .partyCapacityAlert(_, let partyTitle, _, _):
            return "Party Almost Full! 🎉"
        case .partyStartReminder(_, let partyTitle, let hoursUntil):
            return "Party Starting in \(hoursUntil)h ⭐"
        case .paymentReceived(_, let partyTitle, let guestName, _):
            return "Payment Received 💰"
        // Guest notifications
        case .requestApproved(_, let partyTitle, _):
            return "Request Approved! 🎉"
        case .requestDenied(_, let partyTitle, _):
            return "Request Update 📝"
        case .partyLocationUpdate(_, let partyTitle, _):
            return "Location Update 📍"
        case .partyTimeUpdate(_, let partyTitle, _):
            return "Time Change ⏰"
        case .hostMessage(_, let partyTitle, let hostName, _):
            return "Message from \(hostName) 💬"
        case .partyStartingSoon(_, let partyTitle, let minutesUntil):
            return "Party Starting Soon! 🚀"
        case .partyEnding(_, let partyTitle, let minutesLeft):
            return "Last Call! ⏰"
        // System
        case .systemMaintenance(_):
            return "Scheduled Maintenance 🔧"
        case .newFeatureAvailable(let featureName):
            return "New Feature: \(featureName) ✨"
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
        // Host notifications
        case .guestRequestReceived(_, let partyTitle, let guestName):
            return "\(guestName) wants to join \(partyTitle). Tap to review their request."
        case .guestApprovalDeadline(_, let partyTitle, let pendingCount):
            return "You have \(pendingCount) pending requests for \(partyTitle). Approve soon!"
        case .partyCapacityAlert(_, let partyTitle, let currentCount, let maxCount):
            return "\(partyTitle) is at \(currentCount)/\(maxCount) capacity. Consider closing requests!"
        case .partyStartReminder(_, let partyTitle, let hoursUntil):
            return "Don't forget to prep for \(partyTitle)! Make sure you're ready to host."
        case .paymentReceived(_, let partyTitle, let guestName, let amount):
            return "\(guestName) paid \(amount) for \(partyTitle). Check your Venmo!"
        // Guest notifications
        case .requestApproved(_, let partyTitle, let hostName):
            return "You're in! \(hostName) approved your request for \(partyTitle). Check party details."
        case .requestDenied(_, let partyTitle, let hostName):
            return "Your request for \(partyTitle) wasn't approved this time. Keep looking for other parties!"
        case .partyLocationUpdate(_, let partyTitle, let newLocation):
            return "\(partyTitle) location changed to \(newLocation). Update your plans!"
        case .partyTimeUpdate(_, let partyTitle, let newTime):
            return "\(partyTitle) time changed to \(newTime). Mark your calendar!"
        case .hostMessage(_, let partyTitle, let hostName, let message):
            return "\(message)"
        case .partyStartingSoon(_, let partyTitle, let minutesUntil):
            return "\(partyTitle) starts in \(minutesUntil) minutes! Time to head over."
        case .partyEnding(_, let partyTitle, let minutesLeft):
            return "\(partyTitle) ends in \(minutesLeft) minutes. Last chance to join!"
        // System
        case .systemMaintenance(let scheduledTime):
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            return "Bondfyr will be down for maintenance on \(formatter.string(from: scheduledTime))."
        case .newFeatureAvailable(let featureName):
            return "Try out \(featureName) in the latest app update!"
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
        // Host notifications
        case .guestRequestReceived(let partyId, _, _):
            return "guest-request-\(partyId)-\(UUID().uuidString)"
        case .guestApprovalDeadline(let partyId, _, _):
            return "approval-deadline-\(partyId)"
        case .partyCapacityAlert(let partyId, _, _, _):
            return "capacity-alert-\(partyId)"
        case .partyStartReminder(let partyId, _, _):
            return "party-start-reminder-\(partyId)"
        case .paymentReceived(let partyId, _, _, _):
            return "payment-received-\(partyId)-\(UUID().uuidString)"
        // Guest notifications
        case .requestApproved(let partyId, _, _):
            return "request-approved-\(partyId)"
        case .requestDenied(let partyId, _, _):
            return "request-denied-\(partyId)"
        case .partyLocationUpdate(let partyId, _, _):
            return "location-update-\(partyId)"
        case .partyTimeUpdate(let partyId, _, _):
            return "time-update-\(partyId)"
        case .hostMessage(let partyId, _, _, _):
            return "host-message-\(partyId)-\(UUID().uuidString)"
        case .partyStartingSoon(let partyId, _, _):
            return "party-starting-\(partyId)"
        case .partyEnding(let partyId, _, _):
            return "party-ending-\(partyId)"
        // System
        case .systemMaintenance(_):
            return "system-maintenance"
        case .newFeatureAvailable(let featureName):
            return "new-feature-\(featureName.lowercased().replacingOccurrences(of: " ", with: "-"))"
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
        // Host notifications
        case .guestRequestReceived(let partyId, let partyTitle, let guestName):
            return [
                "type": "guest_request_received",
                "partyId": partyId,
                "partyTitle": partyTitle,
                "guestName": guestName
            ]
        case .guestApprovalDeadline(let partyId, let partyTitle, let pendingCount):
            return [
                "type": "guest_approval_deadline",
                "partyId": partyId,
                "partyTitle": partyTitle,
                "pendingCount": pendingCount
            ]
        case .partyCapacityAlert(let partyId, let partyTitle, let currentCount, let maxCount):
            return [
                "type": "party_capacity_alert",
                "partyId": partyId,
                "partyTitle": partyTitle,
                "currentCount": currentCount,
                "maxCount": maxCount
            ]
        case .partyStartReminder(let partyId, let partyTitle, let hoursUntil):
            return [
                "type": "party_start_reminder",
                "partyId": partyId,
                "partyTitle": partyTitle,
                "hoursUntil": hoursUntil
            ]
        case .paymentReceived(let partyId, let partyTitle, let guestName, let amount):
            return [
                "type": "payment_received",
                "partyId": partyId,
                "partyTitle": partyTitle,
                "guestName": guestName,
                "amount": amount
            ]
        // Guest notifications
        case .requestApproved(let partyId, let partyTitle, let hostName):
            return [
                "type": "request_approved",
                "partyId": partyId,
                "partyTitle": partyTitle,
                "hostName": hostName
            ]
        case .requestDenied(let partyId, let partyTitle, let hostName):
            return [
                "type": "request_denied",
                "partyId": partyId,
                "partyTitle": partyTitle,
                "hostName": hostName
            ]
        case .partyLocationUpdate(let partyId, let partyTitle, let newLocation):
            return [
                "type": "party_location_update",
                "partyId": partyId,
                "partyTitle": partyTitle,
                "newLocation": newLocation
            ]
        case .partyTimeUpdate(let partyId, let partyTitle, let newTime):
            return [
                "type": "party_time_update",
                "partyId": partyId,
                "partyTitle": partyTitle,
                "newTime": newTime
            ]
        case .hostMessage(let partyId, let partyTitle, let hostName, let message):
            return [
                "type": "host_message",
                "partyId": partyId,
                "partyTitle": partyTitle,
                "hostName": hostName,
                "message": message
            ]
        case .partyStartingSoon(let partyId, let partyTitle, let minutesUntil):
            return [
                "type": "party_starting_soon",
                "partyId": partyId,
                "partyTitle": partyTitle,
                "minutesUntil": minutesUntil
            ]
        case .partyEnding(let partyId, let partyTitle, let minutesLeft):
            return [
                "type": "party_ending",
                "partyId": partyId,
                "partyTitle": partyTitle,
                "minutesLeft": minutesLeft
            ]
        // System
        case .systemMaintenance(let scheduledTime):
            return [
                "type": "system_maintenance",
                "scheduledTime": scheduledTime.timeIntervalSince1970
            ]
        case .newFeatureAvailable(let featureName):
            return [
                "type": "new_feature_available",
                "featureName": featureName
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
    

    func requestAuthorization() {
        print("🔔 SETUP: Requesting notification authorization...")
        
        self.notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("🟢 SETUP: Notification permission GRANTED")
                
                // Set default notification settings to true
                DispatchQueue.main.async {
                    let userDefaults = UserDefaults.standard
                    
                    // Only set defaults if they haven't been set before
                    if userDefaults.object(forKey: "notificationSettingsInitialized") == nil {
                        userDefaults.set(true, forKey: "eventReminders")
                        userDefaults.set(true, forKey: "partyUpdates")
                        userDefaults.set(true, forKey: "notificationSettingsInitialized")
                        print("🔔 SETUP: Default notification settings enabled")
                    }
                    
                    // Register for remote notifications
                    UIApplication.shared.registerForRemoteNotifications()
                    print("🔔 SETUP: Registered for remote notifications")
                }
            } else if let error = error {
                print("🔴 SETUP: Notification permission DENIED with error: \(error.localizedDescription)")
            } else {
                print("🔴 SETUP: Notification permission DENIED by user")
            }
        }
    }
    
    /// Check current notification permission status and settings
    func checkNotificationStatus() {
        print("🔔 CHECK: Checking notification status...")
        
        notificationCenter.getNotificationSettings { settings in
            print("🔔 CHECK: Authorization Status: \(settings.authorizationStatus.rawValue)")
            print("🔔 CHECK: Alert Setting: \(settings.alertSetting.rawValue)")
            print("🔔 CHECK: Badge Setting: \(settings.badgeSetting.rawValue)")
            print("🔔 CHECK: Sound Setting: \(settings.soundSetting.rawValue)")
            
            let userDefaults = UserDefaults.standard
            print("🔔 CHECK: Event Reminders Setting: \(userDefaults.bool(forKey: "eventReminders"))")
            print("🔔 CHECK: Party Updates Setting: \(userDefaults.bool(forKey: "partyUpdates"))")
            print("🔔 CHECK: Settings Initialized: \(userDefaults.bool(forKey: "notificationSettingsInitialized"))")
            
            if settings.authorizationStatus != .authorized {
                print("🔴 CHECK: Notifications NOT authorized - user needs to enable in Settings")
            } else {
                print("🟢 CHECK: Notifications properly authorized")
            }
        }
    }
    
    /// Send a test notification to verify the system is working
    func sendTestGuestRequestNotification() {
        print("🧪 TEST: Sending test guest request notification")
        
        scheduleGuestStatusNotification(
            title: "🧪 Test Notification",
            body: "This is a test notification to verify the system is working",
            partyId: "test-party-id",
            delaySeconds: 1
        )
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
                
            } else {
                
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
                
            }
        }
    }

    // Schedule reminder notification
    func scheduleEventReminder(for event: Event, hoursInAdvance: Int = 2) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM d, yyyy HH:mm"
        
        guard let eventDate = dateFormatter.date(from: "\(event.date) \(event.time)") else {
            
            return
        }
        
        let reminderTime = eventDate.addingTimeInterval(-Double(hoursInAdvance * 3600))
        
        // Only schedule if reminder time is in the future
        guard reminderTime > Date() else {
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = "Event Reminder: \(event.name)"
        content.body = "Your event at \(event.venue) starts in \(hoursInAdvance) hours!"
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
                
            }
        }
    }

    // MARK: - Local Notifications
    
    func scheduleLocalNotification(for notificationType: NotificationType, delaySeconds: TimeInterval = 0) {
        print("🔔 SCHEDULE: scheduleLocalNotification called for: \(notificationType.title)")
        print("🔔 SCHEDULE: Delay seconds: \(delaySeconds)")
        
        // Check if notifications are authorized
        self.notificationCenter.getNotificationSettings { settings in
            print("🔔 SCHEDULE: Authorization status: \(settings.authorizationStatus.rawValue)")
                
            guard settings.authorizationStatus == .authorized else {
                print("🔴 SCHEDULE: Notifications not authorized - status: \(settings.authorizationStatus.rawValue)")
                return
            }
            
            print("🟢 SCHEDULE: Notifications authorized, creating notification content...")
            
            // Create the notification content
            let content = UNMutableNotificationContent()
            content.title = notificationType.title
            content.body = notificationType.body
            content.sound = .default
            content.userInfo = notificationType.userInfo
            
            print("🔔 SCHEDULE: Notification content created")
            print("🔔 SCHEDULE: Title: \(content.title)")
            print("🔔 SCHEDULE: Body: \(content.body)")
            print("🔔 SCHEDULE: Identifier: \(notificationType.identifier)")
            
            // Create the trigger (time-based)
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, delaySeconds), repeats: false)
            
            // Create the notification request
            let request = UNNotificationRequest(
                identifier: notificationType.identifier,
                content: content,
                trigger: trigger
            )
            
            print("🔔 SCHEDULE: Adding notification request to center...")
            
            // Schedule the notification
            self.notificationCenter.add(request) { error in
                if let error = error {
                    print("🔴 SCHEDULE: Failed to schedule notification: \(error.localizedDescription)")
                } else {
                    print("🟢 SCHEDULE: Notification scheduled successfully!")
                }
            }
        }
    }
    
    // MARK: - Remote Notifications
    
    func registerDeviceToken(_ deviceToken: Data) {
        
        // The APNS token is already set in AppDelegate, so we don't need to do it again here
        // Just confirm it's set
        
    }
    
    // Add method to save FCM token after user signs in
    func saveFCMTokenIfNeeded() {
        
        
        // Check if we have a stored FCM token
        if let savedToken = UserDefaults.standard.string(forKey: "fcmToken"),
           let userId = Auth.auth().currentUser?.uid {
            
            saveFCMTokenToFirestore(token: savedToken, userId: userId)
        } else {
            
            // Request a new FCM token
            Messaging.messaging().token { token, error in
                if let error = error {
                    
                } else if let token = token {
                    
                    UserDefaults.standard.set(token, forKey: "fcmToken")
                    
                    if let userId = Auth.auth().currentUser?.uid {
                        self.saveFCMTokenToFirestore(token: token, userId: userId)
                    }
                }
            }
        }
    }
    
    private func saveFCMTokenToFirestore(token: String, userId: String) {
        
        
        let db = Firestore.firestore()
        let tokenData: [String: Any] = [
            "token": token,
            "device": "iOS",
            "platform": "ios",
            "lastUpdated": FieldValue.serverTimestamp(),
            "createdAt": FieldValue.serverTimestamp()
        ]
        
        // Save in both the old location and new location for compatibility
        db.collection("users").document(userId).collection("deviceTokens").document(token).setData(tokenData) { error in
            if let error = error {
                
            } else {
                
            }
        }
        
        // Also save in the fcmTokens collection as expected by the cloud function
        db.collection("users").document(userId).collection("fcmTokens").document(token).setData(tokenData) { error in
            if let error = error {
                
            } else {
                
            }
        }
    }

    private func saveTokenToFirestore(_ token: String) {
        guard let userId = Auth.auth().currentUser?.uid else {
            
            return
        }
        
        saveFCMTokenToFirestore(token: token, userId: userId)
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
                
                return
            }
            
            // 1. Send notification to all users with tickets for this event
            self.notifyCheckedInUsersAboutPhotoContest(eventId: eventId, eventName: eventName)
            
            // 2. Update event's contest status in Firestore
            EventService.shared.togglePhotoContest(eventId: eventId, active: true) { success, error in
                if let error = error {
                    
                } else {
                    
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
                
            } else {
                
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
                
            } else {
                
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

    func scheduleAfterpartyReminder(afterparty: Afterparty) {
        let content = UNMutableNotificationContent()
        content.title = "Afterparty Starting Soon! 🎉"
        content.body = "The afterparty at \(afterparty.locationName) starts in 30 minutes!"
        content.sound = .default
        
        // Schedule for 30 minutes before start time
        let triggerDate = afterparty.startTime.addingTimeInterval(-30 * 60)
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "afterparty-reminder-\(afterparty.id)",
            content: content,
            trigger: trigger
        )
        
        notificationCenter.add(request) { error in
            if let error = error {
                
            }
        }
    }
    
    func sendJoinRequestNotification(afterparty: Afterparty) {
        let content = UNMutableNotificationContent()
        content.title = "New Join Request 👋"
        content.body = "Someone wants to join your afterparty at \(afterparty.locationName)!"
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "join-request-\(afterparty.id)-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        
        notificationCenter.add(request) { error in
            if let error = error {
                
            }
        }
    }
    
    func sendRequestAcceptedNotification(afterparty: Afterparty) {
        let content = UNMutableNotificationContent()
        content.title = "Join Request Accepted! 🎉"
        content.body = "You've been accepted to join the afterparty at \(afterparty.locationName)!"
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "request-accepted-\(afterparty.id)-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        
        notificationCenter.add(request) { error in
            if let error = error {
                
            }
        }
    }
    
    func sendAfterpartyJoinNotification(afterparty: Afterparty) {
        let content = UNMutableNotificationContent()
        content.title = "New Afterparty Member! 🎉"
        content.body = "Someone new has joined your afterparty at \(afterparty.locationName)!"
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "afterparty-join-\(afterparty.id)-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        
        notificationCenter.add(request) { error in
            if let error = error {
                
            }
        }
    }
    
    // MARK: - Settings-Based Notification Methods
    
    func scheduleNotificationIfEnabled(type: NotificationType, delaySeconds: TimeInterval = 0) {
        print("🔔 NOTIFICATION: scheduleNotificationIfEnabled called for type: \(type.title)")
        
        // Check user settings before sending notification
        let userDefaults = UserDefaults.standard
        let shouldSend: Bool
        
        switch type {
        case .upcomingEvent, .partyStartReminder, .partyStartingSoon:
            shouldSend = userDefaults.bool(forKey: "eventReminders")
            print("🔔 NOTIFICATION: Event reminder setting: \(shouldSend)")
        case .guestRequestReceived, .partyLocationUpdate, .partyTimeUpdate, .hostMessage, .requestApproved, .requestDenied:
            shouldSend = userDefaults.bool(forKey: "partyUpdates")
            print("🔔 NOTIFICATION: Party updates setting: \(shouldSend)")
            print("🔔 NOTIFICATION: UserDefaults partyUpdates key value: \(userDefaults.object(forKey: "partyUpdates") ?? "nil")")
        default:
            shouldSend = true // Always send system notifications
            print("🔔 NOTIFICATION: System notification - always send")
        }
        
        print("🔔 NOTIFICATION: Final shouldSend decision: \(shouldSend)")
        
        if shouldSend {
            print("🟢 NOTIFICATION: Sending notification")
            scheduleLocalNotification(for: type, delaySeconds: delaySeconds)
        } else {
            print("🔴 NOTIFICATION: Notification disabled in settings")
        }
    }
    
    // MARK: - Host Notification Methods
    
    func notifyHostOfGuestRequest(partyId: String, partyTitle: String, guestName: String) {
        print("🔔 NOTIFICATION: notifyHostOfGuestRequest called")
        print("🔔 NOTIFICATION: Party: \(partyTitle), Guest: \(guestName)")
        print("🔔 NOTIFICATION: PartyId: \(partyId)")
        
        // Check notification permissions first
        notificationCenter.getNotificationSettings { settings in
            print("🔔 NOTIFICATION: Authorization status: \(settings.authorizationStatus.rawValue)")
            print("🔔 NOTIFICATION: Alert setting: \(settings.alertSetting.rawValue)")
            print("🔔 NOTIFICATION: Badge setting: \(settings.badgeSetting.rawValue)")
            print("🔔 NOTIFICATION: Sound setting: \(settings.soundSetting.rawValue)")
            
            DispatchQueue.main.async {
        let notification = NotificationType.guestRequestReceived(partyId: partyId, partyTitle: partyTitle, guestName: guestName)
                self.scheduleNotificationIfEnabled(type: notification)
            }
        }
    }
    
    func notifyHostOfCapacityAlert(partyId: String, partyTitle: String, currentCount: Int, maxCount: Int) {
        let notification = NotificationType.partyCapacityAlert(partyId: partyId, partyTitle: partyTitle, currentCount: currentCount, maxCount: maxCount)
        scheduleNotificationIfEnabled(type: notification)
    }
    
    func notifyHostOfApprovalDeadline(partyId: String, partyTitle: String, pendingCount: Int) {
        let notification = NotificationType.guestApprovalDeadline(partyId: partyId, partyTitle: partyTitle, pendingCount: pendingCount)
        scheduleNotificationIfEnabled(type: notification)
    }
    
    func notifyHostOfPayment(partyId: String, partyTitle: String, guestName: String, amount: String) {
        let notification = NotificationType.paymentReceived(partyId: partyId, partyTitle: partyTitle, guestName: guestName, amount: amount)
        scheduleNotificationIfEnabled(type: notification)
    }
    
    func schedulePartyStartReminder(partyId: String, partyTitle: String, startTime: Date) {
        let hoursUntil = Int(startTime.timeIntervalSinceNow / 3600)
        let notification = NotificationType.partyStartReminder(partyId: partyId, partyTitle: partyTitle, hoursUntil: hoursUntil)
        
        // Schedule for 2 hours before start time
        let reminderTime = startTime.addingTimeInterval(-2 * 3600)
        let delaySeconds = reminderTime.timeIntervalSinceNow
        
        if delaySeconds > 0 {
            scheduleNotificationIfEnabled(type: notification, delaySeconds: delaySeconds)
        }
    }
    
    // MARK: - Guest Notification Methods
    
    func notifyGuestOfApproval(partyId: String, partyTitle: String, hostName: String) {
        let notification = NotificationType.requestApproved(partyId: partyId, partyTitle: partyTitle, hostName: hostName)
        scheduleNotificationIfEnabled(type: notification)
    }
    
    func notifyGuestOfDenial(partyId: String, partyTitle: String, hostName: String) {
        let notification = NotificationType.requestDenied(partyId: partyId, partyTitle: partyTitle, hostName: hostName)
        scheduleNotificationIfEnabled(type: notification)
    }
    
    func notifyGuestOfLocationUpdate(partyId: String, partyTitle: String, newLocation: String) {
        let notification = NotificationType.partyLocationUpdate(partyId: partyId, partyTitle: partyTitle, newLocation: newLocation)
        scheduleNotificationIfEnabled(type: notification)
    }
    
    func notifyGuestOfTimeUpdate(partyId: String, partyTitle: String, newTime: String) {
        let notification = NotificationType.partyTimeUpdate(partyId: partyId, partyTitle: partyTitle, newTime: newTime)
        scheduleNotificationIfEnabled(type: notification)
    }
    
    func sendHostMessage(partyId: String, partyTitle: String, hostName: String, message: String) {
        let notification = NotificationType.hostMessage(partyId: partyId, partyTitle: partyTitle, hostName: hostName, message: message)
        scheduleNotificationIfEnabled(type: notification)
    }
    
    func schedulePartyStartingSoonNotification(partyId: String, partyTitle: String, startTime: Date) {
        let notification = NotificationType.partyStartingSoon(partyId: partyId, partyTitle: partyTitle, minutesUntil: 30)
        
        // Schedule for 30 minutes before start time
        let reminderTime = startTime.addingTimeInterval(-30 * 60)
        let delaySeconds = reminderTime.timeIntervalSinceNow
        
        if delaySeconds > 0 {
            scheduleNotificationIfEnabled(type: notification, delaySeconds: delaySeconds)
        }
    }
    
    func schedulePartyEndingNotification(partyId: String, partyTitle: String, endTime: Date) {
        let notification = NotificationType.partyEnding(partyId: partyId, partyTitle: partyTitle, minutesLeft: 30)
        
        // Schedule for 30 minutes before end time
        let reminderTime = endTime.addingTimeInterval(-30 * 60)
        let delaySeconds = reminderTime.timeIntervalSinceNow
        
        if delaySeconds > 0 {
            scheduleNotificationIfEnabled(type: notification, delaySeconds: delaySeconds)
        }
    }
    
    // MARK: - System Notifications
    
    func scheduleMaintenanceNotification(scheduledTime: Date) {
        let notification = NotificationType.systemMaintenance(scheduledTime: scheduledTime)
        
        // Schedule for 24 hours before maintenance
        let reminderTime = scheduledTime.addingTimeInterval(-24 * 3600)
        let delaySeconds = reminderTime.timeIntervalSinceNow
        
        if delaySeconds > 0 {
            scheduleLocalNotification(for: notification, delaySeconds: delaySeconds)
        }
    }
    
    func announceNewFeature(featureName: String) {
        let notification = NotificationType.newFeatureAvailable(featureName: featureName)
        scheduleLocalNotification(for: notification, delaySeconds: 2)
    }

    // MARK: - Enhanced Guest Flow Notifications
    
    func scheduleGuestStatusNotification(title: String, body: String, partyId: String, delaySeconds: TimeInterval = 0) {
        print("🔔 GUEST: Scheduling guest status notification")
        print("🔔 GUEST: Title: \(title)")
        print("🔔 GUEST: Body: \(body)")
        print("🔔 GUEST: Party ID: \(partyId)")
        
        // Check if notifications are authorized first
        self.notificationCenter.getNotificationSettings { settings in
            print("🔔 GUEST: Authorization status: \(settings.authorizationStatus.rawValue)")
            
            guard settings.authorizationStatus == .authorized else {
                print("🔴 GUEST: Notifications not authorized - requesting permission")
                DispatchQueue.main.async {
                    self.requestAuthorization()
                }
                return
            }
            
            print("🟢 GUEST: Notifications authorized, creating notification...")
            
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = UNNotificationSound.default
            content.badge = 1
            
            // Rich notification data for deep linking
            content.userInfo = [
                "partyId": partyId,
                "type": "guest_status_update",
                "timestamp": Date().timeIntervalSince1970,
                "action": "open_party"
            ]
            
            // Add notification category for interactive actions
            content.categoryIdentifier = "GUEST_STATUS"
            
            // Create trigger
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(delaySeconds, 1), repeats: false)
            
            // Create request with unique identifier
            let requestId = "guest_status_\(partyId)_\(Int(Date().timeIntervalSince1970))"
            let request = UNNotificationRequest(identifier: requestId, content: content, trigger: trigger)
            
            // Schedule notification
            self.notificationCenter.add(request) { error in
                if let error = error {
                    print("🔴 GUEST: Error scheduling notification: \(error)")
                } else {
                    print("🟢 GUEST: Successfully scheduled notification with ID: \(requestId)")
                }
            }
        }
    }
    
    func setupNotificationCategories() {
        print("🔔 SETUP: Setting up notification categories")
        
        // Guest status category
        let viewPartyAction = UNNotificationAction(
            identifier: "VIEW_PARTY",
            title: "View Party",
            options: [.foreground]
        )
        
        let joinChatAction = UNNotificationAction(
            identifier: "JOIN_CHAT",
            title: "Join Chat",
            options: [.foreground]
        )
        
        let guestStatusCategory = UNNotificationCategory(
            identifier: "GUEST_STATUS",
            actions: [viewPartyAction, joinChatAction],
            intentIdentifiers: [],
            options: []
        )
        
        // Host approval category
        let approveAction = UNNotificationAction(
            identifier: "APPROVE_GUEST",
            title: "Approve",
            options: [.foreground]
        )
        
        let denyAction = UNNotificationAction(
            identifier: "DENY_GUEST",
            title: "Deny",
            options: [.destructive]
        )
        
        let hostApprovalCategory = UNNotificationCategory(
            identifier: "HOST_APPROVAL",
            actions: [approveAction, denyAction],
            intentIdentifiers: [],
            options: []
        )
        
        notificationCenter.setNotificationCategories([guestStatusCategory, hostApprovalCategory])
        print("🟢 SETUP: Notification categories configured")
    }
    
    // MARK: - Enhanced Host Notifications
    
    func sendHostGuestRequestNotification(partyId: String, partyTitle: String, guestName: String) {
        print("🔔 HOST: Sending host guest request notification")
        print("🔔 HOST: Party: \(partyTitle)")
        print("🔔 HOST: Guest: \(guestName)")
        
        scheduleGuestStatusNotification(
            title: "🎉 New Guest Request",
            body: "\(guestName) wants to join \(partyTitle)",
            partyId: partyId,
            delaySeconds: 0
        )
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
                    NotificationCenter.default.post(
                        name: Notification.Name("NavigateToPhotoContest"),
                        object: nil,
                        userInfo: userInfo
                    )
                }
            case "new_event", "upcoming_event":
                if let eventId = userInfo["eventId"] as? String {
                    NotificationCenter.default.post(
                        name: Notification.Name("NavigateToEvent"),
                        object: nil,
                        userInfo: userInfo
                    )
                }
            case "ticket_confirmation":
                if let ticketId = userInfo["ticketId"] as? String {
                    NotificationCenter.default.post(
                        name: Notification.Name("NavigateToTicket"),
                        object: nil,
                        userInfo: userInfo
                    )
                }
            // Host notification handlers
            case "guest_request_received", "guest_approval_deadline", "party_capacity_alert", "payment_received":
                if let partyId = userInfo["partyId"] as? String {
                    NotificationCenter.default.post(
                        name: Notification.Name("NavigateToHostDashboard"),
                        object: nil,
                        userInfo: ["partyId": partyId]
                    )
                }
            case "party_start_reminder":
                if let partyId = userInfo["partyId"] as? String {
                    NotificationCenter.default.post(
                        name: Notification.Name("NavigateToPartyDetails"),
                        object: nil,
                        userInfo: ["partyId": partyId, "action": "prep"]
                    )
                }
            // Guest notification handlers
            case "request_approved", "request_denied":
                if let partyId = userInfo["partyId"] as? String {
                    NotificationCenter.default.post(
                        name: Notification.Name("NavigateToPartyDetails"),
                        object: nil,
                        userInfo: ["partyId": partyId]
                    )
                }
            case "party_location_update", "party_time_update", "host_message":
                if let partyId = userInfo["partyId"] as? String {
                    NotificationCenter.default.post(
                        name: Notification.Name("NavigateToPartyDetails"),
                        object: nil,
                        userInfo: ["partyId": partyId, "action": "update"]
                    )
                }
            case "party_starting_soon":
                if let partyId = userInfo["partyId"] as? String {
                    NotificationCenter.default.post(
                        name: Notification.Name("NavigateToPartyDetails"),
                        object: nil,
                        userInfo: ["partyId": partyId, "action": "directions"]
                    )
                }
            case "party_ending":
                if let partyId = userInfo["partyId"] as? String {
                    NotificationCenter.default.post(
                        name: Notification.Name("NavigateToPartyDetails"),
                        object: nil,
                        userInfo: ["partyId": partyId, "action": "ending"]
                    )
                }
            // System handlers
            case "system_maintenance":
                NotificationCenter.default.post(
                    name: Notification.Name("ShowMaintenanceInfo"),
                    object: nil,
                    userInfo: userInfo
                )
            case "new_feature_available":
                NotificationCenter.default.post(
                    name: Notification.Name("ShowFeatureAnnouncement"),
                    object: nil,
                    userInfo: userInfo
                )
            default:
                break
            }
        }
        
        completionHandler()
    }
}


