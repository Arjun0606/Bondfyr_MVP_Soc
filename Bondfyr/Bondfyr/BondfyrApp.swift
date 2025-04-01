//
//  BondfyrApp.swift
//  Bondfyr
//
//  Created by Arjun Varma on 24/03/25.
//

import SwiftUI
import Firebase

@main
struct BondfyrApp: App {
    @StateObject var authViewModel = AuthViewModel()
    @StateObject var tabSelection = TabSelection()

    init() {
        FirebaseApp.configure()
        NotificationManager.shared.requestPermission()
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
                        window.rootViewController = UIHostingController(rootView:
                            PhotoCaptureView(onCapture: { capturedImage in
                                print("Captured Image: \(capturedImage)")
                                
                                guard let imageData = capturedImage.jpegData(compressionQuality: 0.8) else {
                                    print("Failed to convert image to data")
                                    return
                                }

                                // Upload photo using PhotoManager
                                PhotoManager.shared.uploadPhoto(imageData: imageData, eventId: "EventName") { success in
                                    if success {
                                        print("Photo uploaded successfully.")
                                    } else {
                                        print("Failed to upload photo.")
                                    }
                                }
                            })
                        )
                        window.makeKeyAndVisible()
                    }
                }
        }
    }
}
