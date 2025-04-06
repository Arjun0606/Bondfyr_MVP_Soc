import SwiftUI
import UIKit
import AVFoundation
import FirebaseAuth
import CoreImage
import CoreImage.CIFilterBuiltins

struct ContestPhotoCaptureView: View {
    let eventId: String
    
    @StateObject private var photoManager = PhotoManager.shared
    @Environment(\.presentationMode) var presentationMode
    @State private var showSuccessAlert = false
    @State private var showErrorAlert = false
    @State private var errorMessage = "An error occurred"
    @State private var isPhotoTaken = false
    @State private var timeRemaining = 0
    @State private var timer: Timer?
    
    var body: some View {
        ZStack {
            // Black background
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Header
                HStack {
                    Button(action: {
                        dismissView()
                    }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.gray.opacity(0.3))
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                    
                    Text("Take Contest Photo")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    // Space for symmetry
                    Image(systemName: "xmark")
                        .foregroundColor(.clear)
                        .padding(8)
                }
                .padding()
                
                Spacer()
                
                // Instructions
                VStack(spacing: 12) {
                    Text("Contest Rules")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text("• You can only submit one photo\n• No retakes are allowed\n• Photos will have a retro filter applied\n• The photo with the most likes wins\n• Only guests at the venue can submit")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                .padding()
                .background(Color.black.opacity(0.6))
                .cornerRadius(12)
                .padding(.horizontal)
                
                Spacer()
                
                // Camera button
                if !isPhotoTaken {
                    Button(action: {
                        openCamera()
                    }) {
                        ZStack {
                            Circle()
                                .stroke(Color.white, lineWidth: 3)
                                .frame(width: 80, height: 80)
                            
                            Circle()
                                .fill(Color.white)
                                .frame(width: 70, height: 70)
                        }
                    }
                    .padding(.bottom, 40)
                }
                
                if timeRemaining > 0 {
                    Text("Contest ends in: \(timeString(from: TimeInterval(timeRemaining)))")
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.pink.opacity(0.3))
                        .cornerRadius(8)
                }
            }
        }
        .onAppear {
            checkEligibility()
            startTimer()
        }
        .onDisappear {
            timer?.invalidate()
        }
        .alert("Success", isPresented: $showSuccessAlert) {
            Button("View Photos", role: .cancel) {
                dismissToGallery()
            }
        } message: {
            Text("Your retro photo has been submitted to the contest!")
        }
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) {
                if errorMessage.contains("not eligible") {
                    dismissView() 
                }
            }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func startTimer() {
        // Get remaining time from PhotoManager if a contest is active
        if let remaining = photoManager.getContestTimeRemaining() {
            timeRemaining = Int(remaining)
        }
        
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if timeRemaining > 0 {
                timeRemaining -= 1
            } else {
                timer?.invalidate()
                dismissView()
            }
        }
    }
    
    private func checkEligibility() {
        if !photoManager.isUserEligibleForContest() {
            errorMessage = "You are not eligible for this contest. You must be checked in at the event."
            showErrorAlert = true
            
            // Dismiss after showing the error
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                dismissView()
            }
        }
    }
    
    private func openCamera() {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.allowsEditing = false
        picker.delegate = ImagePickerDelegate(onCapture: handleCapturedImage)
        
        UIApplication.shared.windows.first?.rootViewController?.present(picker, animated: true)
    }
    
    private func handleCapturedImage(image: UIImage?) {
        isPhotoTaken = true
        
        guard let originalImage = image else {
            errorMessage = "Failed to capture image"
            showErrorAlert = true
            return
        }
        
        // Apply retro filter to the image
        let filteredImage = applyRetroFilter(to: originalImage)
        
        guard let imageData = filteredImage.jpegData(compressionQuality: 0.7) else {
            errorMessage = "Failed to process the image"
            showErrorAlert = true
            return
        }
        
        // Upload photo to contest
        photoManager.uploadContestPhoto(imageData: imageData) { success in
            if success {
                showSuccessAlert = true
            } else {
                errorMessage = "Failed to upload the photo"
                showErrorAlert = true
            }
        }
    }
    
    private func applyRetroFilter(to image: UIImage) -> UIImage {
        // Create a context to work with Core Image
        let context = CIContext()
        guard let ciImage = CIImage(image: image) else { return image }
        
        // Apply multiple filters to get a disposable camera/retro effect
        
        // Step 1: Adjust color controls to get a vintage look
        let colorFilter = CIFilter.colorControls()
        colorFilter.inputImage = ciImage
        colorFilter.saturation = 1.3  // Slightly oversaturate
        colorFilter.contrast = 1.1    // Increase contrast
        
        guard let colorAdjusted = colorFilter.outputImage else { return image }
        
        // Step 2: Add film grain
        let noiseFilter = CIFilter.randomGenerator()
        guard let noise = noiseFilter.outputImage else { return image }
        
        let monochromeNoiseFilter = CIFilter.colorMatrix()
        monochromeNoiseFilter.inputImage = noise
        // Make the noise monochromatic
        monochromeNoiseFilter.rVector = CIVector(x: 0.5, y: 0.5, z: 0.5, w: 0)
        monochromeNoiseFilter.gVector = CIVector(x: 0.5, y: 0.5, z: 0.5, w: 0)
        monochromeNoiseFilter.bVector = CIVector(x: 0.5, y: 0.5, z: 0.5, w: 0)
        monochromeNoiseFilter.aVector = CIVector(x: 0, y: 0, z: 0, w: 0.05) // Control noise intensity
        
        guard let monochromeNoise = monochromeNoiseFilter.outputImage?.cropped(to: ciImage.extent) else { return image }
        
        // Step 3: Overlay the noise on the image
        let overlayFilter = CIFilter.sourceOverCompositing()
        overlayFilter.inputImage = monochromeNoise
        overlayFilter.backgroundImage = colorAdjusted
        
        guard let grainyImage = overlayFilter.outputImage else { return image }
        
        // Step 4: Apply a slight vignette effect
        let vignetteFilter = CIFilter.vignette()
        vignetteFilter.inputImage = grainyImage
        vignetteFilter.intensity = 0.3
        vignetteFilter.radius = 1.5
        
        guard let vignettedImage = vignetteFilter.outputImage else { return image }
        
        // Step 5: Apply slight photo filter to give it a warm tone
        let photoFilter = CIFilter.photoEffectInstant()
        photoFilter.inputImage = vignettedImage
        
        guard let outputImage = photoFilter.outputImage else { return image }
        
        // Convert back to UIImage
        if let cgImage = context.createCGImage(outputImage, from: outputImage.extent) {
            return UIImage(cgImage: cgImage)
        }
        
        return image // Fallback to original if filter fails
    }
    
    private func dismissView() {
        presentationMode.wrappedValue.dismiss()
    }
    
    private func dismissToGallery() {
        NotificationCenter.default.post(name: Notification.Name("ContestPhotoUploaded"), object: nil)
        dismissView()
    }
    
    private func timeString(from seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

class ImagePickerDelegate: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    private let onCapture: (UIImage?) -> Void
    
    init(onCapture: @escaping (UIImage?) -> Void) {
        self.onCapture = onCapture
        super.init()
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        let image = info[.originalImage] as? UIImage
        onCapture(image)
        picker.dismiss(animated: true)
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        onCapture(nil)
        picker.dismiss(animated: true)
    }
} 