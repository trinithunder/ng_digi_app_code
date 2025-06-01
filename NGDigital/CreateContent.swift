//
//  CreateContent.swift
//  NGDigital
//
//  Created by Marlon on 6/1/25.
//

import SwiftUI
import PhotosUI
import UIKit
import AVFoundation

struct CreateContentView: View {
    @EnvironmentObject var gk: GateKeeper

    @State private var postText: String = ""
    @State private var selectedImage: UIImage?
    @State private var selectedVideoURL: URL?
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showPicker = false
    @State private var pickingType: PickerType = .image
    
    enum PickerType {
            case image, video
        }
    
    var body: some View {
            VStack {
                Button("Select Image") {
                    pickingType = .image
                    showPicker = true
                }

                Button("Select Video") {
                    pickingType = .video
                    showPicker = true
                }

                if let image = selectedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 200)
                }

                if let videoURL = selectedVideoURL {
                    Text("Selected Video: \(videoURL.lastPathComponent)")
                }
            }
            .sheet(isPresented: $showPicker) {
                MediaPicker(
                    selectedImage: $selectedImage,
                    selectedVideoURL: $selectedVideoURL,
                    mediaTypes: pickingType == .image ? ["public.image"] : ["public.movie"]
                )
            }
        }

    func createPost() {
        guard let url = URL(string: "https://lightek.diy/posts") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(gk.appSettings.authToken)", forHTTPHeaderField: "Authorization")

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var data = Data()

        // Text content
        data.append("--\(boundary)\r\n".data(using: .utf8)!)
        data.append("Content-Disposition: form-data; name=\"content\"\r\n\r\n".data(using: .utf8)!)
        data.append("\(postText)\r\n".data(using: .utf8)!)

        // Image
        if let image = selectedImage,
           let imageData = image.jpegData(compressionQuality: 0.8) {
            data.append("--\(boundary)\r\n".data(using: .utf8)!)
            data.append("Content-Disposition: form-data; name=\"image\"; filename=\"image.jpg\"\r\n".data(using: .utf8)!)
            data.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
            data.append(imageData)
            data.append("\r\n".data(using: .utf8)!)
        }

        // Video
        if let videoURL = selectedVideoURL,
           let videoData = try? Data(contentsOf: videoURL) {
            data.append("--\(boundary)\r\n".data(using: .utf8)!)
            data.append("Content-Disposition: form-data; name=\"video\"; filename=\"video.mov\"\r\n".data(using: .utf8)!)
            data.append("Content-Type: video/quicktime\r\n\r\n".data(using: .utf8)!)
            data.append(videoData)
            data.append("\r\n".data(using: .utf8)!)
        }

        data.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = data

        isLoading = true
        errorMessage = ""

        URLSession.shared.dataTask(with: request) { responseData, response, error in
            DispatchQueue.main.async {
                isLoading = false

                if let error = error {
                    errorMessage = "Error: \(error.localizedDescription)"
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse else {
                    errorMessage = "Invalid response"
                    return
                }

                if (200...299).contains(httpResponse.statusCode) {
                    // Successfully posted
                    postText = ""
                    selectedImage = nil
                    selectedVideoURL = nil
                    errorMessage = ""
                } else {
                    errorMessage = "Post failed (status: \(httpResponse.statusCode))"
                }
            }
        }.resume()
    }

}


struct CreateContent_Previews: PreviewProvider {
    static var previews: some View {
        CreateContentView()
    }
}

import PhotosUI

struct MediaPicker: UIViewControllerRepresentable {
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: MediaPicker

        init(parent: MediaPicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {

            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }

            if let mediaURL = info[.mediaURL] as? URL {
                parent.selectedVideoURL = mediaURL
            }

            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }

    @Binding var selectedImage: UIImage?
    @Binding var selectedVideoURL: URL?
    var mediaTypes: [String]

    func makeCoordinator() -> Coordinator {
        return Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.mediaTypes = mediaTypes // ["public.image"] or ["public.movie"]
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
}


