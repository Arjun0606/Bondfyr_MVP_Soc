import SwiftUI
import Kingfisher
import BondfyrPhotos

struct EventPhotoDetailView: View {
    let photo: EventPhoto
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack {
                KFImage(URL(string: photo.photoURL))
                    .placeholder {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                    }
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                
                HStack {
                    Text("Posted \(photo.timestamp.timeAgoDisplay())")
                        .foregroundColor(.gray)
                        .font(.caption)
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.pink)
                        Text("\(photo.likes)")
                            .foregroundColor(.white)
                    }
                }
                .padding()
            }
            
            Button(action: {
                presentationMode.wrappedValue.dismiss()
            }) {
                Image(systemName: "xmark")
                    .foregroundColor(.white)
                    .padding(8)
                    .background(Color.black.opacity(0.6))
                    .clipShape(Circle())
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        }
    }
}

extension Date {
    func timeAgoDisplay() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: self, relativeTo: Date())
    }
} 