//
//  FrameManager.swift
//  brief.brief
//
//  Created by Philippe Tchinda on 05/08/2023.
//

import AVFoundation
import UIKit

class CameraFrameManager: NSObject, ObservableObject {
    static let shared = CameraFrameManager()
    
//    @Published var emotionPredictor = EmotionDetector(sharedImage: BMSharedImage())
//    @Published var counter = 0
    
    @Published var current: CVPixelBuffer?
    
//    @Published var feeling: String?
    
    let videoOutputQueue = DispatchQueue(
        label: "com.nibble.VideoOutputQ",
        qos: .userInitiated,
        attributes: [],
        autoreleaseFrequency: .workItem)
    
    let audioOutputQueue = DispatchQueue(
        label: "com.nibble.AudioOutputQ",
        qos: .userInitiated,
        attributes: [],
        autoreleaseFrequency: .workItem)
    
    private override init() {
        super.init()
        CameraManager.shared.set(self, queue: videoOutputQueue)
        CameraManager.shared.setAudioDelegate(self, queue: audioOutputQueue)
    }
}

func shouldWriteToVideo() -> Bool {
    return CameraManager.shared.isRecordingVideo && CameraManager.shared.videoWriter != nil && CameraManager.shared.videoWriter?.status == .writing
}



func createCGImage(from pixelBuffer: CVPixelBuffer) -> CGImage? {
    let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
    let context = CIContext(options: nil)
    return context.createCGImage(ciImage, from: CGRect(x: 0, y: 0, width: CVPixelBufferGetWidth(pixelBuffer), height: CVPixelBufferGetHeight(pixelBuffer)))
}



extension CameraFrameManager: AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        if CameraManager.shared.cameraNotVisible {
            return
        }
        
        let writeToVideo = shouldWriteToVideo()
        
        if writeToVideo, CameraManager.shared.videoWriterSessionAtSourceTime == nil {
            // start writing
            CameraManager.shared.videoWriterSessionAtSourceTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            CameraManager.shared.videoWriter?.startSession(atSourceTime: CameraManager.shared.videoWriterSessionAtSourceTime!)
        }
        
        if output == CameraManager.shared.videoOutput {
            connection.videoOrientation = .portrait
        }
        
        if writeToVideo, output == CameraManager.shared.videoOutput, CameraManager.shared.videoWriterInput?.isReadyForMoreMediaData == true {
            CameraManager.shared.videoWriterInput!.append(sampleBuffer)
        } else if writeToVideo, output == CameraManager.shared.audioOutput, CameraManager.shared.audioWriterInput?.isReadyForMoreMediaData == true {
            CameraManager.shared.audioWriterInput!.append(sampleBuffer)
        }
            
        if let buffer = sampleBuffer.imageBuffer {
            DispatchQueue.main.async {
                self.current = buffer
            }
            
            if writeToVideo && CameraManager.shared.videoFirstFrameImage == nil {
                if let cgImage = createCGImage(from: buffer) {
                    CameraManager.shared.videoFirstFrameImage = UIImage(cgImage: cgImage, scale: 1, orientation: .up)
                }
            }
        }

        
//        if let pixelBuffer = getPixelBufferFromSampleBuffer(buffer: sampleBuffer) {
//            if (counter % 5 == 0) {
//                emotionPredictor.predict(src: pixelBuffer)
//            }
//            counter += 1
//        }
    }
}
