//
//  NotificationManager.swift
//  Bondfyr
//
//  Created by Arjun Varma on 31/03/25.
//

import Foundation
import UserNotifications
import SwiftUI
import FirebaseFirestore

class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    private let notificationCenter = UNUserNotificationCenter.current()
    
    override init() {
        super.init()
        notificationCenter.delegate = self  // Set delegate in init
        
        // Check authorization status on initialization
        checkNotificationStatus()
    }
    
    private func checkNotificationStatus() {
        notificationCenter.getNotificationSettings { settings in
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
        notificationCenter.requestAuthorization(options: [.alert, .sound, .badge, .provisional]) { granted, error in
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

    func schedulePhotoNotification(forEvent eventName: String) {
        let content = UNMutableNotificationContent()
        content.title = "Time to Capture the Moment!"
        content.body = "You have 3 minutes to capture and upload a photo for \(eventName)."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 10, repeats: false) // 10 sec for testing

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
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
        
        notificationCenter.add(request) { error in
            if let error = error {
                print("Error scheduling event reminder: \(error.localizedDescription)")
            }
        }
    }

    // Handle Notification Clicks
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        print("Notification Clicked: \(response.notification.request.content.body)")
        
        let userInfo = response.notification.request.content.userInfo
        
        DispatchQueue.main.async {
            if let type = userInfo["type"] as? String, type == "contest" {
                // Contest notification
                NotificationCenter.default.post(
                    name: NSNotification.Name("NavigateToContestPhotoCapture"), 
                    object: nil,
                    userInfo: userInfo
                )
            } else {
                // Regular photo notification
                NotificationCenter.default.post(name: NSNotification.Name("NavigateToPhotoCaptureView"), object: nil)
            }
        }
        completionHandler()
    }

    // Ensure notifications work in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}


