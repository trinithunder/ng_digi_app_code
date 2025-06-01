//
//  VideoAudioMerger.swift
//  NGDigital
//
//  Created by Marlon on 6/1/25.
//

import AVFoundation

struct VideoAudioMerger {
    static func merge(videoURL: URL, with audioURL: URL, outputURL: URL, completion: @escaping (Result<URL, Error>) -> Void) {
        let mixComposition = AVMutableComposition()
        
        // Add video track
        let videoAsset = AVAsset(url: videoURL)
        guard let videoTrack = videoAsset.tracks(withMediaType: .video).first else {
            completion(.failure(NSError(domain: "No video track", code: -1, userInfo: nil)))
            return
        }

        let videoTimeRange = CMTimeRange(start: .zero, duration: videoAsset.duration)
        let videoCompositionTrack = mixComposition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)

        try? videoCompositionTrack?.insertTimeRange(videoTimeRange, of: videoTrack, at: .zero)

        // Add original video audio track (optional)
        if let originalAudioTrack = videoAsset.tracks(withMediaType: .audio).first {
            let originalAudioTrackComposition = mixComposition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
            try? originalAudioTrackComposition?.insertTimeRange(videoTimeRange, of: originalAudioTrack, at: .zero)
        }

        // Add selected music track
        let audioAsset = AVAsset(url: audioURL)
        if let musicTrack = audioAsset.tracks(withMediaType: .audio).first {
            let musicCompositionTrack = mixComposition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
            try? musicCompositionTrack?.insertTimeRange(videoTimeRange, of: musicTrack, at: .zero)
        }

        // Export
        guard let exporter = AVAssetExportSession(asset: mixComposition, presetName: AVAssetExportPresetHighestQuality) else {
            completion(.failure(NSError(domain: "Export failed", code: -2, userInfo: nil)))
            return
        }

        exporter.outputURL = outputURL
        exporter.outputFileType = .mov
        exporter.shouldOptimizeForNetworkUse = true

        exporter.exportAsynchronously {
            switch exporter.status {
            case .completed:
                completion(.success(outputURL))
            case .failed, .cancelled:
                completion(.failure(exporter.error ?? NSError(domain: "Unknown export error", code: -3, userInfo: nil)))
            default: break
            }
        }
    }
}

