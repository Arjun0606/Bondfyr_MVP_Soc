// ===========================================
// TEMPORARY FIX FOR SDWEBIMAGESWIFTUI ISSUES
// ===========================================
// This file has been modified to use AsyncImage instead of WebImage
// until SDWebImageSwiftUI can be properly added.
//
// Follow these EXACT steps to add SDWebImageSwiftUI:
// 1. Close Xcode completely
// 2. Delete the DerivedData folder by:
//    - Going to Xcode menu > Preferences > Locations
//    - Click the small arrow next to DerivedData path to open it
//    - Delete the folder content or the entire folder
// 3. Open Terminal and run:
//    cd ~/Library/Caches && rm -rf org.swift.swiftpm
// 4. Reopen Xcode and your project
// 5. Go to File > Packages > Reset Package Caches
// 6. Go to File > Add Packages...
// 7. Enter URL: https://github.com/SDWebImage/SDWebImageSwiftUI.git
// 8. Click "Add Package"
// 9. When prompted, select BOTH "SDWebImageSwiftUI" and "SDWebImage" products
// 10. Select your target "Bondfyr" in the dropdown
// 11. Click "Add Package" again
// 12. After package is added, clean build folder:
//     Hold Option key and click Product > Clean Build Folder
// 13. Once SDWebImageSwiftUI is properly added, replace all AsyncImage
//     instances with WebImage
// ===========================================

import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseAuth
import SDWebImage  // Changed to what's available for now

struct EventPhotoGalleryView: View {
    let event: Event
    let stringEventId: String?  // Optional string ID for notification cases
    
    @StateObject private var photoManager = PhotoContestManager.shared
    @State private var showingCamera = false
    @State private var inputImage: UIImage?
    @State private var caption = ""
    @State private var showingCaptionSheet = false
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    @State private var showingSuccessAlert = false
    @State private var refreshTrigger = UUID()
    @State private var forcedTestEventId = false
    @State private var isLoading = false
    @State private var photoRefreshRetryCount = 0
    @State private var noPhotosMessage: String? = nil
    @State private var setupPhotosComplete = false
    @State private var selectedEventId: String?
    @State private var uploadWindowTimer: Timer?
    
    // Standard initializer with Event object
    init(event: Event) {
        // Check if we have test-event-id set in UserDefaults
        let lastEventId = UserDefaults.standard.string(forKey: "lastPhotoGalleryEventId") ?? ""
        let pendingGalleryEventId = UserDefaults.standard.string(forKey: "pendingGalleryEventId")
        
        // Determine the value of stringEventId once, before assigning it
        let finalStringEventId: String? = (lastEventId == "test-event-id" || pendingGalleryEventId == "test-event-id") 
            ? "test-event-id" 
            : nil
        
        self.event = event
        self.stringEventId = finalStringEventId
        
        if finalStringEventId == "test-event-id" {
            
        }
    }
    
    // Alternative initializer with string event ID (for notifications)
    init(stringEventId: String) {
        // Handle test-event-id directly
        if stringEventId == "test-event-id" || 
           UserDefaults.standard.string(forKey: "lastPhotoGalleryEventId") == "test-event-id" ||
           UserDefaults.standard.string(forKey: "pendingGalleryEventId") == "test-event-id" {
            
        }
        
        // Create a properly initialized placeholder event with all required parameters
        self.event = Event(
            id: UUID(),
            name: "Photo Contest",
            date: "Today",
            time: "Now",
            venue: "Loading...",
            description: "Loading event details...",
            hostId: stringEventId,
            host: "Unknown Host",
            coverPhoto: "placeholder",
            ticketTiers: [],
            venueLogoImage: "placeholder"
        )
        self.stringEventId = stringEventId
        
    }
    
    var body: some View {
        ZStack {
            // Background color
            LinearGradient(gradient: Gradient(colors: [Color.black, Color(red: 0.1, green: 0.1, blue: 0.3)]), startPoint: .top, endPoint: .bottom)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Photo Contest")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button(action: {
                        refreshPhotos()
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.white)
                            .font(.title2)
                    }
                    }
                    .padding()
                
                // Main Content Area
                if isLoading {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                    Spacer()
                } else if photoManager.photos.isEmpty {
                    emptyStateView
                } else {
                    photoGridView
                }
                
                Spacer(minLength: 0)
                
                // Bottom bar with camera button
                cameraButton
            }
            .alert(isPresented: $showingErrorAlert) {
                Alert(
                    title: Text("Error"),
                    message: Text(errorMessage),
                    dismissButton: .default(Text("OK")) {
                        // Reset error state after acknowledgment
                        errorMessage = ""
                    }
                )
            }
        }
        .onAppear {
            
            
            // Check if we have a pending gallery event ID
            if let pendingId = UserDefaults.standard.string(forKey: "pendingGalleryEventId") {
                
                self.selectedEventId = pendingId
                
                // If we have a flag indicating a photo was just uploaded, force refresh
                if UserDefaults.standard.bool(forKey: "photoJustUploaded") {
                    
                    
                    // Multiple refresh attempts with delays
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.refreshPhotosWithStringId(eventId: pendingId)
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        self.refreshPhotosWithStringId(eventId: pendingId)
                    }
                    
                    // Clear the flags after processing
                    UserDefaults.standard.set(false, forKey: "photoJustUploaded")
                } else {
                    self.setupPhotosWithStringId(eventId: pendingId)
                }
                
                // Clear the pending ID after processing
                UserDefaults.standard.removeObject(forKey: "pendingGalleryEventId")
            } else {
                // Regular setup if no pending ID
                self.setupNotificationListeners()
                self.setupPhotos()
            }
            
            // Set up timer to update remaining time every second
            self.uploadWindowTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                // For testing, we're disabling the countdown completely
                // This ensures the upload window stays open
                DispatchQueue.main.async {
                    // Make sure the window stays open by setting a minimum value
                    if self.photoManager.uploadWindowRemainingSeconds < 60 * 60 { // If less than 1 hour
                        self.photoManager.uploadWindowRemainingSeconds = 5 * 60 * 60 // Reset to 5 hours
                    }
                }
            }
        }
        .onDisappear {
            
            // Clean up listeners when view disappears
            if let stringId = stringEventId {
                photoManager.removePhotoListener(for: stringId)
            } else {
                photoManager.removePhotoListener(for: event.id.uuidString)
            }
            
            // Remove notification observers
            NotificationCenter.default.removeObserver(self)
            
            // Clean up timer
            uploadWindowTimer?.invalidate()
            uploadWindowTimer = nil
        }
        .sheet(isPresented: $showingCamera) {
            ImagePicker(image: $inputImage)
                .ignoresSafeArea()
                .onDisappear {
                    if inputImage != nil {
                        
                        showingCaptionSheet = true
                    } else {
                        
                    }
                }
        }
        .sheet(isPresented: $showingCaptionSheet) {
            captionInputView
        }
        .onChange(of: photoManager.error) { error in
            if let error = error {
                
                errorMessage = error.localizedDescription
                showingErrorAlert = true
            }
        }
    }
    
    // MARK: - View Components
    
    private var emptyStateView: some View {
                        VStack(spacing: 20) {
                            Spacer()
                            
                            Image(systemName: "photo.on.rectangle.angled")
                                .resizable()
                                .scaledToFit()
                .frame(width: 80, height: 80)
                .foregroundColor(.white.opacity(0.5))
            
            Text("No Photos Yet")
                .font(.title2)
                .fontWeight(.bold)
                                        .foregroundColor(.white)
            
            Text("Be the first to capture a moment!\nTap the camera button below to start.")
                .font(.body)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                            
                            Spacer()
                        }
    }
    
    private var photoGridView: some View {
                        ScrollView {
            LazyVStack(spacing: 20) {
                // Leaderboard (Top 3)
                if !photoManager.photos.isEmpty {
                    leaderboardView
                }
                
                // All photos
                ForEach(photoManager.photos) { photo in
                    PhotoContestCard(
                        photo: photo,
                        onLike: {
                            likePhoto(photo)
                        },
                        onUnlike: {
                            unlikePhoto(photo)
                        },
                        onDelete: {
                            deletePhoto(photo)
                        },
                        isOwner: photo.userId == Auth.auth().currentUser?.uid
                    )
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
    }
    
    private var leaderboardView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("LEADERBOARD")
                .font(.headline)
                .foregroundColor(.white.opacity(0.8))
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 15) {
                    ForEach(Array(photoManager.photos.prefix(3).enumerated()), id: \.element.id) { index, photo in
                        VStack {
                            // Medal icon
                            medalIcon(for: index)
                                .font(.title)
                                .foregroundColor(medalColor(for: index))
                            
                            // Photo - using AsyncImage temporarily
                            AsyncImage(url: URL(string: photo.photoURL)) { phase in
                                if let image = phase.image {
                                    image
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 100, height: 100)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(medalColor(for: index), lineWidth: 2)
                                        )
                                } else if phase.error != nil {
                                    Image(systemName: "photo")
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 100, height: 100)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(medalColor(for: index), lineWidth: 2)
                                        )
                                } else {
                                    ProgressView()
                                        .frame(width: 100, height: 100)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(medalColor(for: index), lineWidth: 2)
                                        )
                                }
                            }
                            
                            // Like count
                            HStack(spacing: 5) {
                                Image(systemName: "heart.fill")
                                    .foregroundColor(.red)
                                    .font(.footnote)
                                
                                Text("\(photo.likeCount)")
                                    .font(.footnote)
                                    .foregroundColor(.white)
                            }
                            
                            // Username
                            Text(photo.userName)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                                .lineLimit(1)
                        }
                        .frame(width: 100)
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.bottom, 10)
    }
    
    private var cameraButton: some View {
        VStack {
            if let userPhoto = photoManager.userPhoto {
                // User already has a photo uploaded
                HStack {
                    // User photo thumbnail - AsyncImage temporarily
                    AsyncImage(url: URL(string: userPhoto.photoURL)) { phase in
                        if let image = phase.image {
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 40, height: 40)
                                .clipShape(Circle())
                        } else if phase.error != nil {
                            Image(systemName: "person.circle")
                                .resizable()
                                .scaledToFill()
                                .frame(width: 40, height: 40)
                                .clipShape(Circle())
                        } else {
                            ProgressView()
                                .frame(width: 40, height: 40)
                                .clipShape(Circle())
                        }
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Your photo is live!")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                        
                        Text("Delete to upload a new photo")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        // Confirm deletion
                        deletePhoto(userPhoto)
                    }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                            .padding()
                    }
                }
                .padding()
                .background(Color.black.opacity(0.5))
                .cornerRadius(12)
                .padding()
            } else {
                // No photo uploaded, show camera button
                VStack(spacing: 8) {
                    // Upload window info
                    HStack {
                        Image(systemName: "clock")
                            .foregroundColor(.yellow)
                        
                        Text("Upload window: \(formatTimeRemaining(photoManager.uploadWindowRemainingSeconds))")
                            .font(.caption)
                            .foregroundColor(.yellow)
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                    
                    Button(action: {
                        // Direct camera access only - no notifications
                        checkAndOpenCamera()
                    }) {
                        HStack {
                            Image(systemName: "camera.fill")
                                .font(.title2)
                            
                            Text("Capture a Contest Photo")
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(height: 50)
                        .frame(maxWidth: .infinity)
                        .background(LinearGradient(gradient: Gradient(colors: [Color.blue, Color.purple]), startPoint: .leading, endPoint: .trailing))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                    // Only disable if user already has a photo
                    .disabled(photoManager.userUploadCount >= 1)
                    .opacity(photoManager.userUploadCount >= 1 ? 0.5 : 1.0)
                }
                .padding(.vertical, 10)
                .background(Color.black.opacity(0.3))
                .cornerRadius(12)
                .padding()
            }
        }
    }
    
    // Helper to format time remaining
    private func formatTimeRemaining(_ seconds: TimeInterval) -> String {
        if seconds <= 0 {
            return "Closed"
        }
        
        let hours = Int(seconds) / 3600
        let minutes = Int(seconds) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m remaining"
        } else {
            return "\(minutes)m remaining"
        }
    }
    
    private var captionInputView: some View {
        VStack(spacing: 20) {
            // Header
            Text("Add a caption to your photo")
                .font(.headline)
                .padding(.top)
            
            // Image preview
            if let image = inputImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 200)
                    .cornerRadius(10)
            }
            
            // Caption field
            TextField("Write a caption...", text: $caption)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
            
            // Buttons
            HStack {
                Button("Cancel") {
                    caption = ""
                    inputImage = nil
                    showingCaptionSheet = false
                }
                .foregroundColor(.red)
                .padding()
                
                Spacer()
                
                Button("Upload") {
                    uploadPhoto()
                    showingCaptionSheet = false
                }
                .foregroundColor(.blue)
                .disabled(caption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .padding()
            }
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Helper Functions
    
    func medalIcon(for index: Int) -> some View {
        switch index {
        case 0:
            return Image(systemName: "1.circle.fill")
        case 1:
            return Image(systemName: "2.circle.fill")
        case 2:
            return Image(systemName: "3.circle.fill")
        default:
            return Image(systemName: "questionmark.circle.fill")
        }
    }
    
    func medalColor(for index: Int) -> Color {
        switch index {
        case 0:
            return .yellow
        case 1:
            return .gray
        case 2:
            return .brown
        default:
            return .blue
        }
    }
    
    // MARK: - Photo Management
    
    private func setupPhotos() {
        
        
        // Start real-time listener
        let eventIdString = event.id.uuidString
        photoManager.setupPhotoListener(for: eventIdString)
        
        // Initial fetch in case listener is slow
        refreshPhotos()
    }
    
    private func setupPhotosWithStringId(eventId: String) {
        
        
        // First, clear any existing listener
        if let stringId = stringEventId {
            photoManager.removePhotoListener(for: stringId)
        } else {
            photoManager.removePhotoListener(for: event.id.uuidString)
        }
        
        // Start real-time listener with the string ID
        photoManager.setupPhotoListener(for: eventId)
        
        // Initial fetch with string ID
        refreshPhotosWithStringId(eventId: eventId)
        
        // If the eventId is "test-event-id", set up multiple retries
        if eventId == "test-event-id" {
            
            
            // Try another immediate fetch
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                
                self.refreshPhotosWithStringId(eventId: "test-event-id")
                
                // Try again after 1 second
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    
                    self.refreshPhotosWithStringId(eventId: "test-event-id")
                    
                    // Final retry after 2 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        
                        self.refreshPhotosWithStringId(eventId: "test-event-id")
                    }
                }
            }
        }
    }
    
    private func refreshPhotos(forceRefresh: Bool = false) {
        // Use the event ID string directly, no need to check if it's nil
        let eventIdStr = event.id.uuidString
        refreshPhotosWithStringId(eventId: eventIdStr, forceRefresh: forceRefresh)
    }
    
    private func refreshPhotosWithStringId(eventId: String, forceRefresh: Bool = false) {
        guard !isLoading || forceRefresh else {
            
            return
        }
        
        let displayEventId = eventId.count > 8 ? "..." + eventId.suffix(8) : eventId
        
        
        isLoading = true
        
        
        // Reset error state
        errorMessage = ""
        showingErrorAlert = false
        
        photoManager.fetchPhotos(for: eventId) { result in
                DispatchQueue.main.async {
                self.isLoading = false
                
                switch result {
                case .success(let photos):
                    
                    
                    // Store the event ID in UserDefaults for later use
                    UserDefaults.standard.set(eventId, forKey: "lastViewedEventId")
                    
                    // If we have no photos, display appropriate message
                    if photos.isEmpty {
                        
                        self.noPhotosMessage = "No photos yet! Be the first to upload one."
                    } else {
                        // Use empty string instead of nil for non-optional String
                        self.noPhotosMessage = ""
                    }
                    
                    // Update UI
                    self.setupPhotosComplete = true
                    
                    // Reset retry count on success
                    self.photoRefreshRetryCount = 0
                    
                case .failure(let error):
                    
                    
                    if self.photoRefreshRetryCount < 3 {
                        // Retry up to 3 times with exponential backoff
                        self.photoRefreshRetryCount += 1
                        let delay = pow(2.0, Double(self.photoRefreshRetryCount)) * 0.5
                        
                        
                        // Capture eventId for the retry
                        let capturedEventId = eventId
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                            self.refreshPhotosWithStringId(eventId: capturedEventId, forceRefresh: true)
                        }
                    } else {
                        
                        self.errorMessage = "Error loading photos: \(error.localizedDescription)"
                        self.showingErrorAlert = true
                        self.setupPhotosComplete = true
                        self.noPhotosMessage = "Unable to load photos. Please try again later."
                    }
                }
            }
        }
    }
    
    private func checkAndOpenCamera() {
        
        
        guard let userId = Auth.auth().currentUser?.uid else {
            errorMessage = "You need to be logged in to upload photos"
            showingErrorAlert = true
            
            return
        }
        
        // Check eligibility
        let eventIdString = stringEventId ?? event.id.uuidString
        
        
        photoManager.checkUploadEligibility(for: eventIdString) { result in
            switch result {
            case .success:
                
                DispatchQueue.main.async {
                    self.showingCamera = true
                }
            case .failure(let error):
                
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                    self.showingErrorAlert = true
                }
            }
        }
    }
    
    private func uploadPhoto() {
        guard let image = inputImage else { 
            
            return 
        }
        
        
        
        let trimmedCaption = caption.trimmingCharacters(in: .whitespacesAndNewlines)
        let eventIdString = stringEventId ?? event.id.uuidString
        
        
        
        photoManager.uploadPhoto(for: eventIdString, image: image, caption: trimmedCaption) { result in
            DispatchQueue.main.async {
                self.inputImage = nil
                self.caption = ""
                
                switch result {
                case .success:
                    
                    // Photo uploaded successfully, the listener will update the UI
                    if self.stringEventId != nil {
                        self.refreshPhotosWithStringId(eventId: eventIdString)
                } else {
                        self.refreshPhotos()
                    }
                case .failure(let error):
                    
                    self.errorMessage = error.localizedDescription
                    self.showingErrorAlert = true
                }
            }
        }
    }
    
    private func likePhoto(_ photo: PhotoContest) {
        photoManager.likePhoto(photo.id) { result in
            if case .failure(let error) = result {
                
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                    self.showingErrorAlert = true
                }
            } else {
                
            }
        }
    }
    
    private func unlikePhoto(_ photo: PhotoContest) {
        photoManager.unlikePhoto(photo.id) { result in
            if case .failure(let error) = result {
                
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                    self.showingErrorAlert = true
                }
            } else {
                
            }
        }
    }
    
    private func deletePhoto(_ photo: PhotoContest) {
        photoManager.deletePhoto(photo.id) { result in
            DispatchQueue.main.async {
                switch result {
                case .failure(let error):
                    
                    // Don't show an error message for expected errors like "userAlreadyUploaded"
                    // as these might appear after deleting a photo
                    if let photoError = error as? PhotoContestError {
                        if case .userAlreadyUploaded = photoError {
                            // This is expected after deletion - just refresh
                            let eventIdString = self.stringEventId ?? self.event.id.uuidString
                            self.refreshPhotosWithStringId(eventId: eventIdString, forceRefresh: true)
                            return
                        }
                    }
                    
                    self.errorMessage = error.localizedDescription
                    self.showingErrorAlert = true
                    
                case .success:
                    
                    // Clear any error messages
                    self.errorMessage = ""
                    self.showingErrorAlert = false
                    
                    // Refresh the photos list
                    let eventIdString = self.stringEventId ?? self.event.id.uuidString
                    self.refreshPhotosWithStringId(eventId: eventIdString, forceRefresh: true)
                }
            }
        }
    }
    
    // MARK: - Notification Listeners
    
    private func setupNotificationListeners() {
        setupPhotoGalleryNotificationListener()
    }
    
    private func setupPhotoGalleryNotificationListener() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ForceShowEventGallery"),
            object: nil,
            queue: .main
        ) { notification in
            
            
            if let userInfo = notification.userInfo,
               let eventId = userInfo["eventId"] as? String {
                
                
                // Check additional flags that might be passed
                let fromCamera = userInfo["fromCamera"] as? Bool ?? false
                
                // If this notification comes from camera, make sure we reload photos
                if fromCamera {
                    
                    // Force a short delay to ensure Firebase has registered the new photo
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.refreshPhotosWithStringId(eventId: eventId)
                    }
                    
                    // Try again after a slightly longer delay as a backup
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        self.refreshPhotosWithStringId(eventId: eventId)
                    }
                } else {
                    self.setupPhotosWithStringId(eventId: eventId)
                }
            }
        }
        
        // Add listener for the direct gallery notification
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ShowDirectPhotoGallery"),
            object: nil,
            queue: .main
        ) { notification in
            
            
            if let userInfo = notification.userInfo,
               let eventId = userInfo["eventId"] as? String {
                
                
                // Check for flags
                let fromCamera = userInfo["fromCamera"] as? Bool ?? false
                let forceShow = userInfo["forceShow"] as? Bool ?? false
                
                // Set local state
                self.selectedEventId = eventId
                
                // If this notification comes with strong flags, prioritize the refresh
                if fromCamera && forceShow {
                    
                    
                    // Force multiple refreshes with increasing delays to ensure we catch the new photo
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.refreshPhotosWithStringId(eventId: eventId)
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        self.refreshPhotosWithStringId(eventId: eventId)
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        self.refreshPhotosWithStringId(eventId: eventId)
                    }
                            } else {
                    self.setupPhotosWithStringId(eventId: eventId)
                }
            }
        }
    }
}

// MARK: - Photo Contest Card

struct PhotoContestCard: View {
    let photo: PhotoContest
    let onLike: () -> Void
    let onUnlike: () -> Void
    let onDelete: () -> Void
    let isOwner: Bool
    
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // User info header
            userInfoHeader
            
            // Photo
            ZStack {
                Rectangle()
                    .foregroundColor(.gray.opacity(0.3))
                    .frame(height: 200)
                
                // Photo - using AsyncImage temporarily
                AsyncImage(url: URL(string: photo.photoURL)) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .scaledToFit()
                    } else if phase.error != nil {
                        Image(systemName: "photo")
                            .resizable()
                            .scaledToFit()
                    } else {
                        ProgressView()
                    }
                }
            }
            .cornerRadius(12)
            
            // Caption
            if !photo.caption.isEmpty {
                Text(photo.caption)
                    .foregroundColor(.white)
                    .padding(.vertical, 4)
            }
            
            // Like button and expiration info
            likeAndExpirationRow
        }
        .padding()
        .background(Color.black.opacity(0.3))
        .cornerRadius(15)
        .alert(isPresented: $showDeleteConfirmation) {
            Alert(
                title: Text("Delete Photo"),
                message: Text("Are you sure you want to delete your photo? This cannot be undone."),
                primaryButton: .destructive(Text("Delete")) {
                    onDelete()
                },
                secondaryButton: .cancel()
            )
        }
    }
    
    // Break down the view into smaller components
    private var userInfoHeader: some View {
        HStack {
            // Profile image placeholder
            Circle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 36, height: 36)
                .overlay(
                    Text(String(photo.userName.prefix(1).uppercased()))
                        .foregroundColor(.white)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(photo.userName)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                // Time since posted
                Text(timeAgo(from: photo.timestamp))
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            if isOwner {
                Button(action: {
                    showDeleteConfirmation = true
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red.opacity(0.8))
                }
            }
        }
    }
    
    private var likeAndExpirationRow: some View {
        HStack {
            Button(action: {
                if photo.userLiked {
                    onUnlike()
                } else {
                    onLike()
                }
            }) {
                Image(systemName: photo.userLiked ? "heart.fill" : "heart")
                    .foregroundColor(photo.userLiked ? .red : .white)
                    .frame(width: 24, height: 24)
            }
            
            Text("\(photo.likeCount) likes")
                .foregroundColor(.white.opacity(0.8))
                .font(.subheadline)
            
            Spacer()
            
            // Expiration time
            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .font(.caption)
                
                Text("Expires in \(timeUntilExpiry(from: photo.expirationTime))")
                    .font(.caption)
            }
            .foregroundColor(.white.opacity(0.6))
        }
    }
    
    // Format time since posted
    private func timeAgo(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    // Format time until expiry
    private func timeUntilExpiry(from date: Date) -> String {
        let now = Date()
        let components = Calendar.current.dateComponents([.hour, .minute], from: now, to: date)
        
        if let hours = components.hour, let minutes = components.minute {
            if hours > 0 {
                return "\(hours)h \(minutes)m"
            } else {
                return "\(minutes)m"
            }
        }
        
        return "soon"
    }
} 