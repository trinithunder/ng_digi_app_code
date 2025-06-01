//
//  CustomCameraView.swift
//  NGDigital
//
//  Created by Marlon on 6/1/25.
//

import SwiftUI
import AVFoundation
import Foundation

struct CustomCameraView: UIViewControllerRepresentable {
    @Binding var capturedImage: UIImage?
    @Binding var capturedVideoURL: URL?
    
    class Coordinator: NSObject, AVCaptureFileOutputRecordingDelegate, AVCapturePhotoCaptureDelegate {
        var parent: CustomCameraView
        let session = AVCaptureSession()
        let output = AVCaptureMovieFileOutput()
        let photoOutput = AVCapturePhotoOutput()
        var previewLayer: AVCaptureVideoPreviewLayer?

        var currentCamera: AVCaptureDevice.Position = .back

        init(parent: CustomCameraView) {
            self.parent = parent
            super.init()
            configureSession()
        }

        private func configureSession() {
            session.beginConfiguration()
            session.sessionPreset = .high

            if let device = camera(for: currentCamera),
               let input = try? AVCaptureDeviceInput(device: device),
               session.canAddInput(input) {
                session.addInput(input)
            }

            if session.canAddOutput(output) {
                session.addOutput(output)
            }

            if session.canAddOutput(photoOutput) {
                session.addOutput(photoOutput)
            }

            session.commitConfiguration()
            session.startRunning()
        }

        func camera(for position: AVCaptureDevice.Position) -> AVCaptureDevice? {
            AVCaptureDevice.devices().first { $0.position == position && $0.hasMediaType(.video) }
        }

        func switchCamera() {
            session.beginConfiguration()
            for input in session.inputs {
                session.removeInput(input)
            }
            currentCamera = currentCamera == .back ? .front : .back
            if let newDevice = camera(for: currentCamera),
               let input = try? AVCaptureDeviceInput(device: newDevice) {
                session.addInput(input)
            }
            session.commitConfiguration()
        }

        func takePhoto() {
            let settings = AVCapturePhotoSettings()
            photoOutput.capturePhoto(with: settings, delegate: self)
        }

        func startVideoRecording() {
            let fileURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString + ".mov")
            output.startRecording(to: fileURL, recordingDelegate: self)
        }

        func stopVideoRecording() {
            output.stopRecording()
        }

        // MARK: - AVCaptureFileOutputRecordingDelegate
        func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
            DispatchQueue.main.async {
                self.parent.capturedVideoURL = outputFileURL
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> UIViewController {
        let viewController = UIViewController()
        let previewLayer = AVCaptureVideoPreviewLayer(session: context.coordinator.session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = UIScreen.main.bounds
        viewController.view.layer.addSublayer(previewLayer)
        context.coordinator.previewLayer = previewLayer

        return viewController
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

//– SwiftUI Controls for the Camera
struct CameraScreen: View {
    @State private var capturedImage: UIImage?
    @State private var capturedVideoURL: URL?

    @StateObject private var cameraManager = CameraManager()

    var body: some View {
        ZStack {
            CustomCameraView(capturedImage: $capturedImage, capturedVideoURL: $capturedVideoURL)

            VStack {
                Spacer()
                HStack {
                    Button(action: {
                        cameraManager.takePhoto()
                    }) {
                        Circle().strokeBorder(Color.white, lineWidth: 4)
                            .frame(width: 70, height: 70)
                    }

                    Button(action: {
                        if cameraManager.isRecording {
                            cameraManager.stopRecording()
                        } else {
                            cameraManager.startRecording()
                        }
                    }) {
                        Circle()
                            .fill(cameraManager.isRecording ? Color.red : Color.white)
                            .frame(width: 70, height: 70)
                    }

                    Button(action: {
                        cameraManager.switchCamera()
                    }) {
                        Image(systemName: "camera.rotate")
                            .foregroundColor(.white)
                            .font(.title)
                    }
                }
                .padding()
            }
        }
        .onAppear {
            cameraManager.setSession(from: capturedImage, videoURL: capturedVideoURL)
        }
    }
}

class CameraManager: ObservableObject {
    var coordinator: CustomCameraView.Coordinator?
    @Published var isRecording = false

    func setSession(from image: UIImage?, videoURL: URL?) {
        // Optional setup if needed
    }

    func takePhoto() {
        coordinator?.takePhoto()
    }

    func startRecording() {
        coordinator?.startVideoRecording()
        isRecording = true
    }

    func stopRecording() {
        coordinator?.stopVideoRecording()
        isRecording = false
    }

    func switchCamera() {
        coordinator?.switchCamera()
    }
}




//struct CustomCameraView_Previews: PreviewProvider {
//    static var previews: some View {
//        CustomCameraView(capturedImage: nil, capturedVideoURL: nil)
//    }
//}
