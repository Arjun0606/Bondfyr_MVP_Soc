import Foundation
import Firebase
import FirebaseFirestore
import FirebaseStorage
import UIKit
import FirebaseAuth

struct PhotoContest: Identifiable {
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
        }
    }
}

class PhotoContestManager {
    static let shared = PhotoContestManager()
    private let db = Firestore.firestore()
    private let storage = Storage.storage().reference()
    
    // 12 hours in seconds for photo expiration
    private let photoLifetimeInSeconds: TimeInterval = 12 * 60 * 60
    
    private init() {}
    
    // MARK: - Check Eligibility
    
    func checkUploadEligibility(for eventId: String, completion: @escaping (Result<Void, PhotoContestError>) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(.failure(.notLoggedIn))
            return
        }
        
        // For demo purposes, we'll assume everyone is eligible
        // In a real app, you would check if the user has a ticket or has checked in
        completion(.success(()))
        
        // If you want to check for tickets:
        /*
        db.collection("tickets")
            .whereField("userId", isEqualTo: userId)
            .whereField("eventId", isEqualTo: eventId)
            .whereField("isScanned", isEqualTo: true)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error checking eligibility: \(error)")
                    completion(.failure(.serverError))
                    return
                }
                
                if let documents = snapshot?.documents, !documents.isEmpty {
                    completion(.success(()))
                } else {
                    completion(.failure(.notEligible))
                }
            }
        */
    }
    
    // MARK: - Upload Photo
    
    func uploadPhoto(for eventId: String, image: UIImage, caption: String, completion: @escaping (Result<String, PhotoContestError>) -> Void) {
        // First check if user is eligible to upload
        checkUploadEligibility(for: eventId) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success:
                self.performPhotoUpload(eventId: eventId, image: image, caption: caption, completion: completion)
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    private func performPhotoUpload(eventId: String, image: UIImage, caption: String, completion: @escaping (Result<String, PhotoContestError>) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid,
              let imageData = image.jpegData(compressionQuality: 0.7) else {
            completion(.failure(.invalidImage))
            return
        }
        
        // Get user name
        db.collection("users").document(userId).getDocument { [weak self] snapshot, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Error fetching user data: \(error)")
                completion(.failure(.databaseError))
                return
            }
            
            let userName = snapshot?.data()?["name"] as? String ?? "Anonymous"
            
            // Generate unique photo ID
            let photoId = UUID().uuidString
            let photoRef = self.storage.child("photo_contests/\(eventId)/\(photoId).jpg")
            
            // Upload photo to Firebase Storage
            photoRef.putData(imageData, metadata: nil) { _, error in
                if let error = error {
                    print("Error uploading photo: \(error)")
                    completion(.failure(.uploadFailed))
                    return
                }
                
                // Get download URL
                photoRef.downloadURL { url, error in
                    if let error = error {
                        print("Error getting download URL: \(error)")
                        completion(.failure(.uploadFailed))
                        return
                    }
                    
                    guard let downloadURL = url else {
                        completion(.failure(.uploadFailed))
                        return
                    }
                    
                    // Current time
                    let now = Date()
                    
                    // Calculate expiration time (12 hours from now)
                    let expirationTime = now.addingTimeInterval(self.photoLifetimeInSeconds)
                    
                    // Create photo entry in Firestore
                    let photoData: [String: Any] = [
                        "eventId": eventId,
                        "userId": userId,
                        "userName": userName,
                        "photoURL": downloadURL.absoluteString,
                        "caption": caption,
                        "timestamp": Timestamp(date: now),
                        "expirationTime": Timestamp(date: expirationTime),
                        "likeCount": 0,
                        "scheduledForDeletion": false
                    ]
                    
                    // Save to Firestore
                    self.db.collection("photo_contests").document(photoId).setData(photoData) { error in
                        if let error = error {
                            print("Error saving photo data: \(error)")
                            completion(.failure(.databaseError))
                            return
                        }
                        
                        // Schedule deletion of the photo after 12 hours
                        self.schedulePhotoDeletion(photoId: photoId, storageRef: photoRef, expirationTime: expirationTime)
                        
                        completion(.success(photoId))
                    }
                }
            }
        }
    }
    
    // MARK: - Fetch Photos
    
    func fetchPhotos(for eventId: String, completion: @escaping (Result<[PhotoContest], PhotoContestError>) -> Void) {
        let currentUserId = Auth.auth().currentUser?.uid
        
        // Fetch photos that haven't expired yet
        db.collection("photo_contests")
            .whereField("eventId", isEqualTo: eventId)
            .whereField("expirationTime", isGreaterThan: Timestamp(date: Date()))
            .whereField("scheduledForDeletion", isEqualTo: false)
            .order(by: "expirationTime")
            .order(by: "timestamp", descending: true)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("Error fetching photos: \(error)")
                    completion(.failure(.databaseError))
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    completion(.success([]))
                    return
                }
                
                // Process photos
                var photoContests: [PhotoContest] = []
                let dispatchGroup = DispatchGroup()
                
                for document in documents {
                    dispatchGroup.enter()
                    
                    let data = document.data()
                    let photoId = document.documentID
                    let eventId = data["eventId"] as? String ?? ""
                    let userId = data["userId"] as? String ?? ""
                    let userName = data["userName"] as? String ?? "Anonymous"
                    let photoURL = data["photoURL"] as? String ?? ""
                    let caption = data["caption"] as? String ?? ""
                    let timestamp = (data["timestamp"] as? Timestamp)?.dateValue() ?? Date()
                    let expirationTime = (data["expirationTime"] as? Timestamp)?.dateValue() ?? Date()
                    let likeCount = data["likeCount"] as? Int ?? 0
                    
                    // Check if current user has liked this photo
                    if let currentUserId = currentUserId {
                        self.checkIfUserLiked(photoId: photoId, userId: currentUserId) { userLiked in
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
                            
                            photoContests.append(photo)
                            dispatchGroup.leave()
                        }
                    } else {
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
                            userLiked: false
                        )
                        
                        photoContests.append(photo)
                        dispatchGroup.leave()
                    }
                }
                
                dispatchGroup.notify(queue: .main) {
                    // Sort by like count (most liked first), then by timestamp (newest first)
                    let sortedPhotos = photoContests.sorted { photo1, photo2 in
                        if photo1.likeCount != photo2.likeCount {
                            return photo1.likeCount > photo2.likeCount
                        }
                        return photo1.timestamp > photo2.timestamp
                    }
                    
                    completion(.success(sortedPhotos))
                }
            }
    }
    
    // MARK: - Like / Unlike Photo
    
    func toggleLike(for photoId: String, completion: @escaping (Result<Bool, PhotoContestError>) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(.failure(.notLoggedIn))
            return
        }
        
        let likeId = "\(userId)_\(photoId)"
        let likeRef = db.collection("likes").document(likeId)
        
        likeRef.getDocument { snapshot, error in
            if let error = error {
                print("Error checking like status: \(error)")
                completion(.failure(.serverError))
                return
            }
            
            if let snapshot = snapshot, snapshot.exists {
                // User already liked the photo, remove the like
                likeRef.delete { error in
                    if let error = error {
                        print("Error removing like: \(error)")
                        completion(.failure(.serverError))
                        return
                    }
                    
                    // Decrement like count
                    self.db.collection("photo_contests").document(photoId).updateData([
                        "likeCount": FieldValue.increment(Int64(-1))
                    ]) { error in
                        if let error = error {
                            print("Error updating like count: \(error)")
                            completion(.failure(.serverError))
                            return
                        }
                        
                        completion(.success(false))  // false means not liked anymore
                    }
                }
            } else {
                // User hasn't liked the photo yet, add a like
                let likeData: [String: Any] = [
                    "userId": userId,
                    "photoId": photoId,
                    "timestamp": FieldValue.serverTimestamp()
                ]
                
                likeRef.setData(likeData) { error in
                    if let error = error {
                        print("Error adding like: \(error)")
                        completion(.failure(.serverError))
                        return
                    }
                    
                    // Increment like count
                    self.db.collection("photo_contests").document(photoId).updateData([
                        "likeCount": FieldValue.increment(Int64(1))
                    ]) { error in
                        if let error = error {
                            print("Error updating like count: \(error)")
                            completion(.failure(.serverError))
                            return
                        }
                        
                        completion(.success(true))  // true means liked
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func checkIfUserLiked(photoId: String, userId: String, completion: @escaping (Bool) -> Void) {
        let likeId = "\(userId)_\(photoId)"
        db.collection("likes").document(likeId).getDocument { snapshot, error in
            completion(snapshot?.exists == true)
        }
    }
    
    private func schedulePhotoDeletion(photoId: String, storageRef: StorageReference, expirationTime: Date) {
        // Mark photo as scheduled for deletion in Firestore
        db.collection("photo_contests").document(photoId).updateData([
            "scheduledForDeletion": true
        ]) { error in
            if let error = error {
                print("Error marking photo for deletion: \(error)")
            }
        }
        
        // In a real implementation, you would use Cloud Functions to handle automatic deletion
        // This would be the pseudocode for the Cloud Function:
        /*
         exports.deleteExpiredPhotos = functions.pubsub.schedule('every 1 hours').onRun(async context => {
             const now = admin.firestore.Timestamp.now();
             const snapshot = await admin.firestore().collection('photo_contests')
                 .where('expirationTime', '<', now)
                 .where('scheduledForDeletion', '==', true)
                 .get();
             
             const batch = admin.firestore().batch();
             const promises = [];
             
             snapshot.forEach(doc => {
                 const data = doc.data();
                 const photoURL = data.photoURL;
                 
                 // Delete from Storage
                 if (photoURL) {
                     const decodedURL = decodeURIComponent(photoURL);
                     const storageRef = admin.storage().refFromURL(decodedURL);
                     promises.push(storageRef.delete());
                 }
                 
                 // Delete from Firestore
                 batch.delete(doc.ref);
                 
                 // Delete associated likes
                 promises.push(admin.firestore().collection('photo_likes')
                     .where('photoId', '==', doc.id)
                     .get()
                     .then(likesSnapshot => {
                         const likesBatch = admin.firestore().batch();
                         likesSnapshot.forEach(likeDoc => {
                             likesBatch.delete(likeDoc.ref);
                         });
                         return likesBatch.commit();
                     }));
             });
             
             // Commit Firestore batch
             promises.push(batch.commit());
             
             return Promise.all(promises);
         });
         */
    }
    
    // Additional method to check if user has access to view the event's photos
    func canViewPhotos(for eventId: String, completion: @escaping (Bool) -> Void) {
        // Anyone can view photos, so always return true
        completion(true)
    }
}
