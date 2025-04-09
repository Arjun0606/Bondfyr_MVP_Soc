import SwiftUI
import AVFoundation

struct TicketScannerView: View {
    @State private var isScanning = false
    @State private var scannedCode: String?
    @State private var lastScannedTicketId: String?
    @State private var showSuccessAlert = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var eventId: String?
    @State private var eventName: String?
    
    // Camera permission state
    @State private var cameraPermissionGranted = false
    
    // Reference to check-in manager to validate tickets
    private let checkInManager = CheckInManager.shared
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            VStack {
                if cameraPermissionGranted {
                    QRScannerRepresentable(
                        isScanning: $isScanning,
                        scannedCode: $scannedCode
                    )
                    .frame(height: UIScreen.main.bounds.height * 0.7)
                    .padding(.horizontal)
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.5), lineWidth: 2)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.5), lineWidth: 2)
                            .padding(4)
                    )
                    .onChange(of: scannedCode) { newValue in
                        if let code = newValue {
                            handleScannedCode(code)
                        }
                    }
                } else {
                    VStack(spacing: 24) {
                        Image(systemName: "camera.metering.none")
                            .font(.system(size: 80))
                            .foregroundColor(.white.opacity(0.7))
                        
                        Text("Camera access is required to scan tickets")
                            .font(.headline)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                        
                        Button(action: {
                            requestCameraPermission()
                        }) {
                            Text("Allow Camera Access")
                                .font(.headline)
                                .foregroundColor(.black)
                                .padding()
                                .background(Color.white)
                                .cornerRadius(10)
                        }
                    }
                    .padding()
                }
                
                Spacer()
                
                Text("Position the QR code in the scanner")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
            }
            .onAppear {
                checkCameraPermission()
            }
        }
        .alert(isPresented: $showSuccessAlert) {
            Alert(
                title: Text("Check-in Successful"),
                message: Text("The ticket has been successfully validated."),
                dismissButton: .default(Text("OK")) {
                    // If we have eventId and eventName, handle photo contest unlock
                    if let eventId = eventId, let eventName = eventName {
                        handlePhotoContestUnlock(for: eventId, eventName: eventName)
                    }
                    
                    // Reset for next scan
                    resetScanner()
                }
            )
        }
        .alert(isPresented: $showErrorAlert) {
            Alert(
                title: Text("Error"),
                message: Text(errorMessage),
                dismissButton: .default(Text("OK")) {
                    resetScanner()
                }
            )
        }
    }
    
    private func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            self.cameraPermissionGranted = true
            self.isScanning = true
        case .notDetermined:
            requestCameraPermission()
        case .denied, .restricted:
            self.cameraPermissionGranted = false
            self.errorMessage = "Camera access is denied. Please enable it in Settings."
            self.showErrorAlert = true
        @unknown default:
            self.cameraPermissionGranted = false
            self.errorMessage = "Unknown camera authorization status."
            self.showErrorAlert = true
        }
    }
    
    private func requestCameraPermission() {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                self.cameraPermissionGranted = granted
                self.isScanning = granted
                
                if !granted {
                    self.errorMessage = "Camera access is required to scan tickets."
                    self.showErrorAlert = true
                }
            }
        }
    }
    
    private func handleScannedCode(_ code: String) {
        // Temporarily stop scanning to avoid multiple scans
        isScanning = false
        
        // Parse the scanned QR code (expecting a ticket ID or formatted data)
        checkInManager.validateScannedTicket(withCode: code) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let ticketInfo):
                    self.lastScannedTicketId = ticketInfo.ticketId
                    self.eventId = ticketInfo.eventId
                    self.eventName = ticketInfo.eventName
                    self.showSuccessAlert = true
                    
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                    self.showErrorAlert = true
                }
            }
        }
    }
    
    private func resetScanner() {
        // Clear the scanned code and restart scanning
        scannedCode = nil
        isScanning = true
    }
}

// AVFoundation-based QR Scanner
struct QRScannerRepresentable: UIViewRepresentable {
    @Binding var isScanning: Bool
    @Binding var scannedCode: String?
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        let captureSession = AVCaptureSession()
        
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else { return view }
        
        let videoInput: AVCaptureDeviceInput
        
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            return view
        }
        
        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        } else {
            return view
        }
        
        let metadataOutput = AVCaptureMetadataOutput()
        
        if captureSession.canAddOutput(metadataOutput) {
            captureSession.addOutput(metadataOutput)
            
            metadataOutput.setMetadataObjectsDelegate(context.coordinator, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr]
        } else {
            return view
        }
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        // Store session in coordinator to control it
        context.coordinator.captureSession = captureSession
        context.coordinator.previewLayer = previewLayer
        
        if isScanning {
            context.coordinator.startScanning()
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let previewLayer = context.coordinator.previewLayer {
            previewLayer.frame = uiView.bounds
        }
        
        if isScanning != context.coordinator.isScanning {
            if isScanning {
                context.coordinator.startScanning()
            } else {
                context.coordinator.stopScanning()
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        var parent: QRScannerRepresentable
        var captureSession: AVCaptureSession?
        var previewLayer: AVCaptureVideoPreviewLayer?
        var isScanning = false
        
        init(_ parent: QRScannerRepresentable) {
            self.parent = parent
        }
        
        func startScanning() {
            if let captureSession = captureSession, !captureSession.isRunning {
                DispatchQueue.global(qos: .background).async { [weak self] in
                    self?.captureSession?.startRunning()
                    DispatchQueue.main.async {
                        self?.isScanning = true
                    }
                }
            }
        }
        
        func stopScanning() {
            if let captureSession = captureSession, captureSession.isRunning {
                DispatchQueue.global(qos: .background).async { [weak self] in
                    self?.captureSession?.stopRunning()
                    DispatchQueue.main.async {
                        self?.isScanning = false
                    }
                }
            }
        }
        
        func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
            if !isScanning {
                return
            }
            
            if let metadataObject = metadataObjects.first,
               let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject,
               let stringValue = readableObject.stringValue {
                
                // Found a code, pass it back to the parent
                parent.scannedCode = stringValue
                
                // Automatically stop scanning after finding a code
                isScanning = false
                stopScanning()
            }
        }
    }
}

// Don't redefine CheckInManager here - use extension instead
extension CheckInManager {
    // Add a method to validate tickets that works with the TicketScannerView
    func validateScannedTicket(withCode code: String, completion: @escaping (Result<TicketValidationResult, Error>) -> Void) {
        // In a real implementation, this would validate the ticket against a database
        // For now, we'll simulate a successful validation with a delay
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // Parse the code - in a real app, this would be a proper ticket ID format
            if code.count > 8 {
                // Return success with ticket info
                let result = TicketValidationResult(
                    ticketId: code,
                    eventId: "event-123",
                    eventName: "Summer Party",
                    userName: "Guest"
                )
                completion(.success(result))
            } else {
                // Return error for invalid format
                let error = NSError(domain: "TicketScanner", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid ticket format"])
                completion(.failure(error))
            }
        }
    }
}

// Result type for ticket validation
struct TicketValidationResult {
    let ticketId: String
    let eventId: String
    let eventName: String
    let userName: String
    
    // Add explicit initializer to fix ambiguity
    init(ticketId: String, eventId: String, eventName: String, userName: String) {
        self.ticketId = ticketId
        self.eventId = eventId
        self.eventName = eventName
        self.userName = userName
    }
}

// Preview
struct TicketScannerView_Previews: PreviewProvider {
    static var previews: some View {
        TicketScannerView()
    }
} 