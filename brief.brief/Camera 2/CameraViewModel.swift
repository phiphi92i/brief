//
//  CameraViewModel.swift
//  brief.brief
//
//  Created by Philippe Tchinda on 13/07/2023.
//
// CameraViewModel.swift

import CoreImage
import AVFoundation
import UIKit

class CameraViewModel: NSObject, ObservableObject {
  @Published var frame: CGImage?
  @Published var error: Error?
  @Published var takenImage: UIImage?
  @Published var takenVideoURL: URL?

  private let cameraManager = CameraManager.shared
    
  private let frameManager = CameraFrameManager.shared

  override init() {
      super.init()
      self.setupSubscriptions()
  }

    func setupSubscriptions() {
        frameManager.$current
            .receive(on: RunLoop.main)
            .compactMap { buffer -> CGImage? in
                guard let unwrappedBuffer = buffer else {
                    return nil
                }
                return createCGImage(from: unwrappedBuffer)
            }
            .assign(to: &$frame)
        
        cameraManager.$error
            .receive(on: RunLoop.main)
            .map { $0 }
            .assign(to: &$error)
    }


    
    func takePic() {
        CameraManager.shared.onTakePhoto(self)
    }
    
    func resetTakenImage() {
        takenImage = nil
        takenVideoURL = nil
    }
        
    
    func startSession() {
        cameraManager.configure() // Assuming this starts the camera session
    }

    func stopSession() {
        cameraManager.stopSessionRunning()
    }

    func resetCameraToLiveFeed() {
        // Reset the stored takenImage and takenVideoURL
        self.resetTakenImage()
        
        // Reconfigure the camera to show the live feed
        self.configureCamera()
    }
    
    func addTextToImage(text: String, at position: CGPoint, to image: UIImage) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: image.size)
        let img = renderer.image { ctx in
            image.draw(at: CGPoint.zero)
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center
            let attrs = [NSAttributedString.Key.font: UIFont(name: "HelveticaNeue-Thin", size: 24)!, NSAttributedString.Key.foregroundColor: UIColor.white, NSAttributedString.Key.paragraphStyle: paragraphStyle]
            text.draw(with: CGRect(x: position.x, y: position.y, width: image.size.width, height: 100), options: .usesLineFragmentOrigin, attributes: attrs, context: nil)
        }
        return img
    }


    
    
    func onVideoFinishedRecording(firstFrame: UIImage, videoURL: URL) {
        self.takenVideoURL = videoURL
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.2) {
            self.takenImage = firstFrame
        }
    }
    
}




extension CameraViewModel: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if error != nil {
            print("did err out")
            return
        }
        
        guard let imageData = photo.fileDataRepresentation() else {
            print("no pic data")
            return
        }
        
        let newUIImage = UIImage(data: imageData)!

        if CameraManager.shared.frontCameraActive {
            self.takenImage =  UIImage(cgImage: newUIImage.cgImage!, scale: newUIImage.scale, orientation: .leftMirrored)
        } else {
            self.takenImage = newUIImage
        }
        
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.1) {
            CameraManager.shared.stopSessionRunning()
        }
    }
}




extension CameraViewModel {
    func toggleCamera() {
        cameraManager.toggleFrontCamera()
    }
    
    func configureCamera() {
        cameraManager.configure()
    }
}
