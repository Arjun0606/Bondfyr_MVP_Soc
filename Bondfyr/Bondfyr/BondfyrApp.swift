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

@main
struct BondfyrApp: App {
    @StateObject var authViewModel = AuthViewModel()
    @StateObject var tabSelection = TabSelection()
    @UIApplicationDelegateAdaptor private var appDelegate: AppDelegate

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
    }

    var body: some Scene {
        WindowGroup {
            SplashView()
                .environmentObject(authViewModel)
                .environmentObject(tabSelection)
                .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToPhotoCaptureView"))) { _ in
                    if let windowScene = UIApplication.shared.connectedScenes
                        .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
                       let window = windowScene.windows.first {
                        // Handle navigation to photo capture view
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToContestPhotoCapture"))) { notification in
                    if let windowScene = UIApplication.shared.connectedScenes
                        .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
                       let window = windowScene.windows.first {
                        
                        if let userInfo = notification.userInfo,
                           let eventId = userInfo["eventId"] as? String {
                            window.rootViewController = UIHostingController(rootView:
                                ContestPhotoCaptureView(eventId: eventId)
                            )
                            window.makeKeyAndVisible()
                        }
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToContestGallery"))) { notification in
                    if let windowScene = UIApplication.shared.connectedScenes
                        .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
                       let window = windowScene.windows.first {
                        
                        if let userInfo = notification.userInfo,
                           let eventId = userInfo["eventId"] as? String {
                            // Get event name
                            let eventName = sampleEvents.first(where: { $0.id.uuidString == eventId })?.name ?? "Event"
                            
                            let contestGalleryView = ContestPhotoGalleryView(eventId: eventId, eventName: eventName)
                            
                            window.rootViewController = UIHostingController(rootView:
                                contestGalleryView
                            )
                            window.makeKeyAndVisible()
                        }
                    }
                }
        }
    }
}

// Add app delegate to handle notifications
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        
        // Set notification delegate
        UNUserNotificationCenter.current().delegate = self
        
        return true
    }
    
    // Handle notification when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .badge])
    }
}
