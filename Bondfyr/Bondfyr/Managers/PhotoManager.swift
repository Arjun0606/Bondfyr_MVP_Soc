//
//  PhotoManager.swift
//  Bondfyr
//
//  Created by Arjun Varma on 31/03/25.
//

import Foundation
import FirebaseFirestore
import FirebaseStorage
import FirebaseAuth
import Combine

class PhotoManager: ObservableObject {
    static let shared = PhotoManager() // Singleton instance
    
    @Published var photos: [EventPhoto] = []
    @Published var contestActive: Bool = false
    @Published var contestEndTime: Date?
    @Published var contestEventId: String?
    
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    private var contestListener: ListenerRegistration?
    
    init() {
        setupContestListener()
    }
    
    private func setupContestListener() {
        contestListener = db.collection("photo_contests")
            .whereField("active", isEqualTo: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self, let documents = snapshot?.documents else {
                    return
                }
                
                if let contestDoc = documents.first {
                    let data = contestDoc.data()
                    self.contestActive = true
                    self.contestEventId = data["eventId"] as? String
                    
                    if let endTimestamp = data["endTime"] as? Timestamp {
                        self.contestEndTime = endTimestamp.dateValue()
                    } else if let duration = data["durationSeconds"] as? Int {
                        self.contestEndTime = Date().addingTimeInterval(TimeInterval(duration))
                    }
                    
                    // Post local notification if user is checked in at this event
                    self.notifyEligibleUsers()
                } else {
                    self.contestActive = false
                    self.contestEndTime = nil
                    self.contestEventId = nil
                }
            }
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
    
    func isUserEligibleForContest() -> Bool {
        guard let eventId = contestEventId, 
              let endTime = contestEndTime, 
              contestActive, 
              Date() < endTime else {
            return false
        }
        
        if let activeCheckIn = CheckInManager.shared.activeCheckIn, 
           activeCheckIn.eventId == eventId {
            return true
        }
        
        return false
    }
    
    func uploadContestPhoto(imageData: Data, completion: @escaping (Bool) -> Void) {
        guard isUserEligibleForContest(), 
              let eventId = contestEventId,
              let userId = Auth.auth().currentUser?.uid else {
            completion(false)
            return
        }
        
        let photoId = UUID().uuidString
        let storageRef = Storage.storage().reference().child("contest_photos/\(photoId).jpg")

        storageRef.putData(imageData, metadata: nil) { _, error in
            if let error = error {
                print("Error uploading photo: \(error.localizedDescription)")
                completion(false)
                return
            }
            
            storageRef.downloadURL { url, error in
                if let error = error {
                    print("Error getting download URL: \(error.localizedDescription)")
                    completion(false)
                    return
                }
                
                guard let imageUrl = url?.absoluteString else {
                    completion(false)
                    return
                }
                
                let eventPhoto = EventPhoto(
                    eventId: eventId,
                    uploaderId: userId,
                    imageUrl: imageUrl,
                    timestamp: Date(),
                    isContestEntry: true
                )
                
                do {
                    try self.db.collection("event_photos").document(photoId).setData(from: eventPhoto)
                    print("Contest photo uploaded successfully.")
                    
                    // Get event details and notify users
                    self.db.collection("events").document(eventId).getDocument { snapshot, error in
                        guard let data = snapshot?.data(),
                              let eventName = data["name"] as? String else {
                            return
                        }
                        
                        // Notify users who are not checked in about the new contest photos
                        NotificationManager.shared.notifyUsersAboutNewContestPhotos(
                            forEvent: eventId,
                            venueName: eventName
                        )
                    }
                    
                    completion(true)
                } catch {
                    print("Error saving photo to Firestore: \(error.localizedDescription)")
                    completion(false)
                }
            }
        }
    }
    
    func uploadPhoto(imageData: Data, eventId: String, completion: @escaping (Bool) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(false)
            return
        }
        
        let photoId = UUID().uuidString
        let storageRef = Storage.storage().reference().child("event_photos/\(photoId).jpg")

        storageRef.putData(imageData, metadata: nil) { _, error in
            if let error = error {
                print("Error uploading photo: \(error.localizedDescription)")
                completion(false)
                return
            }
            
            storageRef.downloadURL { url, error in
                if let error = error {
                    print("Error getting download URL: \(error.localizedDescription)")
                    completion(false)
                    return
                }
                
                guard let imageUrl = url?.absoluteString else {
                    completion(false)
                    return
                }
                
                let eventPhoto = EventPhoto(
                    eventId: eventId,
                    uploaderId: userId,
                    imageUrl: imageUrl,
                    timestamp: Date()
                )
                
                do {
                    try self.db.collection("event_photos").document(photoId).setData(from: eventPhoto)
                    print("Photo uploaded successfully.")
                    completion(true)
                } catch {
                    print("Error saving photo to Firestore: \(error.localizedDescription)")
                    completion(false)
                }
            }
        }
    }
    
    func fetchPhotos(eventId: String, contestOnly: Bool = false) {
        var query = db.collection("event_photos")
            .whereField("eventId", isEqualTo: eventId)
            .order(by: "timestamp", descending: true)
        
        if contestOnly {
            query = query.whereField("isContestEntry", isEqualTo: true)
        }
        
        query.addSnapshotListener { snapshot, error in
            guard let documents = snapshot?.documents else {
                print("Error fetching photos: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            self.photos = documents.compactMap { doc -> EventPhoto? in
                try? doc.data(as: EventPhoto.self)
            }
        }
    }
    
    func likePhoto(photoId: String?) {
        guard let photoId = photoId else { return }
        
        let photoRef = db.collection("event_photos").document(photoId)
        
        photoRef.updateData(["likes": FieldValue.increment(Int64(1))]) { error in
            if let error = error {
                print("Error liking photo: \(error.localizedDescription)")
            }
        }
        
        // Add user to the liked_photos collection
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        let likeData: [String: Any] = [
            "userId": userId,
            "photoId": photoId,
            "timestamp": FieldValue.serverTimestamp()
        ]
        
        db.collection("liked_photos").document("\(userId)_\(photoId)")
            .setData(likeData) { error in
                if let error = error {
                    print("Error recording like: \(error.localizedDescription)")
                }
            }
    }
    
    // New method to like a photo using the EventPhoto object
    func likePhoto(photo: EventPhoto) {
        guard let photoId = photo.id else { return }
        likePhoto(photoId: photoId)
    }
    
    // New method to unlike a photo
    func unlikePhoto(photo: EventPhoto) {
        guard let photoId = photo.id, let userId = Auth.auth().currentUser?.uid else { return }
        
        let photoRef = db.collection("event_photos").document(photoId)
        
        photoRef.updateData(["likes": FieldValue.increment(Int64(-1))]) { error in
            if let error = error {
                print("Error unliking photo: \(error.localizedDescription)")
            }
        }
        
        // Remove user from the liked_photos collection
        db.collection("liked_photos").document("\(userId)_\(photoId)")
            .delete() { error in
                if let error = error {
                    print("Error removing like: \(error.localizedDescription)")
                }
            }
    }
    
    // Method to check if user has already liked a photo
    func checkIfUserLikedPhoto(photo: EventPhoto, completion: @escaping (Bool) -> Void) {
        guard let photoId = photo.id, let userId = Auth.auth().currentUser?.uid else {
            completion(false)
            return
        }
        
        db.collection("liked_photos").document("\(userId)_\(photoId)")
            .getDocument { snapshot, error in
                if let error = error {
                    print("Error checking if photo is liked: \(error.localizedDescription)")
                    completion(false)
                    return
                }
                
                completion(snapshot?.exists ?? false)
            }
    }
    
    func getContestTimeRemaining() -> TimeInterval? {
        guard let endTime = contestEndTime, contestActive else {
            return nil
        }
        
        let remaining = endTime.timeIntervalSince(Date())
        return remaining > 0 ? remaining : nil
    }
}
