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
    @StateObject var tabSelection = TabSelection()  // ✅ add this

    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            SplashView()
                .environmentObject(authViewModel)
                .environmentObject(tabSelection)  // ✅ inject it
        }
    }
}
