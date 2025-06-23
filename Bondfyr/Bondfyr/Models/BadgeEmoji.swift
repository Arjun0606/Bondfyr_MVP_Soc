import Foundation
import SwiftUI
import UIKit

enum BadgeEmoji {
    static func getEmoji(for type: BadgeType, level: BadgeLevel) -> String {
        // Since we're using emojis directly from badge types, just return the type emoji
        return type.emoji
    }
    
    static func generateBadgeImage(type: BadgeType, level: BadgeLevel) -> UIImage {
        let emoji = type.emoji
        let fontSize: CGFloat = 60
        let size = CGSize(width: fontSize * 1.2, height: fontSize * 1.2)
        
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            // Draw background circle
            let backgroundColor: UIColor
            switch level {
            case .earned:
                backgroundColor = UIColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 0.2) // Gold
            case .inProgress:
                backgroundColor = UIColor(red: 1.0, green: 0.4, blue: 0.2, alpha: 0.2) // Orange
            case .locked:
                backgroundColor = UIColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 0.2) // Gray
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