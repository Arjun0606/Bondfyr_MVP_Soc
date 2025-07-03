import Foundation
import FirebaseStorage
import FirebaseFirestore
import FirebaseAuth
import UIKit
import SwiftUI
import Combine
import BondfyrPhotos

@MainActor
class PhotoManager: ObservableObject {
    static let shared = PhotoManager()
    
    // MARK: - Published Properties
    @Published var cityPhotos: [CityPhoto] = []
    @Published var dailyPhotos: [DailyPhoto] = []
    @Published var contestPhotos: [EventPhoto] = []
    @Published var isLoading = false
    @Published var error: Error?
    @Published var hasPostedToday = false
    @Published var contestTimeRemaining: TimeInterval = 0
    @Published var isEligibleForContest = false
    
    // MARK: - Private Properties
    private let storage = Storage.storage()
    private let db = Firestore.firestore()
    private var cityPhotosListener: ListenerRegistration?
    private var contestTimer: Timer?
    
    init() {
        // Start cleanup timer for expired photos
        Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.cleanupExpiredPhotos()
        }
        checkDailyPostStatus()
        setupContestTimer()
    }
    
    // MARK: - City Photos
    
    func uploadCityPhoto(image: UIImage, photo: CityPhoto) async throws {
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            throw PhotoError.imageCompressionFailed
        }
        
        // Upload image to Storage
        let storageRef = storage.reference().child("city_photos/\(photo.id).jpg")
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        _ = try await storageRef.putDataAsync(imageData, metadata: metadata)
        let imageUrl = try await storageRef.downloadURL().absoluteString
        
        // Create photo document in Firestore
        var updatedPhoto = photo
        updatedPhoto.imageUrl = imageUrl
        
        try await db.collection("city_photos").document(photo.id).setData([
            "id": updatedPhoto.id,
            "imageUrl": updatedPhoto.imageUrl,
            "city": updatedPhoto.city,
            "timestamp": updatedPhoto.timestamp,
            "likes": updatedPhoto.likes,
            "expiresAt": updatedPhoto.expiresAt
        ])
    }
    
    func startListeningToCityPhotos(city: String) {
        cityPhotosListener?.remove()
        
        cityPhotosListener = db.collection("city_photos")
            .whereField("city", isEqualTo: city)
            .whereField("expiresAt", isGreaterThan: Date())
            .order(by: "expiresAt")
            .order(by: "timestamp", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    self?.error = error
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                self?.cityPhotos = documents.compactMap { document -> CityPhoto? in
                    try? document.data(as: CityPhoto.self)
                }
            }
    }
    
    func stopListeningToCityPhotos() {
        cityPhotosListener?.remove()
        cityPhotosListener = nil
    }
    
    func likePhoto(_ photo: CityPhoto) async throws {
        let ref = db.collection("city_photos").document(photo.id)
        try await ref.updateData([
            "likes": FieldValue.increment(Int64(1))
        ])
    }
    
    // MARK: - Daily Photos
    
    private func checkDailyPostStatus() {
        guard let userID = Auth.auth().currentUser?.uid else { return }
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let query = db.collection("photos")
            .whereField("userID", isEqualTo: userID)
            .whereField("timestamp", isGreaterThanOrEqualTo: Timestamp(date: startOfDay))
            .whereField("timestamp", isLessThan: Timestamp(date: endOfDay))
        
        query.getDocuments { [weak self] snapshot, error in
            if let error = error {
                self?.error = error
                return
            }
            
            DispatchQueue.main.async {
                self?.hasPostedToday = !(snapshot?.documents.isEmpty ?? true)
            }
        }
    }
    
    func uploadDailyPhoto(image: UIImage, photo: DailyPhoto) async throws {
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            throw PhotoError.imageCompressionFailed
        }
        
        // Upload image to Storage
        let storageRef = storage.reference().child("daily_photos/\(photo.id).jpg")
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        _ = try await storageRef.putDataAsync(imageData, metadata: metadata)
        let imageUrl = try await storageRef.downloadURL().absoluteString
        
        // Create photo document in Firestore
        try await db.collection("daily_photos").document(photo.id).setData([
            "id": photo.id,
            "photoURL": imageUrl,
            "userID": photo.userID,
            "userHandle": photo.userHandle,
            "city": photo.city,
            "country": photo.country,
            "timestamp": photo.timestamp,
            "likes": photo.likes,
            "likedBy": photo.likedBy
        ])
    }
    
    // MARK: - Contest Photos
    
    private func setupContestTimer() {
        contestTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.updateContestTimeRemaining()
        }
    }
    
    private func updateContestTimeRemaining() {
        let contestEnd = Date().addingTimeInterval(24 * 3600)
        contestTimeRemaining = max(0, contestEnd.timeIntervalSinceNow)
    }
    
    func checkContestEligibility() async {
        guard let userId = Auth.auth().currentUser?.uid else {
            isEligibleForContest = false
            return
        }
        
        do {
            let query = db.collection("contest_photos")
                .whereField("user_id", isEqualTo: userId)
            
            let snapshot = try await query.getDocuments()
            isEligibleForContest = snapshot.documents.isEmpty
        } catch {
            
            isEligibleForContest = false
        }
    }
    
    // MARK: - Cleanup
    
    private func cleanupExpiredPhotos() {
        Task {
            do {
                let snapshot = try await db.collection("city_photos")
                    .whereField("expiresAt", isLessThan: Date())
                    .getDocuments()
                
                for document in snapshot.documents {
                    if let photo = try? document.data(as: CityPhoto.self) {
                        let storageRef = storage.reference().child("city_photos/\(photo.id).jpg")
                        try? await storageRef.delete()
                        try await document.reference.delete()
                    }
                }
            } catch {
                
            }
        }
    }
}