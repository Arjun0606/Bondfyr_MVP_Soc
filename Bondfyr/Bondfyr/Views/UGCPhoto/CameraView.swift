import SwiftUI
import AVFoundation
import Bondfyr

struct CameraView: View {
    @StateObject private var camera = CameraController()
    @Environment(\.dismiss) var dismiss
    @State private var showPreview = false
    @State private var capturedImage: UIImage?
    @State private var showError = false
    @State private var errorMessage = ""
    @StateObject private var photoService = UGCPhotoService()
    @State private var isUploading = false
    
    var body: some View {
        ZStack {
            // Camera preview
            CameraPreviewView(camera: camera)
                .ignoresSafeArea()
            
            // Camera controls
            VStack {
                Spacer()
                
                HStack {
                    Spacer()
                    
                    // Capture button
                    Button(action: {
                        camera.capturePhoto { result in
                            switch result {
                            case .success(let image):
                                capturedImage = image
                                showPreview = true
                            case .failure(let error):
                                errorMessage = error.localizedDescription
                                showError = true
                            }
                        }
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 65, height: 65)
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                                .frame(width: 75, height: 75)
                        }
                    }
                    .disabled(isUploading)
                    
                    Spacer()
                    
                    // Camera flip button
                    Button(action: {
                        camera.switchCamera()
                    }) {
                        Image(systemName: "camera.rotate.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                            .padding()
                    }
                    .disabled(isUploading)
                }
                .padding(.bottom, 30)
            }
        }
        .sheet(isPresented: $showPreview) {
            if let image = capturedImage {
                PhotoPreviewView(image: image) { shouldUpload in
                    if shouldUpload {
                        uploadPhoto(image)
                    }
                    showPreview = false
                }
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            camera.checkPermissions()
        }
    }
    
    private func uploadPhoto(_ image: UIImage) {
        guard let city = UserDefaults.standard.string(forKey: "selectedCity") else {
            errorMessage = "Please select a city first"
            showError = true
            return
        }
        
        isUploading = true
        
        Task {
            do {
                _ = try await photoService.uploadPhoto(image, city: city, country: "India")
                await MainActor.run {
                    isUploading = false
                    dismiss()
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

// Camera preview using UIViewRepresentable
struct CameraPreviewView: UIViewRepresentable {
    let camera: CameraController
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        camera.preview.frame = view.bounds
        view.layer.addSublayer(camera.preview)
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) { }
}

// Photo preview view
struct PhotoPreviewView: View {
    let image: UIImage
    let onDismiss: (Bool) -> Void
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onDismiss(false)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Upload") {
                        onDismiss(true)
                    }
                }
            }
        }
    }
}

// Camera controller using AVFoundation
class CameraController: NSObject, ObservableObject {
    @Published var error: Error?
    
    let preview = AVCaptureVideoPreviewLayer()
    private var captureSession: AVCaptureSession?
    private var currentCamera: AVCaptureDevice?
    private var photoOutput: AVCapturePhotoOutput?
    private var completion: ((Result<UIImage, Error>) -> Void)?
    
    override init() {
        super.init()
        setupCamera()
    }
    
    func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted {
                    DispatchQueue.main.async {
                        self?.setupCamera()
                    }
                }
            }
        default:
            break
        }
    }
    
    private func setupCamera() {
        let session = AVCaptureSession()
        
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
            do {
                let input = try AVCaptureDeviceInput(device: device)
                if session.canAddInput(input) {
                    session.addInput(input)
                }
                
                let output = AVCapturePhotoOutput()
                if session.canAddOutput(output) {
                    session.addOutput(output)
                    self.photoOutput = output
                }
                
                preview.session = session
                preview.videoGravity = .resizeAspectFill
                
                self.captureSession = session
                self.currentCamera = device
                
                DispatchQueue.global(qos: .userInitiated).async {
                    session.startRunning()
                }
            } catch {
                self.error = error
            }
        }
    }
    
    func switchCamera() {
        guard let session = captureSession,
              let currentInput = session.inputs.first as? AVCaptureDeviceInput else { return }
        
        let newPosition: AVCaptureDevice.Position = currentInput.device.position == .back ? .front : .back
        
        guard let newDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPosition),
              let newInput = try? AVCaptureDeviceInput(device: newDevice) else { return }
        
        session.beginConfiguration()
        session.removeInput(currentInput)
        
        if session.canAddInput(newInput) {
            session.addInput(newInput)
            currentCamera = newDevice
        }
        
        session.commitConfiguration()
    }
    
    func capturePhoto(completion: @escaping (Result<UIImage, Error>) -> Void) {
        self.completion = completion
        
        guard let photoOutput = self.photoOutput else {
            completion(.failure(NSError(domain: "CameraController", code: 0, userInfo: [NSLocalizedDescriptionKey: "Photo output not available"])))
            return
        }
        
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
}

extension CameraController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            completion?(.failure(error))
            return
        }
        
        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            completion?(.failure(NSError(domain: "CameraController", code: 0, userInfo: [NSLocalizedDescriptionKey: "Could not create image from photo"])))
            return
        }
        
        completion?(.success(image))
    }
} 