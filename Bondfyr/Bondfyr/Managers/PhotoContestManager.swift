import Foundation
import Firebase
import FirebaseFirestore
import FirebaseStorage
import UIKit
import FirebaseAuth

struct PhotoContest: Identifiable, Equatable {
    let id: String
    let eventId: String
    let userId: String
    let userName: String
    let photoURL: String
    let caption: String
    let timestamp: Date
    let expirationTime: Date
    let likeCount: Int
    var userLiked: Bool = false
    
    // Computed property to check if the photo has expired
    var isExpired: Bool {
        return Date() > expirationTime
    }
    
    static func == (lhs: PhotoContest, rhs: PhotoContest) -> Bool {
        return lhs.id == rhs.id
    }
}

enum PhotoContestError: Error {
    case unauthorized
    case uploadFailed
    case downloadFailed
    case likeFailed
    case unlikeFailed
    case deletionFailed
    case networkError
    case databaseError
    case noTicketFound
    case photoExpired
    case eventNotFound
    case invalidImage
    case notLoggedIn
    case notEligible
    case fetchFailed
    case serverError
    case maxSizeExceeded
    case userAlreadyUploaded
    case uploadWindowClosed
    
    var localizedDescription: String {
        switch self {
        case .unauthorized:
            return "You must scan your ticket QR code to participate in the photo contest."
        case .uploadFailed:
            return "Failed to upload photo. Please try again."
        case .downloadFailed:
            return "Failed to download photo. Please try again."
        case .likeFailed:
            return "Failed to like photo. Please try again."
        case .unlikeFailed:
            return "Failed to unlike photo. Please try again."
        case .deletionFailed:
            return "Failed to delete photo. Please try again."
        case .networkError:
            return "Network error. Please check your connection and try again."
        case .databaseError:
            return "Database error. Please try again."
        case .noTicketFound:
            return "No valid ticket found for this event. Purchase a ticket to participate."
        case .photoExpired:
            return "This photo has expired and is no longer available."
        case .eventNotFound:
            return "Event not found. Please try again."
        case .invalidImage:
            return "Invalid image format. Please try with a different image."
        case .notLoggedIn:
            return "You need to be logged in to participate"
        case .notEligible:
            return "You are not eligible to upload photos for this event"
        case .fetchFailed:
            return "Failed to fetch photos"
        case .serverError:
            return "Server error occurred"
        case .maxSizeExceeded:
            return "Photo size exceeds maximum allowed limit (5MB)"
        case .userAlreadyUploaded:
            return "You have already uploaded a photo for this contest. You may delete your current photo and upload a new one."
        case .uploadWindowClosed:
            return "The upload window has closed. Photos can only be uploaded within 5 hours of the event start."
        }
    }
}

class PhotoContestManager: ObservableObject {
    static let shared = PhotoContestManager()
    private let db = Firestore.firestore()
    private let storage = Storage.storage().reference()
    
    // DEBUG MODE - Set to true to bypass upload window checks
    private let DEBUG_MODE = true
    
    // Published properties for reactivity
    @Published var isLoading: Bool = false
    @Published var error: PhotoContestError?
    @Published var photos: [PhotoContest] = []
    @Published var userPhoto: PhotoContest?
    
    // Maximum image size (5MB)
    private let maxImageSizeBytes: Int = 5 * 1024 * 1024
    
    // Contest parameters
    private let photoLifetimeInSeconds: TimeInterval = 16 * 60 * 60 // 16 hours
    private let maxPhotosPerUser: Int = 1
    
    // Track user's upload count for each event
    @Published var userUploadCount: Int = 0
    
    // Track upload time window
    @Published var uploadWindowRemainingSeconds: TimeInterval = 5 * 60 * 60 // Start with 5 hours by default
    private let uploadWindowDuration: TimeInterval = 5 * 60 * 60 // 5 hours
    
    // Use a series of listeners to track changes in real-time
    private var photoListeners: [String: ListenerRegistration] = [:]
    
    // Cache download URLs to avoid repeated fetches
    private var downloadURLCache: [String: URL] = [:]
    
    private init() {}
    
    deinit {
        // Clean up listeners
        removeAllListeners()
    }
    
    // MARK: - Firestore Listeners
    
    // Setup listener for real-time updates
    func setupPhotoListener(for eventId: String) {
        // Special case for test-event-id
        if eventId == "test-event-id" {
            print("📷 Setting up real photo listener for test-event-id")
            
            // First check for real photos in Firestore
            fetchRealPhotosForTestEvent()
            
            // Set up a real listener for test-event-id
            removeListener(for: eventId)
            
            let listener = db.collection("photo_contests")
                .whereField("eventId", isEqualTo: eventId)
                .whereField("expirationTime", isGreaterThan: Timestamp(date: Date()))
                .whereField("scheduledForDeletion", isEqualTo: false)
                .order(by: "expirationTime")
                .order(by: "timestamp", descending: true)
                .addSnapshotListener { [weak self] snapshot, error in
                    guard let self = self else { return }
                    
                    if let error = error {
                        print("❌ Error listening for test event photos: \(error.localizedDescription)")
                        return
                    }
                    
                    if let documents = snapshot?.documents, !documents.isEmpty {
                        print("📷 Found \(documents.count) real photos for test-event-id")
                        self.processPhotoDocuments(documents, for: eventId)
                    } else {
                        print("📷 No real photos found for test-event-id")
                    }
                }
            
            photoListeners[eventId] = listener
            return
        }
        
        // Normal case - proceed with regular listener setup
        removeListener(for: eventId)
        
        print("📷 Setting up photo listener for event ID: \(eventId)")
        
        let listener = db.collection("photo_contests")
            .whereField("eventId", isEqualTo: eventId)
            .whereField("expirationTime", isGreaterThan: Timestamp(date: Date()))
            .whereField("scheduledForDeletion", isEqualTo: false)
            .order(by: "expirationTime")
            .order(by: "timestamp", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ Error listening for photo updates: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        self.error = .databaseError
                    }
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("📷 No photos found in listener for event: \(eventId)")
                    DispatchQueue.main.async {
                        // Clear photos instead of keeping old ones
                        self.photos = []
                    }
                    return
                }
                
                print("📷 Received \(documents.count) photos in listener")
                self.processPhotoDocuments(documents, for: eventId)
            }
        
        photoListeners[eventId] = listener
    }
    
    // Public method to remove a specific listener
    func removePhotoListener(for eventId: String) {
        print("📷 Removing photo listener for event ID: \(eventId)")
        removeListener(for: eventId)
    }
    
    private func removeListener(for eventId: String) {
        photoListeners[eventId]?.remove()
        photoListeners.removeValue(forKey: eventId)
    }
    
    private func removeAllListeners() {
        for (_, listener) in photoListeners {
            listener.remove()
        }
        photoListeners.removeAll()
    }
    
    // MARK: - Process Photos
    
    private func processPhotoDocuments(_ documents: [QueryDocumentSnapshot], for eventId: String) {
        let currentUserId = Auth.auth().currentUser?.uid
        var processedPhotos: [PhotoContest] = []
        var userPhotoFound: PhotoContest? = nil
        
        print("📷 Processing \(documents.count) photo documents for event \(eventId)")
        
        if documents.isEmpty {
            DispatchQueue.main.async {
                self.photos = []
                self.userPhoto = nil
            }
            return
        }
        
        for document in documents {
            do {
                let data = document.data()
                
                // Using a different approach to handle the id field
                let photoId: String
                if let id = data["id"] as? String {
                    photoId = id
                } else {
                    photoId = document.documentID
                }
                
                guard let userId = data["userId"] as? String,
                      let userName = data["userName"] as? String,
                      let photoURL = data["photoURL"] as? String,
                      let caption = data["caption"] as? String,
                      let timestampData = data["timestamp"] as? Timestamp,
                      let expirationData = data["expirationTime"] as? Timestamp,
                      let likeCount = data["likeCount"] as? Int else {
                    print("❌ Skipping malformed photo document: \(document.documentID)")
                    continue
                }
                
                // Check if the current user has liked this photo
                let likes = data["likes"] as? [String: Bool] ?? [:]
                let userLiked = currentUserId != nil ? (likes[currentUserId!] ?? false) : false
                
                let timestamp = timestampData.dateValue()
                let expirationTime = expirationData.dateValue()
                
                // Skip expired photos
                if Date() > expirationTime {
                    print("📷 Skipping expired photo: \(photoId)")
                    continue
                }
                
                let photo = PhotoContest(
                    id: photoId,
                    eventId: eventId,
                    userId: userId,
                    userName: userName,
                    photoURL: photoURL,
                    caption: caption,
                    timestamp: timestamp,
                    expirationTime: expirationTime,
                    likeCount: likeCount,
                    userLiked: userLiked
                )
                
                processedPhotos.append(photo)
                
                // Check if this is the current user's photo
                if userId == currentUserId {
                    userPhotoFound = photo
                    print("📷 Found current user's photo: \(photoId)")
                }
            } catch {
                print("❌ Error processing photo document \(document.documentID): \(error.localizedDescription)")
            }
        }
        
        // Sort by likes (highest first) then by timestamp (newest first)
        processedPhotos.sort { 
            if $0.likeCount == $1.likeCount {
                return $0.timestamp > $1.timestamp
            }
            return $0.likeCount > $1.likeCount
        }
        
        print("📷 Processed \(processedPhotos.count) valid photos")
        
        DispatchQueue.main.async {
            self.photos = processedPhotos
            self.userPhoto = userPhotoFound
        }
    }
    
    // MARK: - Check Eligibility
    
    func checkUploadEligibility(for eventId: String, completion: @escaping (Result<Void, PhotoContestError>) -> Void) {
        // First, check if user is logged in
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(.failure(.notLoggedIn))
            return
        }
        
        // Special case for test-event-id - bypass checks for testing
        if eventId == "test-event-id" {
            print("📷 Special case: test-event-id - bypassing eligibility checks")
            userUploadCount = 0 // Reset for testing
            completion(.success(()))
            return
        }
        
        // When in DEBUG_MODE, bypass the event existence check
        if DEBUG_MODE {
            print("📷 DEBUG MODE: Bypassing event existence check for ID: \(eventId)")
            self.uploadWindowRemainingSeconds = 5 * 60 * 60 // 5 hours
            self.userUploadCount = 0 // Reset for testing
            completion(.success(()))
            return
        }
        
        // Check if the event exists and get its start time
        db.collection("events").document(eventId).getDocument { [weak self] snapshot, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Error fetching event: \(error.localizedDescription)")
                completion(.failure(.eventNotFound))
                return
            }
            
            guard let eventData = snapshot?.data() else {
                completion(.failure(.eventNotFound))
                return
            }
            
            // Check upload window (within 5 hours of event start)
            // In a real app, you'd have a proper start time field
            // For now, we'll use timestamp field if present, or creation date
            var eventStartTime: Date
            
            // For test-event-id, keep the window open
            if eventId == "test-event-id" {
                // For test events, set start time to 30 minutes ago
                eventStartTime = Date().addingTimeInterval(-30 * 60)
                
                // Update the published remaining time - give a full 5 hours for testing
                self.uploadWindowRemainingSeconds = self.uploadWindowDuration - (30 * 60)
                
                // Skip time check for test events
                print("📷 Test event ID detected - bypassing upload window check")
            } else if let timestamp = eventData["startTime"] as? Timestamp {
                eventStartTime = timestamp.dateValue()
            } else if let timestamp = eventData["timestamp"] as? Timestamp {
                eventStartTime = timestamp.dateValue()
            } else {
                // Default to 30 minutes ago for testing instead of 3 hours
                eventStartTime = Date().addingTimeInterval(-30 * 60)
            }
            
            // Calculate time since event started
            let timeSinceStart = Date().timeIntervalSince(eventStartTime)
            
            // Update the published remaining time
            self.uploadWindowRemainingSeconds = max(0, self.uploadWindowDuration - timeSinceStart)
            
            // Skip the time check for test-event-id or when in DEBUG_MODE
            if eventId == "test-event-id" || self.DEBUG_MODE {
                // In debug mode, always set a long remaining time
                self.uploadWindowRemainingSeconds = 5 * 60 * 60 // 5 hours
                print("📷 Debug mode active - bypassing upload window check")
                // Continue with user photo count check
            } else if timeSinceStart > self.uploadWindowDuration {
                // Upload window closed - more than 5 hours since event started
                print("📷 Upload window closed. Event started \(Int(timeSinceStart/3600)) hours ago")
                completion(.failure(.uploadWindowClosed))
                return
            }
            
            // Count how many photos the user has already uploaded for this event
            self.db.collection("photo_contests")
                .whereField("eventId", isEqualTo: eventId)
                .whereField("userId", isEqualTo: userId)
                .whereField("expirationTime", isGreaterThan: Timestamp(date: Date()))
                .getDocuments { [weak self] snapshot, error in
                    guard let self = self else { return }
                    
                    if let error = error {
                        print("Error checking for existing photos: \(error.localizedDescription)")
                        completion(.failure(.databaseError))
                        return
                    }
                    
                    guard let documents = snapshot?.documents else {
                        completion(.failure(.databaseError))
                        return
                    }
                    
                    // Count user's existing photos
                    let uploadCount = documents.count
                    self.userUploadCount = uploadCount
                    
                    // Check if user already has reached the maximum number of photos
                    if uploadCount >= self.maxPhotosPerUser {
                        print("📷 User has already uploaded \(uploadCount) photos (max: \(self.maxPhotosPerUser))")
                        completion(.failure(.userAlreadyUploaded))
                        return
                    }
                    
                    // Check if user has a valid ticket or check-in for this event
                    self.checkTicketOrCheckIn(userId: userId, eventId: eventId) { result in
                        switch result {
                        case .success:
                            completion(.success(()))
                        case .failure(let error):
                            completion(.failure(error))
                        }
                    }
                }
        }
    }
    
    private func checkTicketOrCheckIn(userId: String, eventId: String, completion: @escaping (Result<Void, PhotoContestError>) -> Void) {
        print("📷 Checking ticket or check-in for user: \(userId), event: \(eventId)")
        
        // For demo purposes, first check if CheckInManager is available and if the user has checked in
        if CheckInManager.shared.hasCheckedInToEvent(eventId: eventId) {
            print("📷 User has checked in to the event")
            completion(.success(()))
            return
        }
        
        print("📷 User not checked in, checking for a ticket")
        
        // Check if they have a ticket
        db.collection("tickets")
            .whereField("userId", isEqualTo: userId)
            .whereField("eventId", isEqualTo: eventId)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { 
                    print("❌ Self is nil in ticket check")
                    completion(.failure(.serverError))
                    return 
                }
                
                if let error = error {
                    print("❌ Error checking for tickets: \(error.localizedDescription)")
                    completion(.failure(.serverError))
                    return
                }
                
                // For development, if no tickets found, let's allow uploads anyway
                // In production, you'd want to require a ticket
                if let documents = snapshot?.documents, !documents.isEmpty {
                    print("📷 User has a ticket for the event")
                    completion(.success(()))
                } else {
                    print("⚠️ No ticket found, but allowing upload for development")
                    // In development mode, allow uploads even without a ticket
                    #if DEBUG
                    completion(.success(()))
                    #else
                    completion(.failure(.notEligible))
                    #endif
                }
            }
    }
    
    // MARK: - Upload Photo
    
    func uploadPhoto(for eventId: String, image: UIImage, caption: String, completion: @escaping (Result<String, PhotoContestError>) -> Void) {
        print("📷 Starting photo upload process for event: \(eventId)")
        
        DispatchQueue.main.async {
            self.isLoading = true
            self.error = nil
        }
        
        // First check if user is eligible to upload
        checkUploadEligibility(for: eventId) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success:
                print("📷 User eligible to upload photo for event: \(eventId)")
                self.performPhotoUpload(eventId: eventId, image: image, caption: caption) { result in
                    DispatchQueue.main.async {
                        self.isLoading = false
                    }
                    completion(result)
                }
            case .failure(let error):
                print("❌ Upload eligibility check failed: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.error = error
                }
                completion(.failure(error))
            }
        }
    }
    
    private func performPhotoUpload(eventId: String, image: UIImage, caption: String, completion: @escaping (Result<String, PhotoContestError>) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("❌ Upload failed: User not logged in")
            completion(.failure(.notLoggedIn))
            return
        }
        
        // Compress and prepare the image
        guard let imageData = prepareImageForUpload(image: image) else {
            print("❌ Upload failed: Could not prepare image data")
            completion(.failure(.invalidImage))
            return
        }
        
        // Check image size
        if imageData.count > maxImageSizeBytes {
            print("❌ Upload failed: Image size too large (\(imageData.count) bytes)")
            completion(.failure(.maxSizeExceeded))
            return
        }
        
        print("📷 Image prepared successfully: \(imageData.count) bytes")
        
        // Get user name
        db.collection("users").document(userId).getDocument { [weak self] snapshot, error in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ Upload failed: Error fetching user data: \(error.localizedDescription)")
                completion(.failure(.databaseError))
                return
            }
            
            let userName = snapshot?.data()?["name"] as? String ?? "Anonymous"
            print("📷 Retrieved user name: \(userName)")
            
            // Generate unique photo ID
            let photoId = UUID().uuidString
            let photoRef = self.storage.child("photo_contests/\(eventId)/\(photoId).jpg")
            
            // Create metadata with content type
            let metadata = StorageMetadata()
            metadata.contentType = "image/jpeg"
            
            print("📷 Starting Firebase Storage upload for photo ID: \(photoId)")
            
            // Upload photo to Firebase Storage
            let uploadTask = photoRef.putData(imageData, metadata: metadata) { metadata, error in
                if let error = error {
                    print("❌ Storage upload failed: \(error.localizedDescription)")
                    completion(.failure(.uploadFailed))
                    return
                }
                
                print("📷 Firebase Storage upload successful, getting download URL")
                
                // Get download URL
                photoRef.downloadURL { url, error in
                    if let error = error {
                        print("❌ Failed to get download URL: \(error.localizedDescription)")
                        completion(.failure(.uploadFailed))
                        return
                    }
                    
                    guard let downloadURL = url else {
                        print("❌ Download URL is nil")
                        completion(.failure(.uploadFailed))
                        return
                    }
                    
                    print("📷 Got download URL: \(downloadURL.absoluteString)")
                    
                    // Cache the download URL
                    self.downloadURLCache[photoId] = downloadURL
                    
                    // Calculate expiration time - 16 hours from now
                    let now = Date()
                    let expirationTime = now.addingTimeInterval(self.photoLifetimeInSeconds)
                    
                    print("📷 Creating Firestore document for photo")
                    
                    // Create photo entry in Firestore
                    let photoData: [String: Any] = [
                        "id": photoId,
                        "eventId": eventId,
                        "userId": userId,
                        "userName": userName,
                        "photoURL": downloadURL.absoluteString,
                        "caption": caption,
                        "timestamp": Timestamp(date: now),
                        "expirationTime": Timestamp(date: expirationTime),
                        "likeCount": 0,
                        "likes": [:],
                        "scheduledForDeletion": false
                    ]
                    
                    // Save to Firestore
                    self.db.collection("photo_contests").document(photoId).setData(photoData) { error in
                        if let error = error {
                            print("❌ Failed to save photo data to Firestore: \(error.localizedDescription)")
                            completion(.failure(.databaseError))
                            return
                        }
                        
                        print("📷 Photo data saved to Firestore successfully")
                        
                        // Schedule deletion of the photo after 16 hours
                        self.schedulePhotoDeletion(photoId: photoId, storageRef: photoRef, expirationTime: expirationTime)
                        
                        // Create a local PhotoContest object and update userPhoto
                        let photoContest = PhotoContest(
                            id: photoId,
                            eventId: eventId,
                            userId: userId,
                            userName: userName,
                            photoURL: downloadURL.absoluteString,
                            caption: caption,
                            timestamp: now,
                            expirationTime: expirationTime,
                            likeCount: 0
                        )
                        
                        DispatchQueue.main.async {
                            self.userPhoto = photoContest
                            
                            // Add to photos array if not already present
                            if !self.photos.contains(where: { $0.id == photoId }) {
                                self.photos.append(photoContest)
                                // Sort photos
                                self.photos.sort { 
                                    if $0.likeCount == $1.likeCount {
                                        return $0.timestamp > $1.timestamp
                                    }
                                    return $0.likeCount > $1.likeCount
                                }
                            }
                        }
                        
                        print("📷 Photo upload process completed successfully")
                        completion(.success(photoId))
                    }
                }
            }
            
            // Track upload progress (could be used to show progress in the UI)
            uploadTask.observe(.progress) { snapshot in
                guard let progress = snapshot.progress else { return }
                let percentComplete = 100.0 * Double(progress.completedUnitCount) / Double(progress.totalUnitCount)
                print("📷 Upload progress: \(percentComplete)%")
            }
        }
    }
    
    private func prepareImageForUpload(image: UIImage) -> Data? {
        // Resize the image if needed (maximum dimension 1200 pixels)
        let maxDimension: CGFloat = 1200
        var scaledImage = image
        
        if image.size.width > maxDimension || image.size.height > maxDimension {
            let scaleFactor = maxDimension / max(image.size.width, image.size.height)
            let newWidth = image.size.width * scaleFactor
            let newHeight = image.size.height * scaleFactor
            let newSize = CGSize(width: newWidth, height: newHeight)
            
            UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
            image.draw(in: CGRect(origin: .zero, size: newSize))
            if let resizedImage = UIGraphicsGetImageFromCurrentImageContext() {
                scaledImage = resizedImage
            }
            UIGraphicsEndImageContext()
        }
        
        // Compress to JPEG with decreasing quality until the size is acceptable
        for quality in stride(from: 0.8, to: 0.4, by: -0.1) {
            if let data = scaledImage.jpegData(compressionQuality: quality) {
                if data.count <= maxImageSizeBytes {
                    return data
                }
            }
        }
        
        // If still too large, return the most compressed version
        return scaledImage.jpegData(compressionQuality: 0.4)
    }
    
    // MARK: - Fetch Photos
    
    // Fetch real photos for test-event-id from Firestore
    private func fetchRealPhotosForTestEvent() {
        print("📷 Fetching real photos for test-event-id from Firestore")
        
        db.collection("photo_contests")
            .whereField("eventId", isEqualTo: "test-event-id")
            .whereField("expirationTime", isGreaterThan: Timestamp(date: Date()))
            .whereField("scheduledForDeletion", isEqualTo: false)
            .order(by: "expirationTime")
            .order(by: "likeCount", descending: true)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ Error fetching real test photos: \(error.localizedDescription)")
                    return
                }
                
                if let documents = snapshot?.documents, !documents.isEmpty {
                    print("📷 Found \(documents.count) real photos for test-event-id")
                    self.processPhotoDocuments(documents, for: "test-event-id")
                } else {
                    print("📷 No real photos found for test-event-id, will keep any existing photos")
                    // Only use mock photos if we don't have any real ones
                    if self.photos.isEmpty {
                        print("📷 Creating mock photos since no real ones exist")
                        self.createMockPhotosForTestEvent()
                    }
                }
            }
    }
    
    func fetchPhotos(for eventId: String, completion: @escaping (Result<[PhotoContest], PhotoContestError>) -> Void) {
        // Special handling for test-event-id
        if eventId == "test-event-id" {
            print("📷 Fetching real photos for test-event-id")
            isLoading = true
            
            // Check for real photos first
            db.collection("photo_contests")
                .whereField("eventId", isEqualTo: "test-event-id")
                .whereField("expirationTime", isGreaterThan: Timestamp(date: Date()))
                .whereField("scheduledForDeletion", isEqualTo: false)
                .order(by: "expirationTime")
                .order(by: "likeCount", descending: true)
                .getDocuments { [weak self] snapshot, error in
                    guard let self = self else { return }
                    
                    DispatchQueue.main.async {
                        self.isLoading = false
                    }
                    
                    if let error = error {
                        print("❌ Error fetching real test photos: \(error.localizedDescription)")
                        // Create mock photos anyway if we hit an error
                        self.createMockPhotosForTestEvent()
                        completion(.success(self.photos))
                        return
                    }
                    
                    if let documents = snapshot?.documents, !documents.isEmpty {
                        print("📷 Found \(documents.count) real photos for test-event-id")
                        self.processPhotoDocuments(documents, for: "test-event-id")
                        completion(.success(self.photos))
                    } else {
                        print("📷 No real photos found for test-event-id, creating mock photos")
                        // Always create mock photos for test-event-id when no real ones exist
                        self.createMockPhotosForTestEvent()
                        completion(.success(self.photos))
                    }
                }
            return
        }
        
        isLoading = true
        print("📷 Fetching photos for eventId: \(eventId)")
        
        let queryEventId = eventId
        print("📷 Using queryEventId: \(queryEventId) for Firestore query")
        
        db.collection("photo_contests")
            .whereField("eventId", isEqualTo: queryEventId)
            .whereField("expirationTime", isGreaterThan: Timestamp(date: Date()))
            .whereField("scheduledForDeletion", isEqualTo: false)
            .order(by: "expirationTime")
            .order(by: "likeCount", descending: true)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                
                DispatchQueue.main.async {
                    self.isLoading = false
                }
                
                if let error = error {
                    print("❌ Error fetching photos: \(error.localizedDescription)")
                    completion(.failure(.fetchFailed))
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("📷 No documents found")
                    self.photos = []
                    completion(.success([]))
                    return
                }
                
                print("📷 Found \(documents.count) photo documents for eventId: \(queryEventId)")
                
                if documents.isEmpty {
                    print("📷 No photos found for regular event ID, clearing photos array")
                    DispatchQueue.main.async {
                        self.photos = []
                        self.userPhoto = nil
                    }
                    completion(.success([]))
                } else {
                    self.processPhotoDocuments(documents, for: queryEventId)
                    completion(.success(self.photos))
                }
            }
    }
    
    // Create mock photo data for test-event-id
    private func createMockPhotosForTestEvent() {
        print("📷 Creating mock photos for test-event-id")
        
        // Generate current user information
        let currentUserId = Auth.auth().currentUser?.uid ?? "anonymous"
        let userName = Auth.auth().currentUser?.displayName ?? "Test User"
        
        // Create test expiration time - 16 hours from now
        let now = Date()
        let expirationTime = now.addingTimeInterval(self.photoLifetimeInSeconds)
        
        // Create some sample photos
        let mockPhotos = [
            PhotoContest(
                id: "test-photo-1",
                eventId: "test-event-id",
                userId: currentUserId,
                userName: userName,
                photoURL: "https://firebasestorage.googleapis.com/v0/b/bondfyr-da123.appspot.com/o/sample%2Ftest_photo.jpg?alt=media",
                caption: "This is a test photo",
                timestamp: now.addingTimeInterval(-3600),
                expirationTime: expirationTime,
                likeCount: 15,
                userLiked: true
            ),
            PhotoContest(
                id: "test-photo-2",
                eventId: "test-event-id",
                userId: "other-user-1",
                userName: "John Doe",
                photoURL: "https://firebasestorage.googleapis.com/v0/b/bondfyr-da123.appspot.com/o/sample%2Ftest_photo.jpg?alt=media",
                caption: "This is a test photo",
                timestamp: now.addingTimeInterval(-7200),
                expirationTime: expirationTime,
                likeCount: 8,
                userLiked: false
            ),
            PhotoContest(
                id: "test-photo-3",
                eventId: "test-event-id",
                userId: "other-user-2",
                userName: "Jane Smith",
                photoURL: "https://firebasestorage.googleapis.com/v0/b/bondfyr-da123.appspot.com/o/sample%2Ftest_photo.jpg?alt=media",
                caption: "This is a test photo",
                timestamp: now.addingTimeInterval(-10800),
                expirationTime: expirationTime,
                likeCount: 23,
                userLiked: true
            )
        ]
        
        // Set the photos
        DispatchQueue.main.async {
            self.photos = mockPhotos
            
            // Set the user's photo
            let userPhotos = mockPhotos.filter { $0.userId == currentUserId }
            self.userPhoto = userPhotos.first
            
            print("📷 Created \(mockPhotos.count) mock photos for test-event-id")
        }
    }
    
    // MARK: - Like/Unlike Photos
    
    func likePhoto(_ photoId: String, completion: @escaping (Result<Void, PhotoContestError>) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(.failure(.notLoggedIn))
            return
        }
        
        DispatchQueue.main.async {
            self.isLoading = true
            self.error = nil
        }
        
        // Reference to the photo document
        let photoRef = db.collection("photo_contests").document(photoId)
        
        // Perform transaction to atomically update likes
        db.runTransaction({ (transaction, errorPointer) -> Any? in
            // Get current photo data
            let photoDocument: DocumentSnapshot
            do {
                try photoDocument = transaction.getDocument(photoRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }
            
            guard let photoData = photoDocument.data() else {
                return nil
            }
            
            // Get current like count and likes map
            let currentLikes = photoData["likeCount"] as? Int ?? 0
            var likesMap = photoData["likes"] as? [String: Bool] ?? [:]
            
            // Check if user already liked
            if likesMap[userId] == true {
                // User already liked, do nothing
                return nil
            }
            
            // Add user to likes
            likesMap[userId] = true
            
            // Update document
            transaction.updateData([
                "likeCount": currentLikes + 1,
                "likes": likesMap
            ], forDocument: photoRef)
            
            return nil
        }) { [weak self] (_, error) in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isLoading = false
            }
            
            if let error = error {
                print("Error liking photo: \(error.localizedDescription)")
                self.error = .likeFailed
                completion(.failure(.likeFailed))
            } else {
                // Update local state
                DispatchQueue.main.async {
                    if let index = self.photos.firstIndex(where: { $0.id == photoId }) {
                        var updatedPhoto = self.photos[index]
                        updatedPhoto.userLiked = true
                        updatedPhoto = PhotoContest(
                            id: updatedPhoto.id,
                            eventId: updatedPhoto.eventId,
                            userId: updatedPhoto.userId,
                            userName: updatedPhoto.userName,
                            photoURL: updatedPhoto.photoURL,
                            caption: updatedPhoto.caption,
                            timestamp: updatedPhoto.timestamp,
                            expirationTime: updatedPhoto.expirationTime,
                            likeCount: updatedPhoto.likeCount + 1,
                            userLiked: true
                        )
                        self.photos[index] = updatedPhoto
                        
                        // If this is the user's photo, update userPhoto as well
                        if updatedPhoto.userId == userId {
                            self.userPhoto = updatedPhoto
                        }
                    }
                }
                
                completion(.success(()))
            }
        }
    }
    
    func unlikePhoto(_ photoId: String, completion: @escaping (Result<Void, PhotoContestError>) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(.failure(.notLoggedIn))
            return
        }
        
        DispatchQueue.main.async {
            self.isLoading = true
            self.error = nil
        }
        
        // Reference to the photo document
        let photoRef = db.collection("photo_contests").document(photoId)
        
        // Perform transaction to atomically update likes
        db.runTransaction({ (transaction, errorPointer) -> Any? in
            // Get current photo data
            let photoDocument: DocumentSnapshot
            do {
                try photoDocument = transaction.getDocument(photoRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }
            
            guard let photoData = photoDocument.data() else {
                return nil
            }
            
            // Get current like count and likes map
            let currentLikes = photoData["likeCount"] as? Int ?? 0
            var likesMap = photoData["likes"] as? [String: Bool] ?? [:]
            
            // Check if user liked
            if likesMap[userId] != true {
                // User hasn't liked, do nothing
                return nil
            }
            
            // Remove user from likes
            likesMap[userId] = false
            
            // Update document
            transaction.updateData([
                "likeCount": max(0, currentLikes - 1),
                "likes": likesMap
            ], forDocument: photoRef)
            
            return nil
        }) { [weak self] (_, error) in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isLoading = false
            }
            
            if let error = error {
                print("Error unliking photo: \(error.localizedDescription)")
                self.error = .unlikeFailed
                completion(.failure(.unlikeFailed))
            } else {
                // Update local state
                DispatchQueue.main.async {
                    if let index = self.photos.firstIndex(where: { $0.id == photoId }) {
                        var updatedPhoto = self.photos[index]
                        updatedPhoto.userLiked = false
                        updatedPhoto = PhotoContest(
                            id: updatedPhoto.id,
                            eventId: updatedPhoto.eventId,
                            userId: updatedPhoto.userId,
                            userName: updatedPhoto.userName,
                            photoURL: updatedPhoto.photoURL,
                            caption: updatedPhoto.caption,
                            timestamp: updatedPhoto.timestamp,
                            expirationTime: updatedPhoto.expirationTime,
                            likeCount: max(0, updatedPhoto.likeCount - 1),
                            userLiked: false
                        )
                        self.photos[index] = updatedPhoto
                        
                        // If this is the user's photo, update userPhoto as well
                        if updatedPhoto.userId == userId {
                            self.userPhoto = updatedPhoto
                        }
                    }
                }
                
                completion(.success(()))
            }
        }
    }
    
    // MARK: - Delete Photo
    
    func deletePhoto(_ photoId: String, completion: @escaping (Result<Void, PhotoContestError>) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(.failure(.notLoggedIn))
            return
        }
        
        DispatchQueue.main.async {
            self.isLoading = true
            self.error = nil
        }
        
        // Get the photo document to check if it belongs to the current user
        db.collection("photo_contests").document(photoId).getDocument { [weak self] snapshot, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Error getting photo: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.error = .databaseError
                }
                completion(.failure(.databaseError))
                return
            }
            
            guard let data = snapshot?.data(),
                  let photoOwnerId = data["userId"] as? String else {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.error = .databaseError
                }
                completion(.failure(.databaseError))
                return
            }
            
            // Check if the photo belongs to the current user
            if photoOwnerId != userId {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.error = .unauthorized
                }
                completion(.failure(.unauthorized))
                return
            }
            
            // Mark the photo as deleted in Firestore
            self.db.collection("photo_contests").document(photoId).updateData([
                "scheduledForDeletion": true
            ]) { error in
                if let error = error {
                    print("Error marking photo for deletion: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        self.isLoading = false
                        self.error = .deletionFailed
                    }
                    completion(.failure(.deletionFailed))
                    return
                }
                
                // Delete the photo from storage
                let photoRef = self.storage.child("photo_contests/\(data["eventId"] as? String ?? "")/\(photoId).jpg")
                photoRef.delete { error in
                    DispatchQueue.main.async {
                        self.isLoading = false
                    }
                    
                    if let error = error {
                        print("Error deleting photo from storage: \(error.localizedDescription)")
                        // Storage deletion failed, but Firestore updated successfully
                        // Consider this partial success
                        
                        // Update local state
                        DispatchQueue.main.async {
                            self.photos.removeAll { $0.id == photoId }
                            if self.userPhoto?.id == photoId {
                                self.userPhoto = nil
                            }
                        }
                        
                        completion(.success(()))
                    } else {
                        print("Photo deleted successfully")
                        
                        // Update local state
                        DispatchQueue.main.async {
                            self.photos.removeAll { $0.id == photoId }
                            if self.userPhoto?.id == photoId {
                                self.userPhoto = nil
                            }
                        }
                        
                        completion(.success(()))
                    }
                }
            }
        }
    }
    
    // MARK: - Cleanup
    
    // Schedule photo deletion
    private func schedulePhotoDeletion(photoId: String, storageRef: StorageReference, expirationTime: Date) {
        // This is a placeholder for a server-side function that would handle
        // scheduled deletion in a production app
        
        // In a real implementation, you would use Cloud Functions to automatically
        // delete expired photos after the expiration time
        print("Scheduled photo \(photoId) for deletion at \(expirationTime)")
    }
}
