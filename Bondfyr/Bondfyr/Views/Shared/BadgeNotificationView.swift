import SwiftUI
import BondfyrPhotos

struct BadgeNotificationView: View {
    let badge: PhotoBadge
    @Binding var isPresented: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            // Badge Icon
            AsyncImage(url: URL(string: badge.imageURL)) { phase in
                switch phase {
                case .empty:
                    Image(systemName: "star.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(Color(hex: badge.level.color))
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 100, height: 100)
                case .failure:
                    Image(systemName: "star.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(Color(hex: badge.level.color))
                @unknown default:
                    EmptyView()
                }
            }
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
    let badge: PhotoBadge
    @Binding var isPresented: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Badge Icon
            AsyncImage(url: URL(string: badge.imageURL)) { phase in
                switch phase {
                case .empty:
                    Image(systemName: "star.circle.fill")
                        .font(.system(size: 30))
                        .foregroundColor(Color(hex: badge.level.color))
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 40, height: 40)
                case .failure:
                    Image(systemName: "star.circle.fill")
                        .font(.system(size: 30))
                        .foregroundColor(Color(hex: badge.level.color))
                @unknown default:
                    EmptyView()
                }
            }
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