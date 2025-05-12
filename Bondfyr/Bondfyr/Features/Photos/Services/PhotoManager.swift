import Foundation
import UIKit
import FirebaseFirestore
import FirebaseStorage
import FirebaseAuth
import Combine
import SwiftUI

@MainActor
final class PhotoManager: ObservableObject {
    static let shared = PhotoManager()
    
    @Published var cityPhotos: [DailyPhoto] = []
    @Published var countryPhotos: [DailyPhoto] = []
    @Published var worldPhotos: [DailyPhoto] = []
    @Published var contestPhotos: [EventPhoto] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var hasPostedToday = false
    @Published var contestTimeRemaining: TimeInterval = 0
    @Published var isEligibleForContest = false
    
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    private var contestTimer: Timer?
    
    private init() {
        checkDailyPostStatus()
        setupContestTimer()
    }
    
    private func setupContestTimer() {
        // Update contest time every second
        contestTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.updateContestTimeRemaining()
        }
    }
    
    private func updateContestTimeRemaining() {
        // For now, just set a fixed contest duration (e.g., 24 hours from event start)
        // In a real app, this would fetch from your backend
        let contestEnd = Date().addingTimeInterval(24 * 3600) // 24 hours from now
        contestTimeRemaining = max(0, contestEnd.timeIntervalSinceNow)
    }
    
    func checkContestEligibility() async {
        guard let userId = Auth.auth().currentUser?.uid else {
            isEligibleForContest = false
            return
        }
        
        do {
            let query = db.collection("contest_photos")
                .whereField(FieldPath(["user_id"]), isEqualTo: userId)
            
            let snapshot = try await query.getDocuments()
            isEligibleForContest = snapshot.documents.isEmpty
        } catch {
            print("Error checking contest eligibility: \(error)")
            isEligibleForContest = false
        }
    }
    
    private func checkDailyPostStatus() {
        guard let userID = Auth.auth().currentUser?.uid else { return }
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let query = db.collection("photos")
            .whereField(FieldPath(["user_id"]), isEqualTo: userID)
            .whereField(FieldPath(["timestamp"]), isGreaterThanOrEqualTo: Timestamp(date: startOfDay))
            .whereField(FieldPath(["timestamp"]), isLessThan: Timestamp(date: endOfDay))
        
        query.getDocuments { [weak self] snapshot, error in
            if let error = error {
                self?.error = error.localizedDescription
                return
            }
            
            DispatchQueue.main.async {
                self?.hasPostedToday = !(snapshot?.documents.isEmpty ?? true)
            }
        }
    }
    
    func fetchPhotos(scope: DailyPhotoScope) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let photos = try await fetchPhotosForScope(scope)
            switch scope {
            case .city:
                cityPhotos = photos
            case .country:
                countryPhotos = photos
            case .world:
                worldPhotos = photos
            }
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    private func fetchPhotosForScope(_ scope: DailyPhotoScope) async throws -> [DailyPhoto] {
        // Get the start of the current day
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        
        var query = db.collection("photos")
            .whereField(FieldPath(["timestamp"]), isGreaterThanOrEqualTo: Timestamp(date: startOfDay))
            .order(by: "timestamp", descending: true)
        
        // Add scope-specific filters
        switch scope {
        case .city:
            guard let city = UserDefaults.standard.string(forKey: "selectedCity") else {
                throw PhotoError.invalidScope
            }
            query = query.whereField(FieldPath(["city"]), isEqualTo: city)
        case .country:
            guard let country = UserDefaults.standard.string(forKey: "selectedCountry") else {
                throw PhotoError.invalidScope
            }
            query = query.whereField(FieldPath(["country"]), isEqualTo: country)
        case .world:
            // No additional filters for world scope
            break
        }
        
        let snapshot = try await query.getDocuments()
        return try snapshot.documents.map { document in
            let data = document.data()
            return DailyPhoto(
                id: document.documentID,
                photoURL: data["photoURL"] as? String ?? "",
                userID: data["userID"] as? String ?? "",
                userHandle: data["userHandle"] as? String ?? "",
                city: data["city"] as? String ?? "",
                country: data["country"] as? String ?? "",
                timestamp: (data["timestamp"] as? Timestamp)?.dateValue() ?? Date(),
                likes: data["likes"] as? Int ?? 0,
                likedBy: data["likedBy"] as? [String] ?? []
            )
        }
    }
    
    func toggleLike(for photo: DailyPhoto) async {
        guard let userID = Auth.auth().currentUser?.uid else {
            error = "User not authenticated"
            return
        }
        
        do {
            let photoRef = db.collection("photos").document(photo.id)
            let wasLiked = photo.likedBy.contains(userID)
            
            _ = try await db.runTransaction { (transaction, errorPointer) -> Any? in
                do {
                    let photoDoc = try transaction.getDocument(photoRef)
                    guard var likedBy = photoDoc.data()?["likedBy"] as? [String] else {
                        return nil
                    }
                    
                    if wasLiked {
                        likedBy.removeAll { $0 == userID }
                    } else {
                        likedBy.append(userID)
                    }
                    
                    transaction.updateData([
                        "likes": likedBy.count,
                        "likedBy": likedBy
                    ], forDocument: photoRef)
                    
                    return nil
                } catch {
                    if let errorPointer = errorPointer {
                        errorPointer.pointee = error as NSError
                    }
                    return nil
                }
            }
            
            // Update local state
            await fetchPhotos(scope: .city) // Refresh city photos
            await fetchPhotos(scope: .country) // Refresh country photos
            await fetchPhotos(scope: .world) // Refresh world photos
            
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    func uploadDailyPhoto(photo: UIImage) async throws -> String {
        guard let imageData = photo.jpegData(compressionQuality: 0.7) else {
            throw PhotoError.invalidImageData
        }
        
        let photoID = UUID().uuidString
        let storageRef = storage.reference().child("daily_photos/\(photoID).jpg")
        
        // Upload image
        _ = try await storageRef.putDataAsync(imageData, metadata: nil)
        let downloadURL = try await storageRef.downloadURL()
        
        // Create photo document
        let photo = [
            "id": photoID,
            "photoURL": downloadURL.absoluteString,
            "userID": Auth.auth().currentUser?.uid ?? "",
            "userHandle": UserDefaults.standard.string(forKey: "userHandle") ?? "anonymous",
            "city": UserDefaults.standard.string(forKey: "selectedCity") ?? "Unknown",
            "country": UserDefaults.standard.string(forKey: "selectedCountry") ?? "Unknown",
            "timestamp": Timestamp(date: Date()),
            "likes": 0,
            "likedBy": []
        ] as [String: Any]
        
        try await db.collection("daily_photos").document(photoID).setData(photo)
        hasPostedToday = true
        return photoID
    }
    
    func cleanupExpiredPhotos() async {
        let calendar = Calendar.current
        let oneDayAgo = calendar.date(byAdding: .day, value: -1, to: Date())!
        
        let expiredPhotosQuery = db.collection("daily_photos")
            .whereField(FieldPath(["timestamp"]), isLessThan: Timestamp(date: oneDayAgo))
        
        do {
            let snapshot = try await expiredPhotosQuery.getDocuments()
            for document in snapshot.documents {
                if let photoURL = document.data()["photoURL"] as? String {
                    // Delete from Storage
                    let storageRef = storage.reference(withPath: photoURL)
                    try? await storageRef.delete()
                }
                // Delete from Firestore
                try await document.reference.delete()
            }
        } catch {
            print("Error cleaning up expired photos: \(error.localizedDescription)")
        }
    }
    
    func fetchContestPhotos(for eventId: String) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let snapshot = try await db.collection("photo_contests")
                .whereField("eventId", isEqualTo: eventId)
                .order(by: "timestamp", descending: true)
                .getDocuments()
            
            contestPhotos = snapshot.documents.compactMap { document in
                let data = document.data()
                
                guard let userId = data["userId"] as? String,
                      let imageUrl = data["imageUrl"] as? String,
                      let timestamp = (data["timestamp"] as? Timestamp)?.dateValue() else {
                    return nil
                }
                
                return EventPhoto(
                    id: document.documentID,
                    eventId: eventId,
                    uploaderId: userId,
                    imageUrl: imageUrl,
                    timestamp: timestamp,
                    likes: data["likeCount"] as? Int ?? 0,
                    isContestEntry: true
                )
            }
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    func uploadPhoto(photo: UIImage, eventId: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard let imageData = photo.jpegData(compressionQuality: 0.7) else {
            completion(.failure(PhotoError.invalidImageData))
            return
        }
        
        let photoID = UUID().uuidString
        let storageRef = storage.reference().child("ugc_photos/\(eventId)/\(photoID).jpg")
        
        // Create metadata
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        // Upload the image
        storageRef.putData(imageData, metadata: metadata) { metadata, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            // Get download URL
            storageRef.downloadURL { url, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let downloadURL = url else {
                    completion(.failure(PhotoError.downloadURLMissing))
                    return
                }
                
                // Create photo document
                let photo: [String: Any] = [
                    "id": photoID,
                    "eventId": eventId,
                    "photoURL": downloadURL.absoluteString,
                    "userID": Auth.auth().currentUser?.uid ?? "",
                    "userHandle": UserDefaults.standard.string(forKey: "userHandle") ?? "anonymous",
                    "city": UserDefaults.standard.string(forKey: "selectedCity") ?? "Unknown",
                    "country": UserDefaults.standard.string(forKey: "selectedCountry") ?? "Unknown",
                    "timestamp": Timestamp(date: Date()),
                    "likes": 0,
                    "likedBy": []
                ]
                
                // Save to Firestore
                self.db.collection("ugc_photos").document(photoID).setData(photo) { error in
                    if let error = error {
                        completion(.failure(error))
                        return
                    }
                    completion(.success(photoID))
                }
            }
        }
    }
    
    deinit {
        contestTimer?.invalidate()
    }
} 