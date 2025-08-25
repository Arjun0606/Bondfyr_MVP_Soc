//
//  PhotoCaptureView.swift
//  Bondfyr
//
//  Created by Arjun Varma on 31/03/25.
//

import SwiftUI
import AVFoundation

struct PhotoCaptureView: UIViewControllerRepresentable {
    var onCapture: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        var parent: PhotoCaptureView

        init(_ parent: PhotoCaptureView) {
            self.parent = parent
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true) {
                if let windowScene = UIApplication.shared.connectedScenes
                    .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
                   let window = windowScene.windows.first {
                    window.rootViewController = UIHostingController(
                        rootView: MainTabView()
                            .environmentObject(AuthViewModel())
                            .environmentObject(TabSelection())
                            .environmentObject(AppStoreDemoManager.shared)
                    )
                    window.makeKeyAndVisible()
                }
            }
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onCapture(image)
            }
            picker.dismiss(animated: true)
        }
    }
}
