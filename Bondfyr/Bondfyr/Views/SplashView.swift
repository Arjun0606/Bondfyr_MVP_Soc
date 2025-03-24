//
//  SplashView.swift
//  Bondfyr
//
//  Created by Arjun Varma on 24/03/25.
//

import SwiftUI

struct SplashView: View {
    @State private var isActive = false
    @StateObject var authViewModel = AuthViewModel()

    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [Color.black, Color(red: 18/255, green: 18/255, blue: 18/255)]), startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            if isActive {
                if authViewModel.isLoggedIn {
                    MainTabView()
                        .environmentObject(authViewModel)
                } else {
                    LoginView()
                        .environmentObject(authViewModel)
                }
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "flame.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 100)
                        .foregroundColor(Color.pink)
                        .shadow(radius: 10)
                        .scaleEffect(isActive ? 0.8 : 1.0)
                        .opacity(isActive ? 0 : 1)
                        .animation(.easeInOut(duration: 0.6), value: isActive)

                    Text("Bondfyr")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .opacity(isActive ? 0 : 1)
                        .animation(.easeInOut(duration: 0.6), value: isActive)
                }
                .transition(.opacity)
                .onAppear {
                    withAnimation(.easeOut(duration: 1.0)) {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            isActive = true
                        }
                    }
                }
            }
        }
    }
}
