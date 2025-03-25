//
//  SplashView.swift
//  Bondfyr
//
//  Created by Arjun Varma on 24/03/25.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import Foundation

struct SplashView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var isCheckingAuth = true
    @State private var showSplash = true

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if showSplash {
                VStack {
                    Spacer()
                    Image("BondfyrLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 120, height: 120)
                    Spacer()
                }
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        showSplash = false
                        checkAuth()
                    }
                }
            } else {
                if authViewModel.isLoggedIn {
                    MainTabView()
                } else {
                    GoogleSignInView()
                }
            }
        }
    }

    @MainActor
    private func checkAuth() {
        if let _ = Auth.auth().currentUser {
            authViewModel.fetchUserProfile { success in
                authViewModel.isLoggedIn = success
                isCheckingAuth = false
            }
        } else {
            isCheckingAuth = false
        }
    }
}
