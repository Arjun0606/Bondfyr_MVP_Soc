//
//  LoginView.swift
//  Bondfyr
//
//  Created by Arjun Varma on 24/03/25.
//

import SwiftUI

struct LoginView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var isLoggedIn = false

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 20) {
                    Text("Welcome to Bondfyr")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .padding()
                        .background(Color(.darkGray))
                        .cornerRadius(10)
                        .foregroundColor(.white)

                    SecureField("Password", text: $password)
                        .padding()
                        .background(Color(.darkGray))
                        .cornerRadius(10)
                        .foregroundColor(.white)

                    Button(action: {
                        isLoggedIn = true
                    }) {
                        Text("Login")
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.pink)
                            .cornerRadius(10)
                    }

                    Button(action: {
                        // Add signup logic later
                    }) {
                        Text("Don’t have an account? Sign up")
                            .foregroundColor(.gray)
                            .font(.footnote)
                    }

                    NavigationLink(
                        destination: MainTabView(),
                        isActive: $isLoggedIn
                    ) {
                        EmptyView()
                    }
                }
                .padding()
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}
