//
//  MediaEditingContext.swift
//  NGDigital
//
//  Created by Marlon on 6/1/25.
//

import SwiftUI
import UIKit
import AVFoundation
import AVKit

enum MediaType {
    case image(UIImage)
    case video(URL)
}

enum FilterOption: String, CaseIterable, Identifiable {
    case none, sepia, noir, mono, vivid

    var id: String { self.rawValue }

    var displayName: String {
        switch self {
            case .none: return "Original"
            case .sepia: return "Sepia"
            case .noir: return "Noir"
            case .mono: return "Mono"
            case .vivid: return "Vivid"
        }
    }
}


struct MediaEditingContext {
    var mediaType: MediaType
    var filters: [FilterOption] = []
    var cropRect: CGRect? = nil
    var rotationAngle: CGFloat = 0.0
    var isEdited: Bool {
        return cropRect != nil || rotationAngle != 0.0 || !filters.isEmpty
    }
}

class MediaEditorViewModel: ObservableObject {
    @Published var context: MediaEditingContext

    init(context: MediaEditingContext) {
        self.context = context
    }

    func apply(filter: FilterOption) {
        context.filters.append(filter)
    }

    func rotate(by angle: CGFloat) {
        context.rotationAngle += angle
    }

    func crop(to rect: CGRect) {
        context.cropRect = rect
    }

    func renderFinalImage() -> UIImage? {
        guard case .image(let image) = context.mediaType else { return nil }

        var editedImage = image

        // Apply rotation (simple)
        if context.rotationAngle != 0 {
            editedImage = editedImage.rotated(by: context.rotationAngle)
        }

        // Apply filters
        for filter in context.filters {
            editedImage = editedImage.applyFilter(filter)
        }

        // Apply crop
        if let cropRect = context.cropRect {
            editedImage = editedImage.cropped(to: cropRect)
        }

        return editedImage
    }
}

extension UIImage {
    func rotated(by degrees: CGFloat) -> UIImage {
        let radians = degrees * .pi / 180
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            context.cgContext.translateBy(x: size.width / 2, y: size.height / 2)
            context.cgContext.rotate(by: radians)
            draw(in: CGRect(x: -size.width/2, y: -size.height/2, width: size.width, height: size.height))
        }
    }

    func applyFilter(_ filter: FilterOption) -> UIImage {
        guard filter != .none else { return self }

        let ciImage = CIImage(image: self)
        let filterName: String

        switch filter {
            case .sepia: filterName = "CISepiaTone"
            case .noir: filterName = "CIPhotoEffectNoir"
            case .mono: filterName = "CIPhotoEffectMono"
            case .vivid: filterName = "CIColorControls"
            default: return self
        }

        guard let filter = CIFilter(name: filterName) else { return self }
        filter.setValue(ciImage, forKey: kCIInputImageKey)

        if filterName == "CIColorControls" {
            filter.setValue(1.2, forKey: kCIInputSaturationKey)
            filter.setValue(0.8, forKey: kCIInputBrightnessKey)
            filter.setValue(1.1, forKey: kCIInputContrastKey)
        }

        guard let output = filter.outputImage,
              let cgimg = CIContext().createCGImage(output, from: output.extent) else { return self }

        return UIImage(cgImage: cgimg)
    }

    func cropped(to rect: CGRect) -> UIImage {
        guard let cgImage = cgImage?.cropping(to: rect) else { return self }
        return UIImage(cgImage: cgImage)
    }
}

struct MediaEditorView: View {
    @ObservedObject var viewModel: MediaEditorViewModel

    var body: some View {
        VStack {
            if case .image(let image) = viewModel.context.mediaType {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 300)
            }

            Picker("Filter", selection: Binding(
                get: { viewModel.context.filters.last ?? .none },
                set: { viewModel.apply(filter: $0) }
            )) {
                ForEach(FilterOption.allCases) { filter in
                    Text(filter.displayName).tag(filter)
                }
            }
            .pickerStyle(.segmented)

            HStack {
                Button("Rotate Left") {
                    viewModel.rotate(by: -90)
                }
                Button("Rotate Right") {
                    viewModel.rotate(by: 90)
                }
            }

            Button("Crop to Center") {
                // Simple fixed crop
                viewModel.crop(to: CGRect(x: 50, y: 50, width: 200, height: 200))
            }

            if let finalImage = viewModel.renderFinalImage() {
                Image(uiImage: finalImage)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 150)
            }
        }
        .padding()
    }
}

import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

struct ImageEditorView: View {
    @Binding var image: UIImage
    @Environment(\.presentationMode) var presentationMode

    // Editing state
    @State private var currentImage: UIImage
    @State private var rotationAngle: Angle = .zero
    @State private var scale: CGFloat = 1.0

    // Cropping state
    @State private var cropRect: CGRect? = nil
    @State private var dragStart: CGPoint? = nil
    @State private var dragCurrent: CGPoint? = nil

    // Filtering
    @State private var filterType: FilterType = .none
    @State private var intensity: Double = 0.5

    // Core Image context
    let context = CIContext()

    init(image: Binding<UIImage>) {
        self._image = image
        self._currentImage = State(initialValue: image.wrappedValue)
    }

    var body: some View {
        VStack {
            Spacer()

            GeometryReader { geo in
                ZStack {
                    Image(uiImage: currentImage)
                        .resizable()
                        .scaledToFit()
                        .rotationEffect(rotationAngle)
                        .scaleEffect(scale)
                        .frame(maxWidth: geo.size.width, maxHeight: geo.size.height)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    if dragStart == nil {
                                        dragStart = value.location
                                    }
                                    dragCurrent = value.location
                                    cropRect = rectFromPoints(dragStart!, dragCurrent!)
                                }
                                .onEnded { _ in
                                    dragStart = nil
                                    dragCurrent = nil
                                }
                        )

                    if let cropRect = cropRect {
                        Rectangle()
                            .path(in: cropRect)
                            .stroke(Color.red, lineWidth: 2)
                            .background(Color.red.opacity(0.2).clipShape(Rectangle().path(in: cropRect)))
                    }
                }
            }
            .frame(height: 400)

            // Controls
            Form {
                Section("Transform") {
                    HStack {
                        Button("Rotate Left") { rotate(by: -90) }
                        Spacer()
                        Button("Rotate Right") { rotate(by: 90) }
                    }
                    Slider(value: $scale, in: 0.5...2.0) {
                        Text("Scale")
                    }
                }

                Section("Filter") {
                    Picker("Filter", selection: $filterType) {
                        ForEach(FilterType.allCases, id: \.self) { filter in
                            Text(filter.rawValue.capitalized)
                        }
                    }
                    .pickerStyle(.segmented)

                    if filterType != .none {
                        Slider(value: $intensity, in: 0...1) {
                            Text("Intensity")
                        }
                    }
                }
            }

            Spacer()

            HStack {
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
                Spacer()
                Button("Apply") {
                    applyEdits()
                    if let cropRect = cropRect {
                        cropImage(rect: cropRect)
                    }
                    presentationMode.wrappedValue.dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .onChange(of: filterType) { _ in
            applyEdits()
        }
        .onChange(of: intensity) { _ in
            applyEdits()
        }
    }

    private func rectFromPoints(_ p1: CGPoint, _ p2: CGPoint) -> CGRect {
        CGRect(x: min(p1.x, p2.x),
               y: min(p1.y, p2.y),
               width: abs(p1.x - p2.x),
               height: abs(p1.y - p2.y))
    }

    private func rotate(by degrees: Double) {
        rotationAngle += .degrees(degrees)
        applyEdits()
    }

    private func applyEdits() {
        guard let ciImage = CIImage(image: image) else { return }

        var filtered = ciImage

        switch filterType {
        case .none:
            filtered = ciImage
        case .sepia:
            let sepia = CIFilter.sepiaTone()
            sepia.inputImage = ciImage
            sepia.intensity = Float(intensity)
            filtered = sepia.outputImage ?? ciImage
        case .mono:
            let mono = CIFilter.photoEffectMono()
            mono.inputImage = ciImage
            filtered = mono.outputImage ?? ciImage
        case .blur:
            let blur = CIFilter.gaussianBlur()
            blur.inputImage = ciImage
            blur.radius = Float(intensity * 10)
            filtered = blur.outputImage ?? ciImage
        case .contrast:
            let contrast = CIFilter.colorControls()
            contrast.inputImage = ciImage
            contrast.contrast = Float(intensity * 2)
            filtered = contrast.outputImage ?? ciImage
        }

        guard let cgImage = context.createCGImage(filtered, from: filtered.extent) else {
            return
        }
        var processedImage = UIImage(cgImage: cgImage)

        processedImage = processedImage.rotated(by: rotationAngle)
        processedImage = processedImage.scaled(by: scale)

        currentImage = processedImage
    }

    private func cropImage(rect: CGRect) {
        guard let cgImage = currentImage.cgImage else { return }

        // Adjust cropping rectangle to image scale and orientation
        let scaleX = CGFloat(cgImage.width) / UIScreen.main.bounds.width
        let scaleY = CGFloat(cgImage.height) / 400 // height of image frame

        let adjustedRect = CGRect(x: rect.origin.x * scaleX,
                                  y: rect.origin.y * scaleY,
                                  width: rect.size.width * scaleX,
                                  height: rect.size.height * scaleY)

        guard let croppedCGImage = cgImage.cropping(to: adjustedRect) else { return }

        currentImage = UIImage(cgImage: croppedCGImage)
        image = currentImage
        cropRect = nil
    }
}

enum FilterType: String, CaseIterable {
    case none
    case sepia
    case mono
    case blur
    case contrast
}

extension UIImage {
    func rotated(by angle: Angle) -> UIImage {
        let radians = CGFloat(angle.radians)
        let newSize = CGRect(origin: CGPoint.zero, size: size)
            .applying(CGAffineTransform(rotationAngle: radians))
            .integral.size

        UIGraphicsBeginImageContextWithOptions(newSize, false, scale)
        guard let context = UIGraphicsGetCurrentContext() else { return self }

        let origin = CGPoint(x: newSize.width / 2, y: newSize.height / 2)

        context.translateBy(x: origin.x, y: origin.y)
        context.rotate(by: radians)

        draw(in: CGRect(x: -size.width / 2,
                        y: -size.height / 2,
                        width: size.width,
                        height: size.height))

        let rotatedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return rotatedImage ?? self
    }

    func scaled(by scale: CGFloat) -> UIImage {
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        UIGraphicsBeginImageContextWithOptions(newSize, false, self.scale)
        draw(in: CGRect(origin: .zero, size: newSize))
        let scaledImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return scaledImage ?? self
    }
}


struct VideoEditorView: View {
    @Binding var videoURL: URL
    @Environment(\.presentationMode) var presentationMode

    @State private var player = AVPlayer()
    @State private var startTime: Double = 0
    @State private var endTime: Double = 10
    @State private var duration: Double = 0

    var body: some View {
        VStack {
            VideoPlayer(player: player)
                .frame(height: 300)
                .onAppear {
                    player = AVPlayer(url: videoURL)
                    player.play()
                    fetchDuration()
                }

            Text("Trim Video")
                .font(.headline)

            HStack {
                Text("Start: \(String(format: "%.1f", startTime))s")
                Slider(value: $startTime, in: 0...(endTime - 1), step: 0.1)
            }

            HStack {
                Text("End: \(String(format: "%.1f", endTime))s")
                Slider(value: $endTime, in: (startTime + 1)...duration, step: 0.1)
            }

            HStack {
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
                Spacer()
                Button("Apply Trim") {
                    trimVideo()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .padding()
    }

    private func fetchDuration() {
        let asset = AVAsset(url: videoURL)
        duration = CMTimeGetSeconds(asset.duration)
        endTime = duration
    }

    private func trimVideo() {
        let asset = AVAsset(url: videoURL)
        let start = CMTime(seconds: startTime, preferredTimescale: 600)
        let end = CMTime(seconds: endTime, preferredTimescale: 600)
        let timeRange = CMTimeRange(start: start, end: end)

        let composition = AVMutableComposition()
        guard
            let track = asset.tracks(withMediaType: .video).first,
            let compTrack = composition.addMutableTrack(withMediaType: .video,
                                                        preferredTrackID: kCMPersistentTrackID_Invalid)
        else { return }

        do {
            try compTrack.insertTimeRange(timeRange, of: track, at: .zero)
        } catch {
            print("Failed to insert time range: \(error)")
            return
        }

        // Export the trimmed video
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("trimmed.mov")

        if FileManager.default.fileExists(atPath: outputURL.path) {
            try? FileManager.default.removeItem(at: outputURL)
        }

        guard let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            print("Could not create export session")
            return
        }

        exporter.outputURL = outputURL
        exporter.outputFileType = .mov
        exporter.timeRange = CMTimeRange(start: .zero, duration: end - start)

        exporter.exportAsynchronously {
            DispatchQueue.main.async {
                if exporter.status == .completed {
                    videoURL = outputURL
                    presentationMode.wrappedValue.dismiss()
                } else {
                    print("Failed to export: \(exporter.error?.localizedDescription ?? "Unknown error")")
                }
            }
        }
    }
}





