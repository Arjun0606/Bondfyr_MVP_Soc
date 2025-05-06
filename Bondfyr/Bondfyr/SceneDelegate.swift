import UIKit
import SwiftUI

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = UIHostingController(rootView: ContentView())
        self.window = window
        window.makeKeyAndVisible()
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else { return }
        
        // Handle OAuth callbacks
        if url.scheme == "bondfyr" {
            if url.host == "auth" {
                if url.path.contains("snapchat") {
                    handleSnapchatCallback(url: url)
                } else if url.path.contains("instagram") {
                    handleInstagramCallback(url: url)
                }
            }
        }
    }
    
    private func handleSnapchatCallback(url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
            print("❌ Invalid Snapchat callback URL")
            return
        }
        
        // Exchange code for access token
        // This would typically be done through your backend
        print("✅ Got Snapchat auth code: \(code)")
        
        // Post notification for views to handle
        NotificationCenter.default.post(
            name: Notification.Name("SnapchatAuthSuccess"),
            object: nil,
            userInfo: ["code": code]
        )
    }
    
    private func handleInstagramCallback(url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
            print("❌ Invalid Instagram callback URL")
            return
        }
        
        // Exchange code for access token
        // This would typically be done through your backend
        print("✅ Got Instagram auth code: \(code)")
        
        // Post notification for views to handle
        NotificationCenter.default.post(
            name: Notification.Name("InstagramAuthSuccess"),
            object: nil,
            userInfo: ["code": code]
        )
    }
} 