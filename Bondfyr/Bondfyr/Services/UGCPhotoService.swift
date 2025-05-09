import Foundation
import FirebaseFirestore
import FirebaseStorage
import UIKit

public enum PhotoScope {
    case city
    case country
    case world
}

public class UGCPhotoService: ObservableObject {
    private let db = Firestore.firestore()
    private let storage = Storage.storage().reference()
    
    @Published public var cityPhotos: [UGCPhoto] = []
    @Published public var countryPhotos: [UGCPhoto] = []
    @Published public var worldPhotos: [UGCPhoto] = []
    @Published public var hasUploadedToday: Bool = false
    
    public init() {
        checkTodayUpload()
    }
    
    private func checkTodayUpload() {
        guard let userId = UserDefaults.standard.string(forKey: "userId") else { return }
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        db.collection("ugc_photos")
            .whereField("userId", isEqualTo: userId)
            .whereField("timestamp", isGreaterThan: startOfDay)
            .whereField("timestamp", isLessThan: endOfDay)
            .getDocuments { [weak self] snapshot, error in
                if let documents = snapshot?.documents, !documents.isEmpty {
                    DispatchQueue.main.async {
                        self?.hasUploadedToday = true
                    }
                }
            }
    }
    
    public func uploadPhoto(_ image: UIImage, city: String, country: String) async throws -> UGCPhoto {
        guard let userId = UserDefaults.standard.string(forKey: "userId"),
              let userHandle = UserDefaults.standard.string(forKey: "userHandle"),
              let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw NSError(domain: "UGCPhotoService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid input data"])
        }
        
        // Check if user has already uploaded today
        if hasUploadedToday {
            throw NSError(domain: "UGCPhotoService", code: 403, userInfo: [NSLocalizedDescriptionKey: "You can only upload one photo per day"])
        }
        
        let timestamp = Date()
        let fileName = "\(timestamp.timeIntervalSince1970).jpg"
        let photoRef = storage.child("ugc_photos/\(userId)/\(fileName)")
        
        // Upload image to Firebase Storage
        _ = try await photoRef.putDataAsync(imageData)
        let photoURL = try await photoRef.downloadURL().absoluteString
        
        // Create Firestore document
        let photo = UGCPhoto(
            id: UUID().uuidString,
            userId: userId,
            userHandle: userHandle,
            photoURL: photoURL,
            city: city,
            country: country,
            timestamp: timestamp,
            likes: 0,
            likedBy: []
        )
        
        try await db.collection("ugc_photos").document(photo.id).setData(from: photo)
        
        DispatchQueue.main.async {
            self.hasUploadedToday = true
        }
        
        return photo
    }
    
    public func fetchPhotos(scope: PhotoScope) async throws {
        guard let userCity = UserDefaults.standard.string(forKey: "selectedCity") else { return }
        let userCountry = "India" // Hardcoded for now, update later
        
        var query = db.collection("ugc_photos")
            .order(by: "likes", descending: true)
            .order(by: "timestamp", descending: true)
        
        switch scope {
        case .city:
            query = query.whereField("city", isEqualTo: userCity)
        case .country:
            query = query.whereField("country", isEqualTo: userCountry)
        case .world:
            break
        }
        
        let snapshot = try await query.getDocuments()
        let photos = snapshot.documents.compactMap { try? $0.data(as: UGCPhoto.self) }
            .filter { !$0.isExpired }
        
        await MainActor.run {
            switch scope {
            case .city:
                self.cityPhotos = photos
            case .country:
                self.countryPhotos = photos
            case .world:
                self.worldPhotos = photos
            }
        }
    }
    
    public func likePhoto(_ photo: UGCPhoto) async throws {
        guard let userId = UserDefaults.standard.string(forKey: "userId") else { return }
        
        if photo.likedBy.contains(userId) {
            return // User has already liked this photo
        }
        
        let ref = db.collection("ugc_photos").document(photo.id)
        try await ref.updateData([
            "likes": FieldValue.increment(Int64(1)),
            "likedBy": FieldValue.arrayUnion([userId])
        ])
        
        // Refresh photos to update UI
        try await fetchPhotos(scope: .city)
        try await fetchPhotos(scope: .country)
        try await fetchPhotos(scope: .world)
    }
} 