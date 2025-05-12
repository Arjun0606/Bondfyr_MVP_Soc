import UIKit
import FirebaseStorage
import FirebaseFirestore

struct UGCPhotoUploader: PhotoUploader {
    let eventId: String?
    
    func uploadPhoto(_ photo: UIImage) async throws -> String {
        try await uploadPhoto(photo, eventId: eventId)
    }
    
    func uploadPhoto(_ photo: UIImage, eventId: String?) async throws -> String {
        guard let imageData = photo.jpegData(compressionQuality: 0.7) else {
            throw PhotoError.invalidImageData
        }
        
        let photoID = UUID().uuidString
        let path = eventId != nil ? "event_photos/\(eventId!)/\(photoID).jpg" : "ugc_photos/\(photoID).jpg"
        let storageRef = Storage.storage().reference().child(path)
        
        // Create metadata
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        // Upload the image
        _ = try await storageRef.putDataAsync(imageData, metadata: metadata)
        
        // Get download URL
        let downloadURL = try await storageRef.downloadURL()
        
        // Save to Firestore
        let db = Firestore.firestore()
        let photoData: [String: Any] = [
            "imageUrl": downloadURL.absoluteString,
            "timestamp": FieldValue.serverTimestamp(),
            "eventId": eventId as Any,
            "likes": 0
        ]
        
        let docRef = try await db.collection("photos").addDocument(data: photoData)
        return docRef.documentID
    }
} 