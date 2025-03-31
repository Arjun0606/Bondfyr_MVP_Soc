//
//  NotificationManager.swift
//  Bondfyr
//
//  Created by Arjun Varma on 31/03/25.
//

import Foundation
import UserNotifications
import SwiftUI

class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error)")
            }
        }
        UNUserNotificationCenter.current().delegate = self
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

    // Handle Notification Clicks
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        print("Notification Clicked: \(response.notification.request.content.body)")
        
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: NSNotification.Name("NavigateToPhotoCaptureView"), object: nil)
        }
        completionHandler()
    }

    // Ensure notifications work in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}

