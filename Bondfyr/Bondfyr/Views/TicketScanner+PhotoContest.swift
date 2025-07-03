import SwiftUI
import FirebaseFirestore

extension TicketScannerView {
    
    // This function should be called after a successful ticket scan
    func handlePhotoContestUnlock(for eventId: String, eventName: String) {
        // Update the ticket's scanned status in Firestore
        updateTicketScannedStatus(for: eventId) { success in
            if success {
                // Send local notification about photo contest
                NotificationManager.shared.sendPhotoContestUnlockedNotification(
                    eventId: eventId,
                    eventName: eventName
                )
                
                // Show in-app banner about photo contest
                showPhotoContestUnlockedBanner()
            }
        }
    }
    
    private func updateTicketScannedStatus(for eventId: String, completion: @escaping (Bool) -> Void) {
        guard let userId = AuthManager.shared.getCurrentUser()?.uid else {
            completion(false)
            return
        }
        
        let db = Firestore.firestore()
        
        // Find user's ticket for this event
        db.collection("tickets")
            .whereField("userId", isEqualTo: userId)
            .whereField("eventId", isEqualTo: eventId)
            .getDocuments { snapshot, error in
                if let error = error {
                    
                    completion(false)
                    return
                }
                
                guard let documents = snapshot?.documents, !documents.isEmpty else {
                    
                    completion(false)
                    return
                }
                
                // Update the first matching ticket (there should only be one per user per event)
                let ticketId = documents[0].documentID
                
                db.collection("tickets").document(ticketId).updateData([
                    "isScanned": true,
                    "scanTimestamp": FieldValue.serverTimestamp()
                ]) { error in
                    if let error = error {
                        
                        completion(false)
                    } else {
                        
                        completion(true)
                    }
                }
            }
    }
    
    private func showPhotoContestUnlockedBanner() {
        // Show in-app banner (this would be implemented in the main app)
        // You could use a binding to show the banner or use NotificationCenter
        NotificationCenter.default.post(
            name: NSNotification.Name("ShowPhotoContestUnlocked"),
            object: nil
        )
    }
}

// A reusable view for the photo contest unlocked banner
struct PhotoContestUnlockedBanner: View {
    @Binding var isShowing: Bool
    let eventName: String
    var onTap: () -> Void
    
    var body: some View {
        VStack {
            HStack(spacing: 12) {
                Image(systemName: "camera.fill")
                    .font(.title3)
                    .foregroundColor(.blue)
                    .padding(8)
                    .background(Circle().fill(Color.blue.opacity(0.1)))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Photo Contest Unlocked!")
                        .font(.headline)
                    
                    Text("You can now share photos at \(eventName)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: {
                    withAnimation {
                        isShowing = false
                    }
                }) {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(8)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
            )
            .padding(.horizontal)
            .contentShape(Rectangle())
            .onTapGesture {
                onTap()
            }
        }
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.spring(), value: isShowing)
    }
}

// Preview provider for the banner
struct PhotoContestUnlockedBanner_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .edgesIgnoringSafeArea(.all)
            
            PhotoContestUnlockedBanner(
                isShowing: .constant(true),
                eventName: "Summer Party"
            ) {
                
            }
            .padding(.top, 50)
        }
    }
}
