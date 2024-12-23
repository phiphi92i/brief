//  CameraPreview.swift
//  brief.brief
//
//  Created by Philippe Tchinda on 23/09/2023.
//


import UIKit
import AVFoundation
import SwiftUI
import Combine


public struct CameraPreview: UIViewRepresentable {
    // Hold a reference to the CameraService
    public let cameraService: CameraService
    
    public init(cameraService: CameraService) {
        self.cameraService = cameraService
    }
    
    public func makeUIView(context: Context) -> VideoPreviewView {
        cameraService.reset() // Call the resetCameraSession() function

        let viewFinder = VideoPreviewView(cameraService: cameraService)
        viewFinder.backgroundColor = .black
        viewFinder.videoPreviewLayer.cornerRadius = 0
        viewFinder.videoPreviewLayer.session = cameraService.session
        viewFinder.videoPreviewLayer.connection?.videoOrientation = .portrait
        viewFinder.videoPreviewLayer.videoGravity = .resizeAspectFill
        return viewFinder
    }
    
    public func updateUIView(_ uiView: VideoPreviewView, context: Context) {
        // You can update the UI here, if needed
    }
    
    public class VideoPreviewView: UIView {
        public override class var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }
        
        var videoPreviewLayer: AVCaptureVideoPreviewLayer {
            return layer as! AVCaptureVideoPreviewLayer
        }
        
        let cameraService: CameraService
        
        public init(cameraService: CameraService) {
            self.cameraService = cameraService
            super.init(frame: .zero)
            setupView()
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func setupView() {
            let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(focusAndExposeTap(gestureRecognizer:)))
            self.addGestureRecognizer(tapGestureRecognizer)
        }
        
        @objc func focusAndExposeTap(gestureRecognizer: UITapGestureRecognizer) {
            let devicePoint = videoPreviewLayer.captureDevicePointConverted(fromLayerPoint: gestureRecognizer.location(in: gestureRecognizer.view))
            cameraService.focus(at: devicePoint)  // Call the focus function from CameraService
        }
    }
}
