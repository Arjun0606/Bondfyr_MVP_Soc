import SwiftUI
import AVFoundation
import UIKit

struct CityPhotoCamera: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var cameraManager = CameraManager()
    @State private var capturedImage: UIImage?
    @State private var isFlashOn = false
    @State private var isFrontCamera = false
    @State private var showingPreview = false
    @State private var isUploading = false
    let currentCity: String
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Camera preview
                CameraPreviewView(session: cameraManager.session)
                    .edgesIgnoringSafeArea(.all)
                
                // Camera controls overlay
                VStack {
                    // Top controls
                    HStack {
                        // Close button
                        Button(action: {
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                                .padding(12)
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                        }
                        
                        Spacer()
                        
                        // Flash toggle
                        Button(action: toggleFlash) {
                            Image(systemName: isFlashOn ? "bolt.fill" : "bolt.slash.fill")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                                .padding(12)
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                        }
                    }
                    .padding()
                    
                    Spacer()
                    
                    // City indicator
                    Text(currentCity)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(20)
                    
                    // Bottom controls
                    HStack {
                        Spacer()
                        
                        // Capture button
                        Button(action: capturePhoto) {
                            ZStack {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 65, height: 65)
                                Circle()
                                    .stroke(Color.white.opacity(0.3), lineWidth: 3)
                                    .frame(width: 75, height: 75)
                            }
                        }
                        
                        Spacer()
                        
                        // Camera flip
                        Button(action: switchCamera) {
                            Image(systemName: "camera.rotate.fill")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                                .padding(12)
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, geometry.safeAreaInsets.bottom + 20)
                }
            }
        }
        .sheet(isPresented: $showingPreview) {
            if let image = capturedImage {
                PhotoPreviewView(image: image, city: currentCity) { 
                    // Handle successful upload
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
        .onAppear {
            cameraManager.checkPermissionsAndSetup()
        }
    }
    
    private func toggleFlash() {
        isFlashOn.toggle()
        cameraManager.toggleFlash(isOn: isFlashOn)
    }
    
    private func switchCamera() {
        isFrontCamera.toggle()
        cameraManager.switchCamera()
    }
    
    private func capturePhoto() {
        cameraManager.capturePhoto { image in
            capturedImage = image
            showingPreview = true
        }
    }
}

// Camera preview using UIViewRepresentable
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: CGRect.zero)
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let layer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            layer.frame = uiView.bounds
        }
    }
}

// Camera manager class
class CameraManager: NSObject, ObservableObject {
    @Published var session = AVCaptureSession()
    private var camera: AVCaptureDevice?
    private var input: AVCaptureDeviceInput?
    private var output = AVCapturePhotoOutput()
    private var completion: ((UIImage?) -> Void)?
    
    override init() {
        super.init()
    }
    
    func checkPermissionsAndSetup() {
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
        do {
            session.beginConfiguration()
            
            // Add input
            camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
            guard let camera = camera else { return }
            input = try AVCaptureDeviceInput(device: camera)
            if session.canAddInput(input!) {
                session.addInput(input!)
            }
            
            // Add output
            if session.canAddOutput(output) {
                session.addOutput(output)
            }
            
            session.commitConfiguration()
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.session.startRunning()
            }
        } catch {
            print("Camera setup error: \(error)")
        }
    }
    
    func toggleFlash(isOn: Bool) {
        guard let device = camera else { return }
        if device.hasTorch {
            do {
                try device.lockForConfiguration()
                device.torchMode = isOn ? .on : .off
                device.unlockForConfiguration()
            } catch {
                print("Flash error: \(error)")
            }
        }
    }
    
    func switchCamera() {
        guard let currentInput = input else { return }
        session.beginConfiguration()
        session.removeInput(currentInput)
        
        let newPosition: AVCaptureDevice.Position = currentInput.device.position == .back ? .front : .back
        camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPosition)
        
        do {
            guard let camera = camera else { return }
            input = try AVCaptureDeviceInput(device: camera)
            if session.canAddInput(input!) {
                session.addInput(input!)
            }
        } catch {
            print("Camera switch error: \(error)")
        }
        
        session.commitConfiguration()
    }
    
    func capturePhoto(completion: @escaping (UIImage?) -> Void) {
        self.completion = completion
        let settings = AVCapturePhotoSettings()
        if let device = camera, device.hasTorch {
            settings.flashMode = device.torchMode == .on ? .on : .off
        }
        output.capturePhoto(with: settings, delegate: self)
    }
}

extension CameraManager: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            completion?(nil)
            return
        }
        completion?(image)
    }
} 