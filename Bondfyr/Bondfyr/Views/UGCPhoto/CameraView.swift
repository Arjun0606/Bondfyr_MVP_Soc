import SwiftUI
import AVFoundation
import BondfyrPhotos

struct CameraView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var photoManager = PhotoManager.shared
    @State private var showingImagePicker = false
    @State private var capturedImage: UIImage?
    @State private var isUploading = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                if let image = capturedImage {
                    // Preview captured image
                    VStack {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .padding()
                        
                        HStack(spacing: 40) {
                            Button(action: { capturedImage = nil }) {
                                VStack {
                                    Image(systemName: "arrow.counterclockwise")
                                        .font(.system(size: 24))
                                    Text("Retake")
                                        .font(.caption)
                                }
                                .foregroundColor(.white)
                            }
                            
                            Button(action: uploadPhoto) {
                                VStack {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.system(size: 24))
                                    Text("Upload")
                                        .font(.caption)
                                }
                                .foregroundColor(.white)
                            }
                            .disabled(isUploading)
                        }
                        .padding(.top, 30)
                        
                        if isUploading {
                            ProgressView("Uploading...")
                                .progressViewStyle(CircularProgressViewStyle())
                                .foregroundColor(.white)
                                .padding(.top, 20)
                        }
                    }
                } else {
                    // Camera UI
                    VStack {
                        Spacer()
                        Button(action: { showingImagePicker = true }) {
                            ZStack {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 70, height: 70)
                                Circle()
                                    .stroke(Color.white.opacity(0.5), lineWidth: 4)
                                    .frame(width: 80, height: 80)
                            }
                        }
                        .padding(.bottom, 30)
                    }
                }
            }
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
                .foregroundColor(.white)
            )
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(image: $capturedImage, sourceType: .camera)
        }
    }
    
    private func uploadPhoto() {
        guard let image = capturedImage else { return }
        isUploading = true
        
        // Create a new DailyPhoto
        let photo = DailyPhoto(
            id: UUID().uuidString,
            photoURL: "", // Will be set after upload
            userID: "", // Set this from your auth system
            userHandle: "", // Set this from your auth system
            city: "", // Set this from location
            country: "", // Set this from location
            timestamp: Date(),
            likes: 0,
            likedBy: []
        )
        
        Task {
            do {
                try await photoManager.uploadDailyPhoto(image: image, photo: photo)
                await MainActor.run {
                    isUploading = false
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