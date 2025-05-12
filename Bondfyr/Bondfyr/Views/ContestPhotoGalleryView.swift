import SwiftUI
import FirebaseFirestore
import Kingfisher

struct ContestPhotoGalleryView: View {
    let eventId: String
    let eventName: String
    
    @StateObject private var photoManager = PhotoManager.shared
    @State private var selectedPhoto: EventPhoto?
    @State private var isShowingPhotoCapture = false
    @State private var contestStatus: ContestStatus = .checking
    @Environment(\.presentationMode) var presentationMode
    
    enum ContestStatus {
        case checking
        case active(timeRemaining: TimeInterval)
        case ended
        case noContest
    }
    
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack {
                // Header with event name and close button
                HStack {
                    Text("Contest Photos")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.gray.opacity(0.3))
                            .clipShape(Circle())
                    }
                }
                .padding()
                
                // Contest Status Banner
                contestStatusView
                
                // Photo Grid
                        ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(photoManager.contestPhotos) { photo in
                            PhotoGridItem(photo: photo)
                                        .onTapGesture {
                                            selectedPhoto = photo
                                        }
                                }
                            }
                            .padding()
                }
            }
        }
        .sheet(item: $selectedPhoto) { photo in
            EventPhotoDetailView(photo: photo)
        }
        .sheet(isPresented: $isShowingPhotoCapture) {
            ContestPhotoCaptureView(eventId: eventId)
        }
        .onAppear {
            checkContestStatus()
            Task {
                await photoManager.fetchContestPhotos(for: eventId)
            }
        }
    }
    
    private var contestStatusView: some View {
            switch contestStatus {
            case .checking:
            return AnyView(
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .pink))
            )
            case .active(let timeRemaining):
            return AnyView(
                HStack {
                    Image(systemName: "timer")
                        .foregroundColor(.pink)
                    Text("Contest ends in \(formatTimeRemaining(timeRemaining))")
                        .foregroundColor(.white)
                    Spacer()
                    Button(action: { isShowingPhotoCapture = true }) {
                        Image(systemName: "camera")
                            .foregroundColor(.pink)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.2))
            )
        case .ended:
            return AnyView(
                Text("Contest has ended")
                    .foregroundColor(.gray)
                    .padding()
            )
        case .noContest:
            return AnyView(
                Text("No active contest")
                    .foregroundColor(.gray)
                    .padding()
            )
        }
    }
    
    private func checkContestStatus() {
        // Implement contest status check logic
        // This should check if there's an active contest for the event
        // and update the contestStatus accordingly
    }
    
    private func formatTimeRemaining(_ timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) / 60 % 60
        return "\(hours)h \(minutes)m"
    }
}

struct PhotoGridItem: View {
    let photo: EventPhoto
    
    var body: some View {
        KFImage(URL(string: photo.imageUrl))
            .placeholder {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    }
                            .resizable()
            .aspectRatio(1, contentMode: .fill)
                            .frame(maxWidth: .infinity)
            .cornerRadius(12)
            .overlay(
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text("\(photo.likes)")
                            .foregroundColor(.white)
                            .font(.caption)
                            .padding(6)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(8)
                            .padding(8)
            }
        }
            )
    }
}
