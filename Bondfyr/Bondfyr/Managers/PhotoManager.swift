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
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    
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
    
    func fetchPhotos(eventId: String) {
        db.collection("event_photos")
            .whereField("eventId", isEqualTo: eventId)
            .order(by: "timestamp", descending: true)
            .addSnapshotListener { snapshot, error in
                guard let documents = snapshot?.documents else {
                    print("Error fetching photos: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                
                self.photos = documents.compactMap { doc -> EventPhoto? in
                    try? doc.data(as: EventPhoto.self)
                }
            }
    }
    
    func likePhoto(photoId: String) {
        let photoRef = db.collection("event_photos").document(photoId)
        
        photoRef.updateData(["likes": FieldValue.increment(Int64(1))]) { error in
            if let error = error {
                print("Error liking photo: \(error.localizedDescription)")
            }
        }
    }
}
