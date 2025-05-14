import Foundation
import SwiftUI

enum BadgeEmoji {
    static func getEmoji(for type: BadgeType, level: BadgeLevel) -> String {
        let baseEmoji = baseEmoji(for: type)
        let levelIndicator = levelIndicator(for: level)
        return "\(baseEmoji)\(levelIndicator)"
    }
    
    private static func baseEmoji(for type: BadgeType) -> String {
        switch type {
        case .mostLiked:
            return "❤️" // Heart for most liked photos
        case .topThree:
            return "🏆" // Trophy for top 3 appearances
        case .afterpartyHost:
            return "🎉" // Party popper for hosting parties
        case .afterpartyGuest:
            return "🦋" // Butterfly for social butterfly
        case .dailyStreak:
            return "🔥" // Fire for daily streak
        }
    }
    
    private static func levelIndicator(for level: BadgeLevel) -> String {
        switch level {
        case .bronze:
            return "🥉"
        case .silver:
            return "🥈"
        case .gold:
            return "🥇"
        }
    }
    
    static func generateBadgeImage(type: BadgeType, level: BadgeLevel) -> UIImage {
        let emoji = getEmoji(for: type, level: level)
        let fontSize: CGFloat = 60
        let size = CGSize(width: fontSize * 1.2, height: fontSize * 1.2)
        
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            // Draw background circle
            let backgroundColor: UIColor
            switch level {
            case .bronze:
                backgroundColor = UIColor(red: 0.8, green: 0.5, blue: 0.2, alpha: 0.2)
            case .silver:
                backgroundColor = UIColor(red: 0.8, green: 0.8, blue: 0.8, alpha: 0.2)
            case .gold:
                backgroundColor = UIColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 0.2)
            }
            
            backgroundColor.setFill()
            context.cgContext.fillEllipse(in: CGRect(origin: .zero, size: size))
            
            // Draw emoji
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: fontSize)
            ]
            
            let attributedString = NSAttributedString(string: emoji, attributes: attributes)
            let stringSize = attributedString.size()
            let origin = CGPoint(
                x: (size.width - stringSize.width) / 2,
                y: (size.height - stringSize.height) / 2
            )
            
            attributedString.draw(at: origin)
        }
        
        return image
    }
} 