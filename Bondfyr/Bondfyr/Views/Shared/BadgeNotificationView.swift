import SwiftUI

struct LegacyBadgeNotificationView: View {
    let badge: UserBadge
    @Binding var isPresented: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            // Badge Icon
            Text(badge.type.emoji)
                .font(.system(size: 80))
                .frame(width: 100, height: 100)
                .background(
                    Circle()
                        .fill(Color(hex: badge.level.color).opacity(0.2))
                )
                .overlay(
                    Circle()
                        .stroke(Color(hex: badge.level.color), lineWidth: 3)
                )
            
            // Badge Info
            Text("New Badge Earned!")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text(badge.name)
                .font(.headline)
                .foregroundColor(Color(hex: badge.level.color))
            
            Text(badge.level.rawValue)
                .font(.subheadline)
                .foregroundColor(.gray)
            
            Text(badge.description)
                .font(.body)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            // Dismiss Button
            Button(action: {
                withAnimation {
                    isPresented = false
                }
            }) {
                Text("Awesome!")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(width: 200)
                    .padding(.vertical, 12)
                    .background(Color.pink)
                    .cornerRadius(25)
            }
            .padding(.top)
        }
        .padding(30)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.black)
                .shadow(color: Color(hex: badge.level.color).opacity(0.3), radius: 20)
        )
        .transition(.scale.combined(with: .opacity))
    }
}

struct BadgeToastView: View {
    let badge: UserBadge
    @Binding var isPresented: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Badge Icon
            Text(badge.type.emoji)
                .font(.system(size: 30))
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(Color(hex: badge.level.color).opacity(0.2))
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text("New Badge!")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Text("\(badge.name) - \(badge.level.rawValue)")
                    .font(.subheadline)
                    .foregroundColor(.white)
            }
            
            Spacer()
            
            Button(action: {
                withAnimation {
                    isPresented = false
                }
            }) {
                Image(systemName: "xmark")
                    .foregroundColor(.gray)
                    .padding(8)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.black)
                .shadow(color: Color(hex: badge.level.color).opacity(0.3), radius: 10)
        )
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

 