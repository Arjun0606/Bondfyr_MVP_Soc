import SwiftUI

struct InstagramOAuthView: View {
    var onSuccess: (String, String?) -> Void
    var onManual: () -> Void

    @State private var handle: String = ""
    @State private var avatarURL: String = ""

    var body: some View {
        VStack(spacing: 24) {
            Text("Instagram Login (MVP Placeholder)")
                .font(.title2)
                .bold()
                .padding(.top, 40)
            TextField("Instagram Handle", text: $handle)
                .padding()
                .background(Color.white.opacity(0.1))
                .cornerRadius(10)
                .foregroundColor(.white)
            TextField("Avatar URL (optional)", text: $avatarURL)
                .padding()
                .background(Color.white.opacity(0.1))
                .cornerRadius(10)
                .foregroundColor(.white)
            Button("Continue") {
                onSuccess(handle.lowercased(), avatarURL.isEmpty ? nil : avatarURL)
            }
            .disabled(handle.isEmpty)
            .padding()
            .background(handle.isEmpty ? Color.gray : Color.pink)
            .foregroundColor(.white)
            .cornerRadius(10)
            Button("Enter Manually Instead") {
                onManual()
            }
            .padding(.top, 8)
            Spacer()
        }
        .padding()
        .background(Color.black.ignoresSafeArea())
    }
} 