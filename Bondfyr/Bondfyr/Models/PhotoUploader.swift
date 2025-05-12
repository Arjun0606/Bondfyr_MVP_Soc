import UIKit
 
protocol PhotoUploader {
    func uploadPhoto(_ photo: UIImage) async throws -> String
    func uploadPhoto(_ photo: UIImage, eventId: String?) async throws -> String
} 