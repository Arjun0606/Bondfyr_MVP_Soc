import SwiftUI
import BondfyrPhotos

struct PhotoPreviewView: View {
    let image: UIImage
    let city: String
    let onUploadComplete: () -> Void
    
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var photoManager = PhotoManager.shared
    @State private var isUploading = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                VStack {
                    // Image preview
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: geometry.size.width)
                    
                    Spacer()
                    
                    // Upload button
                    Button(action: uploadPhoto) {
                        HStack {
                            if isUploading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .padding(.trailing, 8)
                            }
                            Text(isUploading ? "Uploading..." : "Share Photo")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isUploading ? Color.gray : Color.pink)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                    .disabled(isUploading)
                    .padding(.bottom, geometry.safeAreaInsets.bottom + 20)
                }
            }
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func uploadPhoto() {
        isUploading = true
        
        // Create a new CityPhoto
        let photo = CityPhoto(
            id: UUID().uuidString,
            imageUrl: "", // Will be set after upload
            city: city,
            timestamp: Date(),
            likes: 0,
            expiresAt: Calendar.current.date(byAdding: .hour, value: 24, to: Date()) ?? Date()
        )
        
        Task {
            do {
                try await photoManager.uploadCityPhoto(image: image, photo: photo)
                await MainActor.run {
                    isUploading = false
                    onUploadComplete()
                    presentationMode.wrappedValue.dismiss()
                }
            } catch {
                await MainActor.run {
                    isUploading = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
} 