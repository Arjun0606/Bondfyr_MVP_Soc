//
//  BondfyrApp.swift
//  Bondfyr
//
//  Created by Arjun Varma on 24/03/25.
//

import SwiftUI
import Firebase
import FirebaseAppCheck
import UserNotifications
import FirebaseMessaging
import FirebaseAuth
import FirebaseFirestore

@main
struct BondfyrApp: App {
    @StateObject var authViewModel = AuthViewModel()
    @StateObject var tabSelection = TabSelection()
    @UIApplicationDelegateAdaptor private var appDelegate: AppDelegate
    
    // Add state variables to manage navigation
    @State private var showContestPhotoCapture = false
    @State private var contestEventId: String? = nil
    @State private var contestEventName: String? = nil

    init() {
        FirebaseApp.configure()
        
        // Temporarily disable AppCheck for development
        // Comment this back in when you've registered your app in Firebase console
        /*
        let providerFactory = DeviceCheckProviderFactory()
        AppCheck.setAppCheckProviderFactory(providerFactory)
        */
        
        // Request notifications at startup
        NotificationManager.shared.requestAuthorization()
        
        // Initialize the chat manager
        _ = ChatManager.shared
        
        // Initialize new managers
        _ = OfflineDataManager.shared
        _ = CalendarManager.shared
        
        // Cache all events for offline use if no cache exists
        if !OfflineDataManager.shared.hasCachedData() {
            OfflineDataManager.shared.cacheEvents(sampleEvents)
            
            // Cache individual venue info
            for event in sampleEvents {
                OfflineDataManager.shared.cacheVenueInfo(for: event)
            }
        }
        
        // Listen for contest photo notifications
        setupContestPhotoNotificationListener()
    }
    
    func setupContestPhotoNotificationListener() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("NavigateToContestPhotoCapture"),
            object: nil,
            queue: .main
        ) { notification in
            print("Received NavigateToContestPhotoCapture notification")
            if let userInfo = notification.userInfo,
               let eventId = userInfo["eventId"] as? String,
               let eventName = userInfo["eventName"] as? String {
                self.contestEventId = eventId
                self.contestEventName = eventName
                self.showContestPhotoCapture = true
                print("Setting showContestPhotoCapture to true for event: \(eventName)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                SplashView()
                    .environmentObject(authViewModel)
                    .environmentObject(tabSelection)
                
                // Contest photo capture overlay
                if showContestPhotoCapture, let eventId = contestEventId {
                    ContestPhotoCaptureView(eventId: eventId)
                        .transition(.opacity)
                        .zIndex(100) // Ensure it's on top
                        .onDisappear {
                            print("ContestPhotoCaptureView disappeared")
                            self.showContestPhotoCapture = false
                        }
                }
            }
            .onAppear {
                print("App body appeared")
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToContestPhotoCapture"))) { notification in
                print("Received NavigateToContestPhotoCapture notification in body")
                if let userInfo = notification.userInfo,
                   let eventId = userInfo["eventId"] as? String {
                    print("Setting contestEventId to: \(eventId)")
                    self.contestEventId = eventId
                    if let eventName = userInfo["eventName"] as? String {
                        self.contestEventName = eventName
                    }
                    DispatchQueue.main.async {
                        self.showContestPhotoCapture = true
                        print("Set showContestPhotoCapture to true")
                    }
                } else {
                    // If no event ID is provided, use a default one for testing
                    print("No event ID found in notification, using a default")
                    self.contestEventId = "default-event-id"
                    self.contestEventName = "Default Event"
                    DispatchQueue.main.async {
                        self.showContestPhotoCapture = true
                        print("Set showContestPhotoCapture to true with default values")
                    }
                }
            }
        }
    }
}

// Add app delegate to handle notifications
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        
        // Set notification delegate
        UNUserNotificationCenter.current().delegate = self
        
        // Configure Firebase Messaging
        Messaging.messaging().delegate = self
        
        // Check notification authorization status
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            print("📱 Current notification settings: \(settings.authorizationStatus.rawValue)")
            if settings.authorizationStatus == .notDetermined {
                print("📱 Notification permission not determined, requesting...")
                NotificationManager.shared.requestAuthorization()
            } else if settings.authorizationStatus != .authorized {
                print("📱 Notification permission not authorized, alerting user...")
                DispatchQueue.main.async {
                    // Show alert to instruct user to enable notifications in settings
                    let alertController = UIAlertController(
                        title: "Enable Notifications",
                        message: "Notifications are disabled. Please enable them in Settings to receive important updates.",
                        preferredStyle: .alert
                    )
                    
                    alertController.addAction(UIAlertAction(title: "Settings", style: .default) { _ in
                        if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(settingsURL)
                        }
                    })
                    
                    alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))
                    
                    // Present the alert
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let rootVC = windowScene.windows.first?.rootViewController {
                        rootVC.present(alertController, animated: true)
                    }
                }
            } else {
                // Permission already granted, register for remote notifications
                DispatchQueue.main.async {
                    application.registerForRemoteNotifications()
                }
            }
        }
        
        return true
    }
    
    // Handle device token registration
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        print("📱 Successfully registered for remote notifications with token")
        // Pass the token to NotificationManager
        NotificationManager.shared.registerDeviceToken(deviceToken)
    }
    
    // Handle registration errors
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("📱 Failed to register for remote notifications: \(error.localizedDescription)")
    }
    
    // MARK: - MessagingDelegate
    
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("📱 Firebase registration token: \(fcmToken ?? "nil")")
        
        // Store this token for sending FCM messages to this specific device
        if let token = fcmToken, let userId = Auth.auth().currentUser?.uid {
            let dataDict: [String: String] = ["token": token]
            
            // Save to Firestore
            Firestore.firestore().collection("users").document(userId)
                .collection("fcmTokens").document(token).setData([
                    "token": token,
                    "createdAt": Timestamp(),
                    "deviceType": "iOS"
                ])
            
            // You can also save to local storage if needed
            UserDefaults.standard.set(token, forKey: "fcmToken")
            
            // Notify the app about this new token
            NotificationCenter.default.post(
                name: Notification.Name("FCMTokenReceived"),
                object: nil,
                userInfo: ["token": token]
            )
        }
    }
    
    // Handle notification when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        print("📱 Received notification in foreground")
        completionHandler([.banner, .sound, .badge])
    }
    
    // Handle notification taps
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        print("📱 User tapped notification: \(response.notification.request.identifier)")
        
        // Process notification tap
        let userInfo = response.notification.request.content.userInfo
        print("📱 Notification userInfo: \(userInfo)")
        
        // If it's a test notification or contest notification, handle it
        if response.notification.request.identifier.contains("testNotification") || 
           (userInfo["type"] as? String) == "contest_active" {
            print("📱 Contest notification tapped, will open camera")
            
            // Extract event info from userInfo
            let eventId = userInfo["eventId"] as? String ?? "default-event-id"
            let eventName = userInfo["eventName"] as? String ?? "Test Event"
            
            // First, dismiss any presented controllers
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                if rootVC.presentedViewController != nil {
                    rootVC.dismiss(animated: true) {
                        // Post notification to open contest photo view after dismissing
                        self.postContestCaptureNotification(eventId: eventId, eventName: eventName)
                    }
                } else {
                    // No controller is presented, post notification directly
                    self.postContestCaptureNotification(eventId: eventId, eventName: eventName)
                }
            } else {
                // Fallback if we can't find the root view controller
                self.postContestCaptureNotification(eventId: eventId, eventName: eventName)
            }
        }
        
        completionHandler()
    }
    
    // Helper method to post the notification for contest photo capture
    private func postContestCaptureNotification(eventId: String, eventName: String) {
        DispatchQueue.main.async {
            print("📱 Posting NavigateToContestPhotoCapture with eventId: \(eventId)")
            
            // First, clear any existing state that might interfere
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                if rootVC.presentedViewController != nil {
                    rootVC.dismiss(animated: false)
                }
            }
            
            // Then post notification to open the contest camera
            NotificationCenter.default.post(
                name: NSNotification.Name("NavigateToContestPhotoCapture"),
                object: nil,
                userInfo: [
                    "eventId": eventId,
                    "eventName": eventName,
                    "timestamp": Date().timeIntervalSince1970  // Add timestamp to ensure uniqueness
                ]
            )
            
            // Log to verify the notification was posted
            print("📱 Posted NavigateToContestPhotoCapture notification with eventId: \(eventId)")
        }
    }
}
