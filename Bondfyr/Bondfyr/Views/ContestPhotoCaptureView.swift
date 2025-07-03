import SwiftUI
import UIKit
import AVFoundation
import FirebaseAuth
import CoreImage
import CoreImage.CIFilterBuiltins
import FirebaseStorage
import FirebaseFirestore

struct ContestPhotoCaptureView: View {
    let eventId: String
    
    @StateObject private var photoManager = PhotoManager.shared
    @Environment(\.presentationMode) var presentationMode
    @State private var showSuccessAlert = false
    @State private var showErrorAlert = false
    @State private var errorMessage = "An error occurred"
    @State private var isPhotoTaken = false
    @State private var capturedImage: UIImage? = nil
    @State private var isUploading = false
    @State private var showScreenshotWarning = false
    @State private var isShowingCamera = true
    @State private var uploadComplete = false
    @State private var timer: Timer?
    
    private var isEligible: Bool {
        photoManager.isEligibleForContest
    }
    
    private var timeRemaining: TimeInterval {
        photoManager.contestTimeRemaining
    }
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            if !isEligible {
                VStack {
                    Text("You've already submitted a photo for today's contest")
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding()
                    
                    Button("Close") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.pink)
                    .cornerRadius(10)
                }
            } else {
            VStack {
                // Header with back button
                if !isShowingCamera && !isUploading && capturedImage == nil {
                    HStack {
                        Button(action: navigateToEventDetail) {
                            HStack {
                                Image(systemName: "chevron.left")
                                Text("Back")
                            }
                            .foregroundColor(.white)
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                        
                        Spacer()
                    }
                }
                
                // Rest of the view content
                if isShowingCamera {
                    Color.black
                        .edgesIgnoringSafeArea(.all)
                        .onAppear {
                            openCamera()
                        }
                } else if let image = capturedImage {
                    // Review captured photo
                    VStack {
                        Text("Your Photo")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                        
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .cornerRadius(12)
                            .padding()
                        
                        HStack(spacing: 30) {
                            Button(action: {
                                // Retake photo
                                capturedImage = nil
                                isShowingCamera = true
                            }) {
                                VStack {
                                    Image(systemName: "arrow.counterclockwise")
                                        .font(.system(size: 24))
                                    Text("Retake")
                                        .font(.caption)
                                }
                                .foregroundColor(.white)
                            }
                            
                            Button(action: {
                                // Upload photo
                                uploadPhoto(image)
                            }) {
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
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .foregroundColor(.white)
                                .padding(.top, 20)
                        }
                        
                        if uploadComplete {
                            Text("Photo uploaded successfully!")
                                .foregroundColor(.green)
                                .padding()
                                .onAppear {
                                    // Navigate back to event details instead of just dismissing
                                    // Photo upload complete, navigating to event details
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                        self.navigateToEventDetail()
                                    }
                                }
                        }
                    }
                }
            }
            }
        }
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .alert("Success", isPresented: $showSuccessAlert) {
            Button("View Contest", role: .cancel) {
                dismissToGallery()
            }
        } message: {
            Text("Your retro photo has been submitted to the contest!")
            }
            .onAppear {
                
                
                // Set up screenshot detection
                setupScreenshotDetection()
                
                // Open camera immediately
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    isShowingCamera = true
                }
            
            Task {
                await photoManager.checkContestEligibility()
            }
            }
            .onDisappear {
                // Cleanup all resources
                isShowingCamera = false
                capturedImage = nil
                timer?.invalidate()
                removeScreenshotDetection()
        }
    }
    
    // Set up screenshot detection notification
    private func setupScreenshotDetection() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.userDidTakeScreenshotNotification,
            object: nil,
            queue: .main
        ) { _ in
            handleScreenshotTaken()
        }
    }
    
    // Remove screenshot detection on view dismiss
    private func removeScreenshotDetection() {
        NotificationCenter.default.removeObserver(
            self,
            name: UIApplication.userDidTakeScreenshotNotification,
            object: nil
        )
    }
    
    // Handle screenshot taken
    private func handleScreenshotTaken() {
        // Show warning
        showScreenshotWarning = true
        
        // Blur or hide the image temporarily
        if isPhotoTaken {
            // Apply additional blur to the image to make the screenshot less useful
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if let originalImage = self.capturedImage {
                    self.capturedImage = applyHeavyBlur(to: originalImage)
                    
                    // Restore the original image after a delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        if isPhotoTaken {
                            self.capturedImage = applyRetroFilter(to: originalImage)
                        }
                    }
                }
            }
        }
        
        // Log screenshot attempt for analytics
        
    }
    
    // Apply a heavy blur to make screenshot unusable
    private func applyHeavyBlur(to image: UIImage) -> UIImage {
        let context = CIContext()
        guard let ciImage = CIImage(image: image) else { return image }
        
        let blurFilter = CIFilter.gaussianBlur()
        blurFilter.inputImage = ciImage
        blurFilter.radius = 20 // Heavy blur
        
        guard let outputImage = blurFilter.outputImage else { return image }
        
        // Add warning text
        let textFilter = CIFilter.attributedTextImageGenerator()
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 36),
            .foregroundColor: UIColor.white
        ]
        
        let text = NSAttributedString(string: "SCREENSHOT PROHIBITED", attributes: attributes)
        textFilter.setValue(text, forKey: "inputText")
        textFilter.setValue(10, forKey: "inputScaleFactor")
        
        guard let textImage = textFilter.outputImage else { return image }
        
        // Position the text in the center of the image
        let transform = CGAffineTransform(
            translationX: outputImage.extent.midX - textImage.extent.width / 2,
            y: outputImage.extent.midY - textImage.extent.height / 2
        )
        
        let transformedText = textImage.transformed(by: transform)
        
        // Combine the blurred image and text
        let compositeFilter = CIFilter.sourceOverCompositing()
        compositeFilter.inputImage = transformedText
        compositeFilter.backgroundImage = outputImage
        
        guard let compositeImage = compositeFilter.outputImage else { return image }
        
        // Convert back to UIImage
        if let cgImage = context.createCGImage(compositeImage, from: compositeImage.extent) {
            return UIImage(cgImage: cgImage)
        }
        
        return image
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if timeRemaining > 0 {
                // The timeRemaining will be automatically updated by PhotoManager
                if timeRemaining == 0 {
                timer?.invalidate()
                dismissView()
                }
            }
        }
    }
    
    private func checkEligibility() {
        if !photoManager.isEligibleForContest {
            errorMessage = "You are not eligible for this contest. You must be checked in at the event."
            showErrorAlert = true
            
            // Dismiss after showing the error
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                dismissView()
            }
        }
    }
    
    private func openCamera() {
        
        
        // Use standard UIImagePickerController with built-in controls
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.allowsEditing = false
        
        // Enable built-in controls
        picker.showsCameraControls = true
        picker.cameraFlashMode = .auto
        
        // Use the delegate for image capture
        picker.delegate = ImagePickerDelegate(onCapture: handleCapturedImage)
        
        // Present the camera
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(picker, animated: true)
        } else {
            
        }
    }
    
    private func createCameraOverlay(picker: UIImagePickerController) -> UIView {
        let screenSize = UIScreen.main.bounds.size
        let overlayView = UIView(frame: CGRect(x: 0, y: 0, width: screenSize.width, height: screenSize.height))
        overlayView.backgroundColor = .clear
        
        // Create a safer area for buttons (avoid notch/home indicator)
        let safeTopPadding: CGFloat = 50
        let safeBottomPadding: CGFloat = 120
        
        // Flash toggle button
        let flashButton = UIButton(type: .system)
        flashButton.setImage(UIImage(systemName: "bolt.slash.fill"), for: .normal)
        flashButton.tintColor = .white
        flashButton.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        flashButton.layer.cornerRadius = 25
        flashButton.frame = CGRect(x: screenSize.width - 70, y: safeTopPadding, width: 50, height: 50)
        
        var isFlashOn = false
        flashButton.addAction(UIAction { _ in
            isFlashOn.toggle()
            flashButton.setImage(UIImage(systemName: isFlashOn ? "bolt.fill" : "bolt.slash.fill"), for: .normal)
            picker.cameraFlashMode = isFlashOn ? .on : .off
        }, for: .touchUpInside)
        
        // Camera flip button
        let flipButton = UIButton(type: .system)
        flipButton.setImage(UIImage(systemName: "camera.rotate.fill"), for: .normal)
        flipButton.tintColor = .white
        flipButton.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        flipButton.layer.cornerRadius = 25
        flipButton.frame = CGRect(x: 20, y: safeTopPadding, width: 50, height: 50)
        
        flipButton.addAction(UIAction { _ in
            picker.cameraDevice = picker.cameraDevice == .rear ? .front : .rear
        }, for: .touchUpInside)
        
        // Capture button
        let captureButton = UIButton(type: .system)
        captureButton.backgroundColor = .white
        captureButton.layer.cornerRadius = 35
        captureButton.layer.borderWidth = 5
        captureButton.layer.borderColor = UIColor.white.withAlphaComponent(0.5).cgColor
        captureButton.frame = CGRect(x: (screenSize.width - 70) / 2, y: screenSize.height - safeBottomPadding, width: 70, height: 70)
        
        captureButton.addAction(UIAction { _ in
            // Flash animation
            UIView.animate(withDuration: 0.1, animations: {
                overlayView.backgroundColor = .white
                captureButton.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
            }) { _ in
                UIView.animate(withDuration: 0.1) {
                    overlayView.backgroundColor = .clear
                    captureButton.transform = .identity
                }
            }
            
            // Take picture
            picker.takePicture()
        }, for: .touchUpInside)
        
        // Add all controls to overlay
        overlayView.addSubview(flashButton)
        overlayView.addSubview(flipButton)
        overlayView.addSubview(captureButton)
        
        return overlayView
    }
    
    private func handleCapturedImage(image: UIImage?) {
        guard let originalImage = image else {
            // User canceled or failed to capture
            return
        }
        
        // Apply retro filter to the image
        let filteredImage = applyRetroFilter(to: originalImage)
        
        // Set state to show the filtered image
        self.capturedImage = filteredImage
        self.isPhotoTaken = true
    }
    
    private func uploadPhoto(_ image: UIImage) {
        isUploading = true
        
        // Generate a unique filename
        let fileName = "\(UUID().uuidString).jpg"
        let storageRef = Storage.storage().reference().child("contest_photos/\(eventId)/\(fileName)")
        
        // Compress the image for upload
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            errorMessage = "Could not process image for upload"
            showErrorAlert = true
            isUploading = false
            return
        }
        
        // Upload the image to Firebase Storage
        storageRef.putData(imageData, metadata: nil) { metadata, error in
            if let error = error {
                errorMessage = "Upload failed: \(error.localizedDescription)"
                showErrorAlert = true
                isUploading = false
                return
            }
            
            // Get the download URL
            storageRef.downloadURL { url, error in
                if let error = error {
                    errorMessage = "Failed to get download URL: \(error.localizedDescription)"
                    showErrorAlert = true
                    isUploading = false
                    return
                }
                
                guard let downloadURL = url else {
                    errorMessage = "Missing download URL"
                    showErrorAlert = true
                    isUploading = false
                    return
                }
                
                // Create a document in Firestore
                self.savePhotoMetadata(imageUrl: downloadURL.absoluteString)
            }
        }
    }
    
    private func savePhotoMetadata(imageUrl: String) {
        guard let userId = Auth.auth().currentUser?.uid else {
            errorMessage = "User not logged in"
            showErrorAlert = true
            isUploading = false
            return
        }
        
        let db = Firestore.firestore()
        
        let photoData: [String: Any] = [
            "userId": userId,
            "eventId": eventId,
            "imageUrl": imageUrl,
            "timestamp": FieldValue.serverTimestamp(),
            "likeCount": 0,
            "isContestEntry": true,  // Add this flag to identify contest photos
            "isPublic": true  // Make the photo publicly readable
        ]
        
        // Save to event_photos collection first
        db.collection("event_photos").document().setData(photoData) { error in
            if let error = error {
                
                self.errorMessage = "Failed to save photo: \(error.localizedDescription)"
                self.showErrorAlert = true
                self.isUploading = false
                return
            }
            
            // Then update the event's gallery
            db.collection("events").document(self.eventId).updateData([
                "galleryImages": FieldValue.arrayUnion([imageUrl])
            ]) { error in
                if let error = error {
                    
                }
                
                // Finally save to photo_contests collection
                db.collection("photo_contests").document().setData(photoData) { error in
                    self.isUploading = false
                    
                    if let error = error {
                        
                        return
                    }
                    
                    // Success - update UI and navigate
                    DispatchQueue.main.async {
                        self.uploadComplete = true
                        
                        // Notify that a new contest photo was added
                        NotificationCenter.default.post(
                            name: Notification.Name("ContestPhotoUploaded"),
                            object: nil,
                            userInfo: [
                                "eventId": self.eventId,
                                "imageUrl": imageUrl
                            ]
                        )
                        
                        // Show success alert and navigate
                        self.showSuccessAlert = true
                        
                        // Navigate back to event details after a brief delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            self.navigateToEventDetail()
                        }
                    }
                }
            }
        }
    }
    
    private func navigateToEventDetail() {
        
        
        // First dismiss this view
        dismissView()
        
        // Then post notification to navigate back to the event detail
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NotificationCenter.default.post(
                name: Notification.Name("NavigateToEvent"),
                object: nil,
                userInfo: [
                    "eventId": self.eventId,
                    "source": "photoContest",
                    "action": "showDetails",
                    "forceRefresh": true
                ]
            )
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
        // Ensure we're on the main thread when dismissing
        DispatchQueue.main.async {
            self.presentationMode.wrappedValue.dismiss()
        }
    }
    
    private func dismissToGallery() {
        // First dismiss this view
        dismissView()
        
        // Then post notification to navigate to gallery
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NotificationCenter.default.post(
                name: Notification.Name("NavigateToEvent"),
                object: nil,
                userInfo: [
                    "eventId": self.eventId,
                    "source": "photoContest",
                    "action": "showGallery",
                    "forceRefresh": true
                ]
            )
        }
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

struct ContestPhotoCaptureView_Previews: PreviewProvider {
    static var previews: some View {
        ContestPhotoCaptureView(eventId: "test-event-id")
    }
} 