import Foundation
import FirebaseFirestore
import FirebaseAuth
import SwiftUI

// MARK: - Daily Photo Model
struct DailyPhoto: Identifiable, Codable {
    let id: String
    let photoURL: String
    let userID: String
    let userHandle: String
    let city: String
    let country: String
    let timestamp: Date
    var likes: Int
    var likedBy: [String]
    
    var isLikedByCurrentUser: Bool {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return false }
        return likedBy.contains(currentUserID)
    }
    
    var formattedTimestamp: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
    
    var timeRemaining: TimeInterval {
        let expiryDate = Calendar.current.date(byAdding: .hour, value: 24, to: timestamp) ?? Date()
        return max(0, expiryDate.timeIntervalSince(Date()))
    }
    
    var formattedTimeRemaining: String {
        let hours = Int(timeRemaining) / 3600
        let minutes = Int(timeRemaining) / 60 % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    var isExpired: Bool {
        timeRemaining <= 0
    }
}

// MARK: - Photo Badge
struct PhotoBadge: Identifiable {
    let id = UUID()
    let emoji: String
    let title: String
    let description: String
    
    static func getBadges(for photo: DailyPhoto, in photos: [DailyPhoto], cityName: String) -> [PhotoBadge] {
        var badges: [PhotoBadge] = []
        
        // #1 in City
        if photos.first?.id == photo.id {
            badges.append(PhotoBadge(
                emoji: "🏆",
                title: "#1 in \(cityName)",
                description: "Top photo in \(cityName)"
            ))
        }
        
        // Trending (10+ likes)
        if photo.likes >= 10 {
            badges.append(PhotoBadge(
                emoji: "🔥",
                title: "Trending",
                description: "10+ people liked this photo"
            ))
        }
        
        // Early Bird (posted before 8 AM)
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: photo.timestamp)
        if hour < 8 {
            badges.append(PhotoBadge(
                emoji: "🌅",
                title: "Early Bird",
                description: "Posted before 8 AM"
            ))
        }
        
        // Most Liked (top 3)
        let sortedByLikes = photos.sorted { $0.likes > $1.likes }
        if let index = sortedByLikes.firstIndex(where: { $0.id == photo.id }), index < 3 {
            badges.append(PhotoBadge(
                emoji: "❤️",
                title: "Most Liked",
                description: "One of the top 3 most liked photos"
            ))
        }
        
        // Going Viral (likes > 150% of average)
        let averageLikes = Double(photos.reduce(0) { $0 + $1.likes }) / Double(max(1, photos.count))
        if Double(photo.likes) > averageLikes * 1.5 {
            badges.append(PhotoBadge(
                emoji: "🚀",
                title: "Going Viral",
                description: "More likes than 150% of the average"
            ))
        }
        
        // Perfect Timing (posted during peak hours 8-11 PM)
        if (20...23).contains(hour) {
            badges.append(PhotoBadge(
                emoji: "⚡️",
                title: "Perfect Timing",
                description: "Posted during peak hours"
            ))
        }
        
        return badges
    }
}

// MARK: - Photo Error
enum PhotoError: LocalizedError {
    case invalidImageData
    case userNotAuthenticated
    case uploadFailed(Error)
    case downloadFailed(Error)
    case databaseError(Error)
    case alreadyPostedToday
    case invalidScope
    case downloadURLMissing
    
    var errorDescription: String? {
        switch self {
        case .invalidImageData:
            return "Could not process the image data"
        case .userNotAuthenticated:
            return "You must be logged in to perform this action"
        case .uploadFailed(let error):
            return "Failed to upload photo: \(error.localizedDescription)"
        case .downloadFailed(let error):
            return "Failed to download photo: \(error.localizedDescription)"
        case .databaseError(let error):
            return "Database error: \(error.localizedDescription)"
        case .alreadyPostedToday:
            return "You have already posted a photo today"
        case .invalidScope:
            return "Invalid photo scope"
        case .downloadURLMissing:
            return "Failed to get download URL for the uploaded photo"
        }
    }
} 