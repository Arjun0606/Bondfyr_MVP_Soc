//
//  ProfileView.swift
//  Bondfyr
//
//  Created by Arjun Varma on 24/03/25.
//

import SwiftUI

struct ProfileView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 20) {
                Text("Your Profile")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                Text("Coming soon: saved events, ticket history, logout, etc.")
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding()
            }
            .padding()
        }
    }
}
