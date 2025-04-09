//
//  PhotoManager.swift
//  Bondfyr
//
//  Created by Arjun Varma on 31/03/25.
//

import Foundation
import UIKit
import FirebaseFirestore
import FirebaseStorage
import FirebaseAuth
import Combine

// Simple data model for photo gallery
struct GalleryPhoto: Identifiable {
    var id: String
    var imageUrl: String
    var eventId: String
    var timestamp: Date
    var likes: Int
    var isContestEntry: Bool
}

class PhotoManager: ObservableObject {
    static let shared = PhotoManager() // Singleton instance
    
    @Published var photos: [GalleryPhoto] = []
    @Published var contestActive: Bool = false
    @Published var contestEndTime: Date?
    @Published var contestEventId: String?
    
    private let db = Firestore.firestore()
    private let storage = Storage.storage().reference()
    private var contestListener: ListenerRegistration?
    
    private init() {
        setupContestListener()
    }
    
    private func setupContestListener() {
        // For testing, use a direct approach without the Firestore listener that's failing
        print("Setting up contest listener with direct approach instead of Firestore listener")
        
        // Simulate an active contest for testing
        self.contestActive = true
        self.contestEventId = "test-event-id"
        self.contestEndTime = Date().addingTimeInterval(300) // 5 minutes from now
        
        // Notify eligible users about the test contest
        self.notifyEligibleUsers()
    }
    
    private func notifyEligibleUsers() {
        guard let eventId = contestEventId else { return }
        
        // Check if user is checked in at this event
        CheckInManager.shared.fetchActiveCheckIn()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if let activeCheckIn = CheckInManager.shared.activeCheckIn, 
               activeCheckIn.eventId == eventId {
                // User is checked in at this event - trigger notification
                NotificationManager.shared.scheduleContestNotification(forEvent: eventId)
            }
        }
    }
    
    // Check if user is eligible for contest - for testing always return true
    func isUserEligibleForContest() -> Bool {
        // For testing purposes, always return true
        return true
    }
    
    func uploadContestPhoto(imageData: Data, completion: @escaping (Bool) -> Void) {
        // Simulate upload success after a short delay
        print("Simulating contest photo upload")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            print("Contest photo upload successful (simulated)")
            completion(true)
        }
    }
    
    // MARK: - Photo Management
    
    // Upload a photo
    func uploadPhoto(photo: UIImage, eventId: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid, 
              let imageData = photo.jpegData(compressionQuality: 0.7) else {
            completion(.failure(NSError(domain: "PhotoManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to prepare image"])))
            return
        }
        
        let photoId = UUID().uuidString
        let photoRef = storage.child("event_photos/\(eventId)/\(photoId).jpg")
        
        photoRef.putData(imageData, metadata: nil) { _, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            photoRef.downloadURL { url, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let downloadURL = url else {
                    completion(.failure(NSError(domain: "PhotoManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to get download URL"])))
                    return
                }
                
                let photoData: [String: Any] = [
                    "userId": userId,
                    "eventId": eventId,
                    "imageUrl": downloadURL.absoluteString,
                    "timestamp": FieldValue.serverTimestamp(),
                    "likes": 0,
                    "isContestEntry": true
                ]
                
                self.db.collection("event_photos").document(photoId).setData(photoData) { error in
                    if let error = error {
                        completion(.failure(error))
                    } else {
                        completion(.success(photoId))
                    }
                }
            }
        }
    }
    
    // Like a photo
    func likePhoto(photo: GalleryPhoto) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        let likeId = "\(userId)_\(photo.id)"
        
        // Add like document
        db.collection("photo_likes").document(likeId).setData([
            "userId": userId,
            "photoId": photo.id,
            "timestamp": FieldValue.serverTimestamp()
        ])
        
        // Increment likes count
        db.collection("event_photos").document(photo.id).updateData([
            "likes": FieldValue.increment(Int64(1))
        ])
    }
    
    // Unlike a photo
    func unlikePhoto(photo: GalleryPhoto) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        let likeId = "\(userId)_\(photo.id)"
        
        // Remove like document
        db.collection("photo_likes").document(likeId).delete()
        
        // Decrement likes count
        db.collection("event_photos").document(photo.id).updateData([
            "likes": FieldValue.increment(Int64(-1))
        ])
    }
    
    // Check if user liked a photo
    func checkIfUserLikedPhoto(photo: GalleryPhoto, completion: @escaping (Bool) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(false)
            return
        }
        
        let likeId = "\(userId)_\(photo.id)"
        
        db.collection("photo_likes").document(likeId).getDocument { snapshot, error in
            completion(snapshot?.exists == true)
        }
    }
    
    // Get photos for an event
    func getPhotos(for eventId: String, completion: @escaping ([GalleryPhoto]) -> Void) {
        db.collection("event_photos")
            .whereField("eventId", isEqualTo: eventId)
            .order(by: "timestamp", descending: true)
            .getDocuments { snapshot, error in
                guard let documents = snapshot?.documents, error == nil else {
                    completion([])
                    return
                }
                
                let photos = documents.compactMap { document -> GalleryPhoto? in
                    let data = document.data()
                    
                    guard let imageUrl = data["imageUrl"] as? String,
                          let timestamp = (data["timestamp"] as? Timestamp)?.dateValue() else {
                        return nil
                    }
                    
                    return GalleryPhoto(
                        id: document.documentID,
                        imageUrl: imageUrl,
                        eventId: eventId,
                        timestamp: timestamp,
                        likes: data["likes"] as? Int ?? 0,
                        isContestEntry: data["isContestEntry"] as? Bool ?? false
                    )
                }
                
                completion(photos)
            }
    }
    
    func getContestTimeRemaining() -> TimeInterval? {
        // For testing - return 5 minutes if no end time is set
        if let endTime = contestEndTime {
            return max(0, endTime.timeIntervalSince(Date()))
        }
        return 300 // 5 minutes default
    }
}
