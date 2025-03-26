//
//  ProfileView.swift
//  Bondfyr
//
//  Created by Arjun Varma on 24/03/25.
//

import SwiftUI
import FirebaseAuth

struct ProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showDeleteAlert = false

    // Mock event history – replace with Firestore data later
    let attendedEvents = [
        ("Qora", "March 10, 2025"),
        ("High Spirits", "Feb 24, 2025"),
        ("Vault", "Jan 15, 2025")
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Profile Icon + Name
                VStack(spacing: 10) {
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .frame(width: 100, height: 100)
                        .foregroundColor(.pink)
                        .shadow(radius: 8)

                    Text(authViewModel.currentUser?.name ?? "Guest")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }

                // Profile Details
                VStack(alignment: .leading, spacing: 10) {
                    ProfileField(title: "Email", value: authViewModel.currentUser?.email ?? "-")
                    ProfileField(title: "Date of Birth", value: formatDate(authViewModel.currentUser?.dob))
                    ProfileField(title: "Phone Number", value: authViewModel.currentUser?.phoneNumber ?? "-")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.white.opacity(0.05))
                .cornerRadius(12)

                // Event History
                VStack(alignment: .leading, spacing: 10) {
                    Text("Event History")
                        .font(.headline)
                        .foregroundColor(.white)

                    ForEach(attendedEvents, id: \.0) { event in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(event.0)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                Text(event.1)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(10)
                    }
                }
                .padding(.top)

                // Logout Button
                Button(action: {
                    authViewModel.logout()
                }) {
                    Text("Logout")
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.pink)
                        .cornerRadius(12)
                }
                .padding(.horizontal)

                // Delete Account Button
                Button(action: {
                    showDeleteAlert = true
                }) {
                    Text("Delete Account")
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                .alert(isPresented: $showDeleteAlert) {
                    Alert(
                        title: Text("Delete Account"),
                        message: Text("This will permanently delete your account and cannot be undone."),
                        primaryButton: .destructive(Text("Delete")) {
                            deleteAccount()
                        },
                        secondaryButton: .cancel()
                    )
                }

                Spacer()
            }
            .padding()
        }
        .background(Color.black.ignoresSafeArea())
    }

    func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "-" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    func deleteAccount() {
        guard let user = Auth.auth().currentUser else { return }
        user.delete { error in
            if let error = error {
                print("❌ Failed to delete account: \(error.localizedDescription)")
            } else {
                authViewModel.logout()
                print("✅ Account deleted successfully.")
            }
        }
    }
}

struct ProfileField: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
            Text(value)
                .foregroundColor(.white)
        }
    }
}
