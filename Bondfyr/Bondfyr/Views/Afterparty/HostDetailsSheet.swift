import SwiftUI
import FirebaseFirestore

struct HostDetailsSheet: View {
    let afterparty: Afterparty
    @Environment(\.dismiss) private var dismiss
    @State private var hostUser: AppUser?
    @State private var isLoading = true
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .pink))
                            .scaleEffect(1.5)
                            .frame(height: 200)
                    } else {
                        // Host Profile Header
                        hostProfileHeader
                        
                        // Contact Information
                        contactSection
                        
                        // Payment Methods (Critical for P2P)
                        paymentMethodsSection
                        
                        // Social Media
                        if !(afterparty.instagramHandle?.isEmpty ?? true) || !(afterparty.snapchatHandle?.isEmpty ?? true) {
                            socialMediaSection
                        }
                        
                        // Verification Status
                        verificationSection
                    }
                }
                .padding()
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Host Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.pink)
                }
            }
        }
        .preferredColorScheme(.dark)
        .task {
            await loadHostData()
        }
    }
    
    private var hostProfileHeader: some View {
        VStack(spacing: 12) {
            // Host Avatar
            Circle()
                .fill(LinearGradient(
                    gradient: Gradient(colors: [.pink, .purple]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: 80, height: 80)
                .overlay(
                    Text(afterparty.hostHandle.prefix(2).uppercased())
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                )
            
            Text("@\(afterparty.hostHandle)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            if let hostUser = hostUser {
                Text(hostUser.name)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            Text("Party Host")
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Color.pink.opacity(0.2))
                .cornerRadius(12)
                .foregroundColor(.pink)
        }
    }
    
    private var contactSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Contact Information")
                .font(.headline)
                .foregroundColor(.white)
            
            VStack(alignment: .leading, spacing: 12) {
                // Phone Number
                if let phone = afterparty.phoneNumber, !phone.isEmpty {
                    HStack {
                        Image(systemName: "phone.fill")
                            .foregroundColor(.green)
                            .frame(width: 24)
                        
                        Text(formatPhoneNumber(phone))
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Button(action: {
                            if let url = URL(string: "tel://\(phone)") {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            Text("Call")
                                .font(.caption)
                                .foregroundColor(.green)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background(Color.green.opacity(0.2))
                                .cornerRadius(8)
                        }
                    }
                } else {
                    HStack {
                        Image(systemName: "phone.fill")
                            .foregroundColor(.gray)
                            .frame(width: 24)
                        
                        Text("No phone number provided")
                            .foregroundColor(.gray)
                            .italic()
                    }
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
        }
    }
    
    private var paymentMethodsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Payment Methods")
                .font(.headline)
                .foregroundColor(.white)
            
            Text("Send your payment directly to the host using:")
                .font(.caption)
                .foregroundColor(.gray)
            
            VStack(spacing: 12) {
                // Venmo
                paymentMethodRow(
                    platform: "Venmo",
                    handle: afterparty.venmoHandle ?? "",
                    icon: "dollarsign.circle.fill",
                    color: .blue
                )
                
                // Zelle
                paymentMethodRow(
                    platform: "Zelle",
                    handle: afterparty.zelleInfo ?? "",
                    icon: "banknote.fill",
                    color: .purple
                )
                
                // Cash App
                paymentMethodRow(
                    platform: "Cash App",
                    handle: afterparty.cashAppHandle ?? "",
                    icon: "dollarsign.square.fill",
                    color: .green
                )
                
                // Apple Pay
                if afterparty.acceptsApplePay == true {
                    HStack {
                        Image(systemName: "applelogo")
                            .foregroundColor(.white)
                            .frame(width: 24)
                        
                        Text("Apple Pay")
                            .foregroundColor(.white)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Text("Via Phone")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                }
            }
        }
    }
    
    private func paymentMethodRow(platform: String, handle: String, icon: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)
            
            Text(platform)
                .foregroundColor(.white)
                .fontWeight(.medium)
            
            Spacer()
            
            if !handle.isEmpty {
                Text(handle)
                    .foregroundColor(.gray)
                    .lineLimit(1)
                
                Button(action: {
                    UIPasteboard.general.string = handle
                }) {
                    Image(systemName: "doc.on.doc")
                        .foregroundColor(.blue)
                        .font(.caption)
                }
            } else {
                Text("Not provided")
                    .foregroundColor(.gray)
                    .italic()
                    .font(.caption)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var socialMediaSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Social Media")
                .font(.headline)
                .foregroundColor(.white)
            
            HStack(spacing: 16) {
                if let instagramHandle = afterparty.instagramHandle, !instagramHandle.isEmpty {
                    socialButton(
                        platform: "Instagram",
                        handle: instagramHandle,
                        icon: "camera.fill",
                        color: .pink
                    )
                }
                
                if let snapchatHandle = afterparty.snapchatHandle, !snapchatHandle.isEmpty {
                    socialButton(
                        platform: "Snapchat", 
                        handle: snapchatHandle,
                        icon: "camera.viewfinder",
                        color: .yellow
                    )
                }
            }
        }
    }
    
    private func socialButton(platform: String, handle: String, icon: String, color: Color) -> some View {
        Button(action: {
            // Open social media app or web
            let cleanHandle = handle.replacingOccurrences(of: "@", with: "")
            if platform == "Instagram" {
                if let url = URL(string: "instagram://user?username=\(cleanHandle)") {
                    UIApplication.shared.open(url)
                }
            } else if platform == "Snapchat" {
                if let url = URL(string: "snapchat://add/\(cleanHandle)") {
                    UIApplication.shared.open(url)
                }
            }
        }) {
            HStack {
                Image(systemName: icon)
                Text(handle)
                    .lineLimit(1)
            }
            .font(.caption)
            .foregroundColor(color)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(color.opacity(0.2))
            .cornerRadius(20)
        }
    }
    
    private var verificationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Verification")
                .font(.headline)
                .foregroundColor(.white)
            
            HStack {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(.green)
                
                Text("ID Verified Host")
                    .foregroundColor(.white)
                    .fontWeight(.medium)
                
                Spacer()
            }
            .padding()
            .background(Color.green.opacity(0.1))
            .cornerRadius(12)
        }
    }
    
    private func formatPhoneNumber(_ phone: String) -> String {
        let cleaned = phone.filter { $0.isNumber }
        if cleaned.count == 10 {
            let index0 = cleaned.startIndex
            let index3 = cleaned.index(index0, offsetBy: 3)
            let index6 = cleaned.index(index0, offsetBy: 6)
            let index10 = cleaned.index(index0, offsetBy: 10)
            
            return "(\(cleaned[index0..<index3])) \(cleaned[index3..<index6])-\(cleaned[index6..<index10])"
        }
        return phone
    }
    
    private func loadHostData() async {
        do {
            let db = Firestore.firestore()
            let doc = try await db.collection("users").document(afterparty.userId).getDocument()
            
            if let data = doc.data() {
                await MainActor.run {
                    self.hostUser = AppUser(
                        uid: afterparty.userId,
                        name: data["name"] as? String ?? "",
                        email: data["email"] as? String ?? "",
                        dob: (data["dob"] as? Timestamp)?.dateValue() ?? Date(),
                        phoneNumber: data["phoneNumber"] as? String ?? "",
                        username: data["username"] as? String,
                        gender: data["gender"] as? String,
                        bio: data["bio"] as? String,
                        instagramHandle: data["instagramHandle"] as? String,
                        snapchatHandle: data["snapchatHandle"] as? String,
                        avatarURL: data["avatarURL"] as? String
                    )
                    self.isLoading = false
                }
            }
        } catch {
            print("Error loading host data: \(error)")
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
} 