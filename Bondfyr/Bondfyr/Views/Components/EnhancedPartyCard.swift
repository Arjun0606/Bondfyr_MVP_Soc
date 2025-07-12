import SwiftUI
import CoreLocation

// MARK: - Enhanced Party Card (World-Class Design)
struct EnhancedPartyCard: View {
    let party: Afterparty
    @StateObject private var guestState: PartyGuestState
    @StateObject private var afterpartyManager = AfterpartyManager.shared
    @EnvironmentObject var authViewModel: AuthViewModel
    
    @State private var showingRequestSheet = false
    @State private var showingPartyDetails = false
    @State private var showingSocialShare = false
    @State private var isAnimating = false
    
    // MARK: - Computed Properties
    private var currentUserId: String {
        authViewModel.currentUser?.uid ?? ""
    }
    
    private var capacityInfo: PartyCapacityInfo {
        PartyCapacityInfo(current: party.activeUsers.count, maximum: party.maxGuestCount)
    }
    
    private var timeUntilStart: String {
        let timeInterval = party.startTime.timeIntervalSinceNow
        if timeInterval <= 0 {
            return "Live Now! 🔥"
        } else if timeInterval < 3600 {
            return "Starting in \(Int(timeInterval/60))m"
        } else {
            return "Starting in \(Int(timeInterval/3600))h"
        }
    }
    
    init(party: Afterparty, userId: String) {
        self.party = party
        self._guestState = StateObject(wrappedValue: PartyGuestState(partyId: party.id, userId: userId))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Party Image & Status Overlay
            ZStack(alignment: .topTrailing) {
                // Background image with gradient overlay
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [.purple.opacity(0.8), .pink.opacity(0.6)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 200)
                    .overlay(
                        // Glassmorphism effect
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(.white.opacity(0.2), lineWidth: 1)
                    )
                
                // Status badge
                StatusBadge(status: guestState.status, capacityInfo: capacityInfo)
                    .padding(.top, 12)
                    .padding(.trailing, 12)
            }
            .overlay(alignment: .bottomLeading) {
                // Party title and host info overlay
                VStack(alignment: .leading, spacing: 4) {
                    Text(party.title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .lineLimit(2)
                    
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .foregroundColor(.white.opacity(0.8))
                        Text("@\(party.hostHandle)")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .padding(16)
            }
            
            // MARK: - Party Details Section
            VStack(spacing: 12) {
                // Time and location info
                HStack {
                    // Time info
                    HStack(spacing: 6) {
                        Image(systemName: "clock.fill")
                            .foregroundColor(.orange)
                        Text(timeUntilStart)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    
                    Spacer()
                    
                    // Capacity info
                    HStack(spacing: 6) {
                        Image(systemName: "person.3.fill")
                            .foregroundColor(capacityInfo.isNearCapacity ? .red : .green)
                        Text(capacityInfo.displayText)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }
                
                // Location
                HStack {
                    Image(systemName: "location.fill")
                        .foregroundColor(.blue)
                    Text(party.locationName)
                        .font(.caption)
                        .lineLimit(1)
                    Spacer()
                }
                
                // MARK: - Action Buttons Row
                HStack(spacing: 12) {
                    // Main Action Button
                    ActionButton(
                        status: guestState.status,
                        isLoading: guestState.isLoading,
                        isAnimating: $isAnimating
                    ) {
                        handleAction()
                    }
                    .scaleEffect(isAnimating ? 1.05 : 1.0)
                    .animation(.spring(response: 0.3), value: isAnimating)
                    
                    // Social Share Button
                    Button(action: { showingSocialShare = true }) {
                        HStack(spacing: 6) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Share")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .frame(width: 100, height: 50)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [.pink, .purple]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .padding(16)
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
        .onAppear {
            updateGuestStatus()
        }
        .sheet(isPresented: $showingRequestSheet) {
            EnhancedRequestSheet(party: party) {
                // On request submitted
                guestState.transitionTo(.requestSubmitted)
                updateGuestStatus()
            }
        }
        .sheet(isPresented: $showingSocialShare) {
            SocialShareSheet(party: party, isPresented: $showingSocialShare)
        }
        .fullScreenCover(isPresented: $showingPartyDetails) {
            // TODO: Replace with actual PartyDetailsView when implemented
            NavigationView {
                VStack(spacing: 20) {
                    Text(party.title)
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Party details coming soon...")
                        .font(.body)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button("Close") {
                        showingPartyDetails = false
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .navigationTitle("Party Details")
                .navigationBarTitleDisplayMode(.inline)
                .navigationBarItems(
                    trailing: Button("Done") {
                        showingPartyDetails = false
                    }
                )
            }
        }
    }
    
    // MARK: - Actions
    private func handleAction() {
        withAnimation(.spring()) {
            isAnimating = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isAnimating = false
        }
        
        switch guestState.status {
        case .notRequested:
            showingRequestSheet = true
            
        case .approved:
            // Navigate directly to party chat
            navigateToPartyChat()
            
        case .going:
            // Show party details with chat access
            showingPartyDetails = true
            
        default:
            // For non-actionable states, show party details
            showingPartyDetails = true
        }
    }
    
    private func navigateToPartyChat() {
        // This will be handled by navigation coordinator
        NotificationCenter.default.post(
            name: Notification.Name("NavigateToPartyChat"),
            object: nil,
            userInfo: ["partyId": party.id]
        )
    }
    
    private func updateGuestStatus() {
        let newStatus = guestState.calculateStatus(from: party, userId: currentUserId)
        guestState.transitionTo(newStatus)
    }
}

// MARK: - Status Badge Component
struct StatusBadge: View {
    let status: PartyGuestStatus
    let capacityInfo: PartyCapacityInfo
    
    var body: some View {
        HStack(spacing: 6) {
            if status.showsProgress {
                ProgressView()
                    .scaleEffect(0.7)
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
            } else {
                Image(systemName: status.icon)
            }
            
            Text(badgeText)
                .font(.caption2)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(status.color.opacity(0.9))
                .overlay(
                    Capsule()
                        .stroke(.white.opacity(0.3), lineWidth: 1)
                )
        )
        .foregroundColor(.white)
    }
    
    private var badgeText: String {
        if status == .going || status == .approved {
            return status.displayText
        } else if capacityInfo.isFull && status == .notRequested {
            return "Full"
        } else if capacityInfo.isNearCapacity && status == .notRequested {
            return "Filling Fast!"
        }
        return status.displayText
    }
}

// MARK: - Enhanced Action Button
struct ActionButton: View {
    let status: PartyGuestStatus
    let isLoading: Bool
    @Binding var isAnimating: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            if status.isActionable && !isLoading {
                action()
            }
        }) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Image(systemName: status.icon)
                        .font(.system(size: 16, weight: .semibold))
                }
                
                Text(buttonText)
                    .font(.system(size: 16, weight: .semibold))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(buttonBackground)
            .foregroundColor(buttonForegroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(strokeColor, lineWidth: strokeWidth)
            )
        }
        .disabled(!status.isActionable || isLoading)
        .animation(.easeInOut(duration: 0.2), value: status)
    }
    
    private var buttonText: String {
        if isLoading {
            return "Processing..."
        }
        return status.displayText
    }
    
    private var buttonBackground: AnyView {
        switch status {
        case .notRequested:
            return AnyView(
                LinearGradient(
                    gradient: Gradient(colors: [.purple, .pink]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
        case .approved:
            return AnyView(
                LinearGradient(
                    gradient: Gradient(colors: [.blue, .cyan]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
        case .going:
            return AnyView(Color.green)
        case .requestSubmitted:
            return AnyView(Color.orange.opacity(0.7))
        case .denied:
            return AnyView(Color.red.opacity(0.3))
        case .soldOut, .partyEnded:
            return AnyView(Color.gray.opacity(0.3))
        }
    }
    
    private var buttonForegroundColor: Color {
        switch status {
        case .denied, .soldOut, .partyEnded:
            return .secondary
        default:
            return .white
        }
    }
    
    private var strokeColor: Color {
        switch status {
        case .notRequested, .approved, .going:
            return .clear
        default:
            return .white.opacity(0.3)
        }
    }
    
    private var strokeWidth: CGFloat {
        status.isActionable ? 0 : 1
    }
}

// MARK: - Enhanced Request Sheet
struct EnhancedRequestSheet: View {
    let party: Afterparty
    let onRequestSubmitted: () -> Void
    
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var afterpartyManager = AfterpartyManager.shared
    
    @State private var introMessage = ""
    @State private var isSubmitting = false
    @State private var showingSuccessAnimation = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Text("Join \(party.title)")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Tell @\(party.hostHandle) why you'd be a great addition!")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)
                    
                    // Party quick info
                    PartyQuickInfo(party: party)
                    
                    // Intro message
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your Message")
                            .font(.headline)
                        
                        TextEditor(text: $introMessage)
                            .frame(minHeight: 120)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.ultraThinMaterial)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(.white.opacity(0.2), lineWidth: 1)
                            )
                        
                        Text("\(introMessage.count)/280")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    
                    // Submit button
                    Button(action: submitRequest) {
                        HStack {
                            if isSubmitting {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Image(systemName: "paperplane.fill")
                            }
                            
                            Text(isSubmitting ? "Sending Request..." : "Send Request")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [.purple, .pink]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(introMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)
                    
                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
        .preferredColorScheme(.dark)
        .overlay(
            // Success animation overlay
            SuccessAnimationView(isShowing: $showingSuccessAnimation)
        )
    }
    
    private func submitRequest() {
        guard let currentUser = authViewModel.currentUser else { return }
        
        isSubmitting = true
        
        Task {
            do {
                let guestRequest = GuestRequest(
                    userId: currentUser.uid,
                    userName: currentUser.name,
                    userHandle: currentUser.username ?? currentUser.name,
                    introMessage: introMessage.trimmingCharacters(in: .whitespacesAndNewlines),
                    paymentStatus: .pending
                )
                
                try await afterpartyManager.submitGuestRequest(
                    afterpartyId: party.id,
                    guestRequest: guestRequest
                )
                
                await MainActor.run {
                    isSubmitting = false
                    showSuccessAndDismiss()
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    // Handle error
                }
            }
        }
    }
    
    private func showSuccessAndDismiss() {
        showingSuccessAnimation = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            onRequestSubmitted()
            presentationMode.wrappedValue.dismiss()
        }
    }
}

// MARK: - Supporting Views
struct PartyQuickInfo: View {
    let party: Afterparty
    
    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "clock.fill")
                        .foregroundColor(.orange)
                    Text(party.startTime.formatted(.dateTime.hour().minute()))
                        .font(.caption)
                }
                
                HStack {
                    Image(systemName: "location.fill")
                        .foregroundColor(.blue)
                    Text(party.locationName)
                        .font(.caption)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                HStack {
                    Image(systemName: "person.3.fill")
                        .foregroundColor(.green)
                    Text("\(party.activeUsers.count)/\(party.maxGuestCount)")
                        .font(.caption)
                }
                
                HStack {
                    Image(systemName: "tag.fill")
                        .foregroundColor(.purple)
                    Text(party.vibeTag)
                        .font(.caption)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
    }
}

struct SuccessAnimationView: View {
    @Binding var isShowing: Bool
    
    var body: some View {
        if isShowing {
            ZStack {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.green)
                        .scaleEffect(isShowing ? 1.0 : 0.5)
                        .animation(.spring(response: 0.5, dampingFraction: 0.6), value: isShowing)
                    
                    Text("Request Sent!")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                .padding(40)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial)
                )
            }
        }
    }
} 