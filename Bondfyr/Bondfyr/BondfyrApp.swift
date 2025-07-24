//
//  BondfyrApp.swift
//  Bondfyr
//
//  Created by Arjun Varma on 24/03/25.
//

import SwiftUI
import Firebase
import UIKit
import FirebaseAppCheck
import UserNotifications
import FirebaseMessaging
import FirebaseAuth
import FirebaseFirestore

@main
struct BondfyrApp: App {
    @StateObject var authViewModel = AuthViewModel()
    @StateObject var tabSelection = TabSelection()
    @StateObject var eventViewModel = EventViewModel()
    @StateObject var cityManager = CityManager.shared
    @StateObject var fcmManager = FCMNotificationManager.shared // NEW: FCM push notifications
    @UIApplicationDelegateAdaptor private var appDelegate: AppDelegate
    
    // Add state variables to manage navigation
    @State private var showContestPhotoCapture = false
    @State private var contestEventId: String? = nil
    @State private var contestEventName: String? = nil
    @State private var pendingNavigationEventId: String? = nil
    @State private var pendingNavigationAction: String? = nil

    init() {
        FirebaseApp.configure()
        
        // Enable Firestore persistence for offline use
        let settings = Firestore.firestore().settings
        settings.isPersistenceEnabled = true
        Firestore.firestore().settings = settings
        
        // Enable AppCheck for production
        let providerFactory = DeviceCheckProviderFactory()
        AppCheck.setAppCheckProviderFactory(providerFactory)
        
        // FIXED: Use new notification system instead of broken one
        Task {
            _ = await FixedNotificationManager.shared.requestPermissions()
        }
        
        // Initialize the party chat manager
        _ = PartyChatManager.shared
        
        // Initialize new managers
        _ = OfflineDataManager.shared
        _ = CalendarManager.shared
        
        // Start network monitoring
        NetworkMonitor.shared.startMonitoring()
        
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
        
        // Listen for event navigation
        setupEventNavigationListener()
    }
    
    func setupContestPhotoNotificationListener() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("NavigateToContestPhotoCapture"),
            object: nil,
            queue: .main
        ) { notification in
            if let userInfo = notification.userInfo,
               let eventId = userInfo["eventId"] as? String,
               let eventName = userInfo["eventName"] as? String {
                self.contestEventId = eventId
                self.contestEventName = eventName
                self.showContestPhotoCapture = true
            }
        }
    }
    
    func setupEventNavigationListener() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("NavigateToEvent"),
            object: nil,
            queue: .main
        ) { notification in
            if let userInfo = notification.userInfo,
               let eventId = userInfo["eventId"] as? String {
                // Save the eventId to navigate to once the tab switches
                self.pendingNavigationEventId = eventId
                self.pendingNavigationAction = userInfo["action"] as? String
                
                // Switch to the party feed tab which contains events
                DispatchQueue.main.async {
                    self.tabSelection.selectedTab = .partyFeed
                }
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                SplashView()
                    .environmentObject(authViewModel)
                    .environmentObject(tabSelection)
                    .environmentObject(eventViewModel)
                    .environmentObject(cityManager)
                    .environment(\.pendingEventNavigation, pendingNavigationEventId)
                    .environment(\.pendingEventAction, pendingNavigationAction)
                    .preferredColorScheme(.dark)
                    .onReceive(NotificationCenter.default.publisher(for: UIScene.didActivateNotification)) { _ in
                        // Force dark mode whenever any scene becomes active
                        DispatchQueue.main.async {
                            UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.forEach { windowScene in
                                windowScene.windows.forEach { window in
                                    window.overrideUserInterfaceStyle = .dark
                                }
                            }
                        }
                    } // Force dark mode always
                    .onChange(of: pendingNavigationEventId) { newValue in
                        if newValue != nil {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                self.pendingNavigationEventId = nil
                                self.pendingNavigationAction = nil
                            }
                        }
                    }
                    .onAppear {
                        // Start location monitoring when app launches
                        cityManager.startMonitoringLocation()
                    }
                
                // Contest photo capture overlay
                if showContestPhotoCapture, let eventId = contestEventId {
                    ContestPhotoCaptureView(eventId: eventId)
                        .transition(.opacity)
                        .zIndex(100) // Ensure it's on top
                        .onDisappear {
                            self.showContestPhotoCapture = false
                        }
                }
            }
            .onAppear {
                // Trigger events to load when app appears
                eventViewModel.fetchEvents()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToContestPhotoCapture"))) { notification in
                if let userInfo = notification.userInfo,
                   let eventId = userInfo["eventId"] as? String {
                    self.contestEventId = eventId
                    if let eventName = userInfo["eventName"] as? String {
                        self.contestEventName = eventName
                    }
                    DispatchQueue.main.async {
                        self.showContestPhotoCapture = true
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToEvent"))) { notification in
                if let userInfo = notification.userInfo,
                   let eventId = userInfo["eventId"] as? String {
                    // If we were showing the photo capture view, hide it
                    if self.showContestPhotoCapture {
                        self.showContestPhotoCapture = false
                    }
                    
                    // Navigate to party feed tab which shows events
                    DispatchQueue.main.async {
                        self.tabSelection.selectedTab = .partyFeed
                    }
                }
            }
        }
    }
}

// Add app delegate to handle notifications
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {
    
    // Force dark mode when scenes connect
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        // Don't set delegateClass - let SwiftUI handle the scene lifecycle
        return configuration
    }
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        
        // Force dark mode for the entire app
        DispatchQueue.main.async {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                for window in windowScene.windows {
                    window.overrideUserInterfaceStyle = .dark
                }
            }
            
            // Also force dark mode on any future windows
            UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.forEach { windowScene in
                windowScene.windows.forEach { window in
                    window.overrideUserInterfaceStyle = .dark
                }
            }
        }
        
        // Set notification delegate
        UNUserNotificationCenter.current().delegate = self
        
        // Configure Firebase Messaging
        Messaging.messaging().delegate = self
        
        // Enable automatic Firebase Messaging init now that we have proper setup
        Messaging.messaging().isAutoInitEnabled = true
        
        // Don't force FCM token generation yet - wait for APNS token first
        
        
        // Check notification authorization status
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            
            if settings.authorizationStatus == .notDetermined {
                // FIXED: Use new notification system
                Task {
                    _ = await FixedNotificationManager.shared.requestPermissions()
                }
            } else if settings.authorizationStatus != .authorized {
                
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
        // Set the APNS token in Firebase Messaging FIRST
        Messaging.messaging().apnsToken = deviceToken
        
        // Now we can safely request the FCM token
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            Messaging.messaging().token { token, error in
                if let token = token {
                    UserDefaults.standard.set(token, forKey: "fcmToken")
                    
                    // Save to Firestore if user is signed in
                    if let userId = Auth.auth().currentUser?.uid {
                        self.saveFCMTokenToFirestore(token: token, userId: userId)
                    }
                }
            }
        }
        
        // REMOVED: Old notification manager call - using FixedNotificationManager instead
        // NotificationManager.shared.registerDeviceToken(deviceToken)
    }
    
    // Handle registration errors
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // Silent handling for production
    }
    
    // MARK: - MessagingDelegate
    
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        // Always save the token locally when received
        if let token = fcmToken {
            UserDefaults.standard.set(token, forKey: "fcmToken")
            
            // Try to save to Firestore if user is signed in
            if let userId = Auth.auth().currentUser?.uid {
                saveFCMTokenToFirestore(token: token, userId: userId)
            }
            
            // Notify the app about this new token
            NotificationCenter.default.post(
                name: Notification.Name("FCMTokenReceived"),
                object: nil,
                userInfo: ["token": token]
            )
        }
    }
    
    private func saveFCMTokenToFirestore(token: String, userId: String) {
        Firestore.firestore().collection("users").document(userId)
            .collection("fcmTokens").document(token).setData([
                "token": token,
                "createdAt": Timestamp(),
                "deviceType": "iOS"
            ])
    }
    
    // Handle notification when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .badge])
    }
    
    // Handle notification taps
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        // Process notification tap
        let userInfo = response.notification.request.content.userInfo
        
        // If it's a test notification or contest notification, handle it
        if response.notification.request.identifier.contains("testNotification") || 
           (userInfo["type"] as? String) == "contest_active" {
            
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
        }
    }
}
