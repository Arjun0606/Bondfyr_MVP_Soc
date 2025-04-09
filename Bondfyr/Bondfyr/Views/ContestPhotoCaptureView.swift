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
    @State private var timeRemaining = 0
    @State private var timer: Timer?
    @State private var isUploading = false
    @State private var showScreenshotWarning = false
    @State private var isShowingCamera = true
    @State private var uploadComplete = false
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            if isShowingCamera {
                ZStack {
                    CameraView(capturedImage: $capturedImage, isShowingCamera: $isShowingCamera)
                        .edgesIgnoringSafeArea(.all)
                        .transition(.opacity)
                    
                    VStack {
                        HStack {
                            Button(action: {
                                // Stop camera and cleanup
                                isShowingCamera = false
                                capturedImage = nil
                                timer?.invalidate()
                                removeScreenshotDetection()
                                
                                // Dismiss the view immediately
                                DispatchQueue.main.async {
                                    presentationMode.wrappedValue.dismiss()
                                }
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 30))
                                    .foregroundColor(.white)
                                    .padding()
                                    .background(Color.black.opacity(0.5))
                                    .clipShape(Circle())
                            }
                            .padding(.leading)
                            Spacer()
                        }
                        Spacer()
                    }
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
                                // Dismiss the view after upload is complete
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                    presentationMode.wrappedValue.dismiss()
                                }
                            }
                    }
                }
            }
        }
        .alert(isPresented: $showErrorAlert) {
            Alert(
                title: Text("Error"),
                message: Text(errorMessage),
                dismissButton: .default(Text("OK"))
            )
        }
        .onAppear {
            print("ContestPhotoCaptureView appeared, will open camera")
            
            // Set up screenshot detection
            setupScreenshotDetection()
            
            // Open camera immediately
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                isShowingCamera = true
            }
        }
        .onDisappear {
            // Cleanup all resources
            isShowingCamera = false
            capturedImage = nil
            timer?.invalidate()
            removeScreenshotDetection()
        }
        .alert("Success", isPresented: $showSuccessAlert) {
            Button("View Contest", role: .cancel) {
                dismissToGallery()
            }
        } message: {
            Text("Your retro photo has been submitted to the contest!")
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
        print("Screenshot taken during photo contest view")
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
        print("Opening camera for contest photo capture")
        
        // Fall back to standard UIImagePickerController which is more reliable
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.allowsEditing = false
        picker.delegate = ImagePickerDelegate(onCapture: handleCapturedImage)
        
        // Present the camera
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            // Check if a controller is already being presented
            if rootViewController.presentedViewController != nil {
                rootViewController.dismiss(animated: true) {
                    // After dismissing, then present the camera
                    rootViewController.present(picker, animated: true)
                }
            } else {
                rootViewController.present(picker, animated: true)
            }
        } else {
            print("ERROR: Could not find root view controller to present camera")
        }
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
                savePhotoMetadata(imageUrl: downloadURL.absoluteString)
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
            "likeCount": 0
        ]
        
        db.collection("photo_contests").document().setData(photoData) { error in
            isUploading = false
            
            if let error = error {
                errorMessage = "Failed to save photo data: \(error.localizedDescription)"
                showErrorAlert = true
                return
            }
            
            // Success
            uploadComplete = true
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

// Custom Camera View Controller with flip camera functionality
class CustomCameraViewController: UIViewController, AVCapturePhotoCaptureDelegate {
    // Capture session and device
    private let captureSession = AVCaptureSession()
    private var currentCameraPosition: AVCaptureDevice.Position = .back
    private var cameraOutput = AVCapturePhotoOutput()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    
    // UI Elements
    private var cancelButton: UIButton!
    private var flipCameraButton: UIButton!
    private var captureButton: UIButton!
    
    // Callback for captured image
    var onCapture: ((UIImage?) -> Void)?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupCaptureSession()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startCaptureSession()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopCaptureSession()
    }
    
    private func setupUI() {
        view.backgroundColor = .black
        
        // Preview view
        let previewView = UIView()
        previewView.backgroundColor = .black
        previewView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(previewView)
        
        // Camera controls container
        let controlsView = UIView()
        controlsView.backgroundColor = .clear
        controlsView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(controlsView)
        
        // Cancel button
        cancelButton = UIButton(type: .system)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        cancelButton.tintColor = .white
        cancelButton.backgroundColor = UIColor.gray.withAlphaComponent(0.5)
        cancelButton.layer.cornerRadius = 20
        cancelButton.addTarget(self, action: #selector(cancelButtonTapped), for: .touchUpInside)
        view.addSubview(cancelButton)
        
        // Flip camera button
        flipCameraButton = UIButton(type: .system)
        flipCameraButton.translatesAutoresizingMaskIntoConstraints = false
        flipCameraButton.setImage(UIImage(systemName: "camera.rotate"), for: .normal)
        flipCameraButton.tintColor = .white
        flipCameraButton.backgroundColor = UIColor.gray.withAlphaComponent(0.5)
        flipCameraButton.layer.cornerRadius = 20
        flipCameraButton.addTarget(self, action: #selector(flipCameraButtonTapped), for: .touchUpInside)
        view.addSubview(flipCameraButton)
        
        // Capture button
        captureButton = UIButton(type: .system)
        captureButton.translatesAutoresizingMaskIntoConstraints = false
        captureButton.backgroundColor = .white
        captureButton.layer.cornerRadius = 35
        captureButton.layer.borderWidth = 5
        captureButton.layer.borderColor = UIColor.white.withAlphaComponent(0.5).cgColor
        captureButton.addTarget(self, action: #selector(captureButtonTapped), for: .touchUpInside)
        controlsView.addSubview(captureButton)
        
        // Setup constraints
        NSLayoutConstraint.activate([
            // Preview view
            previewView.topAnchor.constraint(equalTo: view.topAnchor),
            previewView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            previewView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            previewView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // Cancel button
            cancelButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            cancelButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            cancelButton.widthAnchor.constraint(equalToConstant: 40),
            cancelButton.heightAnchor.constraint(equalToConstant: 40),
            
            // Flip camera button
            flipCameraButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            flipCameraButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            flipCameraButton.widthAnchor.constraint(equalToConstant: 40),
            flipCameraButton.heightAnchor.constraint(equalToConstant: 40),
            
            // Controls view
            controlsView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            controlsView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            controlsView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            controlsView.heightAnchor.constraint(equalToConstant: 100),
            
            // Capture button
            captureButton.centerXAnchor.constraint(equalTo: controlsView.centerXAnchor),
            captureButton.centerYAnchor.constraint(equalTo: controlsView.centerYAnchor),
            captureButton.widthAnchor.constraint(equalToConstant: 70),
            captureButton.heightAnchor.constraint(equalToConstant: 70)
        ])
        
        // Store the preview view reference to add the layer to
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer?.videoGravity = .resizeAspectFill
        previewLayer?.frame = previewView.bounds
        previewLayer?.connection?.videoOrientation = .portrait
        
        if let previewLayer = previewLayer {
            previewView.layer.addSublayer(previewLayer)
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }
    
    private func setupCaptureSession() {
        captureSession.beginConfiguration()
        
        // Setup inputs
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: currentCameraPosition) else {
            print("Failed to get the camera device")
            return
        }
        
        do {
            let cameraInput = try AVCaptureDeviceInput(device: camera)
            if captureSession.canAddInput(cameraInput) {
                captureSession.addInput(cameraInput)
            }
            
            if captureSession.canAddOutput(cameraOutput) {
                captureSession.addOutput(cameraOutput)
            }
        } catch {
            print("Error setting up camera: \(error.localizedDescription)")
        }
        
        captureSession.commitConfiguration()
    }
    
    private func startCaptureSession() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession.startRunning()
        }
    }
    
    private func stopCaptureSession() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession.stopRunning()
        }
    }
    
    @objc private func cancelButtonTapped() {
        dismiss(animated: true) {
            self.onCapture?(nil)
        }
    }
    
    @objc private func flipCameraButtonTapped() {
        // Flip the camera
        currentCameraPosition = (currentCameraPosition == .back) ? .front : .back
        
        // Reconfigure session with new camera
        captureSession.beginConfiguration()
        
        // Remove existing inputs
        for input in captureSession.inputs {
            captureSession.removeInput(input)
        }
        
        // Add new input
        if let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: currentCameraPosition),
           let cameraInput = try? AVCaptureDeviceInput(device: camera),
           captureSession.canAddInput(cameraInput) {
            captureSession.addInput(cameraInput)
        }
        
        captureSession.commitConfiguration()
    }
    
    @objc private func captureButtonTapped() {
        // Flash button animation
        UIView.animate(withDuration: 0.1, animations: {
            self.view.backgroundColor = UIColor.white
            self.captureButton.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                self.view.backgroundColor = UIColor.black
                self.captureButton.transform = CGAffineTransform.identity
            }
        }
        
        // Capture the photo
        let settings = AVCapturePhotoSettings()
        cameraOutput.capturePhoto(with: settings, delegate: self)
    }
    
    // AVCapturePhotoCaptureDelegate method
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("Error capturing photo: \(error.localizedDescription)")
            onCapture?(nil)
            return
        }
        
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            print("Error converting photo to image")
            onCapture?(nil)
            return
        }
        
        // Dismiss the camera view and provide the captured image
        DispatchQueue.main.async {
            self.dismiss(animated: true) {
                self.onCapture?(image)
            }
        }
    }
}

// Camera view using UIViewRepresentable
struct CameraView: UIViewRepresentable {
    @Binding var capturedImage: UIImage?
    @Binding var isShowingCamera: Bool
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        
        let captureSession = AVCaptureSession()
        context.coordinator.captureSession = captureSession
        
        guard let backCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: backCamera) else {
            return view
        }
        
        if captureSession.canAddInput(input) {
            captureSession.addInput(input)
        }
        
        // Configure photo output
        let photoOutput = AVCapturePhotoOutput()
        context.coordinator.photoOutput = photoOutput
        
        if captureSession.canAddOutput(photoOutput) {
            captureSession.addOutput(photoOutput)
        }
        
        // Setup preview layer
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)
        
        // Add capture button
        let buttonSize: CGFloat = 70
        let captureButton = UIButton(frame: CGRect(
            x: (view.bounds.width - buttonSize) / 2,
            y: view.bounds.height - buttonSize - 60,
            width: buttonSize,
            height: buttonSize
        ))
        
        captureButton.backgroundColor = .white
        captureButton.layer.cornerRadius = buttonSize / 2
        captureButton.layer.borderWidth = 6
        captureButton.layer.borderColor = UIColor.white.cgColor
        captureButton.addTarget(context.coordinator, action: #selector(Coordinator.capturePhoto), for: .touchUpInside)
        
        view.addSubview(captureButton)
        
        // Start capture session
        DispatchQueue.global(qos: .userInitiated).async {
            captureSession.startRunning()
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if !isShowingCamera {
            context.coordinator.stopSession()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, AVCapturePhotoCaptureDelegate {
        var parent: CameraView
        var captureSession: AVCaptureSession?
        var photoOutput: AVCapturePhotoOutput?
        
        init(_ parent: CameraView) {
            self.parent = parent
        }
        
        func stopSession() {
            DispatchQueue.global(qos: .userInitiated).async {
                self.captureSession?.stopRunning()
            }
        }
        
        @objc func capturePhoto() {
            guard let photoOutput = photoOutput else { return }
            
            let settings = AVCapturePhotoSettings()
            if let previewPixelType = settings.availablePreviewPhotoPixelFormatTypes.first {
                settings.previewPhotoFormat = [kCVPixelBufferPixelFormatTypeKey as String: previewPixelType]
            }
            
            photoOutput.capturePhoto(with: settings, delegate: self)
        }
        
        func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
            if let error = error {
                print("Error capturing photo: \(error.localizedDescription)")
                parent.capturedImage = nil
                parent.isShowingCamera = false
                return
            }
            
            guard let imageData = photo.fileDataRepresentation(), 
                  let image = UIImage(data: imageData) else {
                return
            }
            
            // Update the parent view
            DispatchQueue.main.async {
                self.parent.capturedImage = image
                self.parent.isShowingCamera = false
            }
        }
    }
}

struct ContestPhotoCaptureView_Previews: PreviewProvider {
    static var previews: some View {
        ContestPhotoCaptureView(eventId: "test-event-id")
    }
} 