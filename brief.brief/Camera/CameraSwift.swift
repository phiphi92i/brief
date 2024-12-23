//
//  CameraManager.swift
//  brief.brief
//
//  Created by Philippe Tchinda on 22/09/2023.
//

import Foundation
import Combine
import AVFoundation
import Photos
import UIKit
import SwiftUI

//  MARK: Class Camera Service, handles setup of AVFoundation needed for a basic camera app.
public struct Photo: Identifiable, Equatable {
    public var id: String
    public var originalData: Data
    
    public init(id: String = UUID().uuidString, originalData: Data) {
        self.id = id
        self.originalData = originalData
    }
}

public struct AlertError {
    public var title: String = ""
    public var message: String = ""
    public var primaryButtonTitle = "Accept"
    public var secondaryButtonTitle: String?
    public var primaryAction: (() -> ())?
    public var secondaryAction: (() -> ())?
    
    public init(title: String = "", message: String = "", primaryButtonTitle: String = "Accept", secondaryButtonTitle: String? = nil, primaryAction: (() -> ())? = nil, secondaryAction: (() -> ())? = nil) {
        self.title = title
        self.message = message
        self.primaryAction = primaryAction
        self.primaryButtonTitle = primaryButtonTitle
        self.secondaryAction = secondaryAction
    }
}

enum SessionSetupResult {
    case success
    case notAuthorized
    case configurationFailed
}

public class CameraService: NSObject, ObservableObject, Identifiable {
    typealias PhotoCaptureSessionID = String
    
    //    MARK: Observed Properties UI must react to
    
    @Published public var flashMode: AVCaptureDevice.FlashMode = .off
    @Published public var shouldShowAlertView = false
    @Published public var shouldShowSpinner = false
    
    @Published public var willCapturePhoto = false
    @Published public var isCameraButtonDisabled = false
    @Published public var isCameraUnavailable = false
    @Published public var photo: Photo?
    @Published var capturedPhotoData: Data? = nil
    // Inside CameraService
    var backCameraInput: AVCaptureDeviceInput?
    var frontCameraInput: AVCaptureDeviceInput?
    var isDoubleCaptureModeEnabled: Bool = false

    
    @Published var error: CameraError?
//    @Published var flashActive = false
    @Published var frontCameraActive = false
    @Published var isUltraWideCamera = false
    @Published var hasDualWideCamera = false
    @Published var isRecordingVideo = false
    @Published var zoomFactor = 1.0
    @Published var frontBackCameraModeActive = false
//    let session = AVCaptureSession()
    let videoOutput = AVCaptureVideoDataOutput()
    let audioOutput = AVCaptureAudioDataOutput()
    var status = Status.unconfigured
//    private let sessionQueue = DispatchQueue(label: "com.nibble.SessionQ")
//    private let photoOutput = AVCapturePhotoOutput()
    private let metadataOutput = AVCaptureMetadataOutput()
//    private var videoDeviceInput: AVCaptureDeviceInput?
    private var audioDeviceInput: AVCaptureDeviceInput?
    private var videoRecordingTimer: Timer?
    var timeLeft: Int?
    var videoWriter: AVAssetWriter?
    var videoWriterInput: AVAssetWriterInput?
    var audioWriterInput: AVAssetWriterInput?
    var videoWriterSessionAtSourceTime: CMTime?
    var videoFirstFrameImage: UIImage?
    var cameraNotVisible = false
    var videoCompletionCall: ((_ firstFrame: UIImage, _ videoURL: URL) -> Void)?

    @Published var secondCapturedPhoto: UIImage? = nil
    
    @Published public var secondPhoto: Photo?

    
    //    MARK: Alert properties
    public var alertError: AlertError = AlertError()
    
    // MARK: Session Management Properties
    
    public let session = AVCaptureSession()
    weak var delegate:  CameraViewModel?
    
    var isSessionRunning = false
    var isConfigured = false
    var setupResult: SessionSetupResult = .success
    
    // Communicate with the session and other session objects on this queue.
    private let sessionQueue = DispatchQueue(label: "com.brief.brief")

    @objc dynamic var videoDeviceInput: AVCaptureDeviceInput!
    
    // MARK: Device Configuration Properties
    let videoDeviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera, .builtInDualCamera, .builtInTrueDepthCamera], mediaType: .video, position: .unspecified)
    
    // MARK: Capturing Photos
    
    let photoOutput = AVCapturePhotoOutput()
    
    var inProgressPhotoCaptureDelegates = [Int64: PhotoCaptureProcessor]()
    
    // MARK: KVO and Notifications Properties
    
    var keyValueObservations = [NSKeyValueObservation]()
    
    var isUsingUltraWideCamera: Bool = false

       // Threshold zoom factor for switching cameras
       let thresholdScale: CGFloat = 1.5
    
    //    MARK: Init
    
    override public init() {
        super.init()
        
    checkPermissions()

        // Disable the UI. Enable the UI later, if and only if the session starts running.
        DispatchQueue.main.async {
            self.isCameraButtonDisabled = true
            self.isCameraUnavailable = true
        }
    }
    
    enum Status {
        case unconfigured
        case configured
        case unauthorized
        case failed
    }
    

    func configureInBackground() {
        DispatchQueue.global(qos: .background).async {
            self.configure()
        }
    }
    
    func configure() {
        print("Configure function called")
        checkPermissions()
        sessionQueue.async {
            print("Asynchronously configuring capture session")
            self.configureCaptureSession()
            print("Starting session")
            self.session.startRunning()
        }
    }

    
    
    func resetCameraSession() {
        print("Reset camera session function called")
        // Disable the XMark button to prevent user interaction during the reset process
        DispatchQueue.main.async {
            print("Disabling camera button")
            self.isCameraButtonDisabled = true
        }

        sessionQueue.async {
            print("Stopping running session")
            self.session.stopRunning()

            // Remove existing inputs and outputs
            print("Removing existing inputs and outputs")
            self.session.inputs.forEach { input in
                self.session.removeInput(input)
            }
            self.session.outputs.forEach { output in
                self.session.removeOutput(output)
            }

            // Reconfigure session
            print("Reconfiguring session")
            self.configureSession()

            // Add the input, output, videoOutput, and audioOutput on a background thread
            DispatchQueue.global(qos: .background).async {
                print("Adding inputs and outputs on background thread")
                if !self.session.inputs.contains(self.videoDeviceInput) {
                    self.session.addInput(self.videoDeviceInput)
                }

                // Remove existing photoOutput instance if it exists
                self.session.outputs.forEach { output in
                    if let photoOutput = output as? AVCapturePhotoOutput {
                        self.session.removeOutput(photoOutput)
                    }
                }

                // Add the photo output
                self.session.addOutput(self.photoOutput)

                // Check if the video output is already in the session before adding it
                if !self.session.outputs.contains(self.videoOutput) {
                    self.session.addOutput(self.videoOutput)
                }

                // Check if the audio output is already in the session before adding it
                if !self.session.outputs.contains(self.audioOutput) {
                    self.session.addOutput(self.audioOutput)
                }

                print("Starting session")
                self.session.startRunning()

                // Enable the UI and update it on the main thread after the reset process is complete
                DispatchQueue.main.async {
                    print("Enabling camera button")
                    self.isCameraButtonDisabled = false
                }
            }
        }
    }


    
    
    func configureSession() {
        print("Configure session called cs")
        sessionQueue.async {
            print("Beginning session configuration cs")
            self.session.beginConfiguration()
            
            // Setup the video input
            guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .unspecified),
                  let videoDeviceInput = try? AVCaptureDeviceInput(device: videoDevice),
                  self.session.canAddInput(videoDeviceInput) else {
                print("Could not create video device input.cs ")
                self.session.commitConfiguration()
                return
            }
            print("Adding video device input cs")
            self.session.addInput(videoDeviceInput)
            self.videoDeviceInput = videoDeviceInput
            
            // Setup the photo output
            let photoOutput = AVCapturePhotoOutput()
            if self.session.canAddOutput(photoOutput) {
                print("Adding photo output cs ")
                self.session.addOutput(photoOutput)
                photoOutput.isHighResolutionCaptureEnabled = true
            } else {
                print("Could not add photo output to the session. cs")
                self.session.commitConfiguration()
                return
            }
            
            print("Committing session configuration cs ")
            self.session.commitConfiguration()
            
            // Start the session on a background thread after a brief delay to ensure everything is set up
            DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 0.1) {
                print("Starting session cs")
                self.session.startRunning()
            }
        }
    }

    func startSessionSafely() {
        sessionQueue.async {
            if !self.session.isRunning {
                self.session.startRunning()
            }
        }
    }


    
    //        MARK: Checks for permisions, setup obeservers and starts running session
    public func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .notDetermined:
            sessionQueue.suspend()
            AVCaptureDevice.requestAccess(for: .video) { authorized in
                if !authorized {
                    self.status = .unauthorized
                    self.set(error: .deniedAuthorization)
                }
                self.sessionQueue.resume()
            }
        case .restricted:
            status = .unauthorized
            set(error: .restrictedAuthorization)
        case .denied:
            status = .unauthorized
            set(error: .deniedAuthorization)
        case .authorized:
            break
        @unknown default:
            status = .unauthorized
            set(error: .unknownAuthorization)
        }
    }
    
    private func configCamera(_ camera: AVCaptureDevice?, _ config: @escaping (AVCaptureDevice) -> ()) {
        guard let device = camera else { return }
        
        sessionQueue.async { [device] in
            do {
                try device.lockForConfiguration()
            } catch {
                return
            }
            
            config(device)
            
            device.unlockForConfiguration()
        }
    }
    
    //  MARK: Session Managment
    
    // Call this on the session queue.
    /// - Tag: ConfigureSession
    private func configureCaptureSession() {
        if #available(iOS 13.0, *) {
            if AVCaptureDevice.default(.builtInDualWideCamera, for: .video, position: .back) != nil {
//                DispatchQueue.main.async {
                    self.hasDualWideCamera = true
                    self.zoomFactor = 2
                
//                }
            }
        }
        
        guard status == .unconfigured else {
            return
        }
        
        session.beginConfiguration()
        defer {
            session.commitConfiguration()
        }
        
        session.sessionPreset = AVCaptureSession.Preset.photo
        session.automaticallyConfiguresApplicationAudioSession = false
        
        let device = AVCaptureDevice.default(
            self.hasDualWideCamera ? .builtInDualWideCamera : .builtInWideAngleCamera,
            for: .video,
            position: .back)
        
        guard let camera = device else {
            set(error: .cameraUnavailable)
            status = .failed
            return
        }
                
        configCamera(camera) { device in
            device.videoZoomFactor = self.zoomFactor
            device.whiteBalanceMode = .continuousAutoWhiteBalance
        }
        
        do {
            let cameraInput = try AVCaptureDeviceInput(device: camera)
            if session.canAddInput(cameraInput) {
                session.addInput(cameraInput)
                self.videoDeviceInput = cameraInput
            } else {
                set(error: .cannotAddInput)
                status = .failed
                return
            }
        } catch {
            set(error: .createCaptureInput(error))
            status = .failed
            return
        }
        
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
            
            photoOutput.isHighResolutionCaptureEnabled = true
            
            videoOutput.videoSettings =
            [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
            let videoConnection = videoOutput.connection(with: .video)
            videoConnection?.videoOrientation = .portrait
            
            if (videoConnection?.isVideoStabilizationSupported)! {
                videoConnection?.preferredVideoStabilizationMode = AVCaptureVideoStabilizationMode.cinematic
            }
            
            session.addOutput(photoOutput)
            session.addOutput(metadataOutput)
            
            metadataOutput.metadataObjectTypes = [.qr]
        } else {
            set(error: .cannotAddOutput)
            status = .failed
            return
        }
        
        status = .configured
    }

    
    
    func handleSetupFailure(_ result: SessionSetupResult) {
        switch result {
        case .notAuthorized:
            // Handle not authorized case
            break
        case .configurationFailed:
            // Handle configuration failed case
            break
        default:
            break
        }
    }
    
    private func resumeInterruptedSession() {
        sessionQueue.async {
            /*
             The session might fail to start running, for example, if a phone or FaceTime call is still
             using audio or video. This failure is communicated by the session posting a
             runtime error notification. To avoid repeatedly failing to start the session,
             only try to restart the session in the error handler if you aren't
             trying to resume the session.
             */
            self.session.startRunning()
            self.isSessionRunning = self.session.isRunning
            if !self.session.isRunning {
                DispatchQueue.main.async {
                    self.alertError = AlertError(title: "Camera Error", message: "Unable to resume camera", primaryButtonTitle: "Accept", secondaryButtonTitle: nil, primaryAction: nil, secondaryAction: nil)
                    self.shouldShowAlertView = true
                    self.isCameraUnavailable = true
                    self.isCameraButtonDisabled = true
                }
            } else {
                DispatchQueue.main.async {
                    self.isCameraUnavailable = false
                    self.isCameraButtonDisabled = false
                }
            }
        }
    }
    
    //  MARK: Device Configuration
    

    public func focus(with focusMode: AVCaptureDevice.FocusMode, exposureMode: AVCaptureDevice.ExposureMode, at devicePoint: CGPoint, monitorSubjectAreaChange: Bool) {
        sessionQueue.async {
            guard let device = self.videoDeviceInput?.device else { return }
            do {
                try device.lockForConfiguration()
                
                /*
                 Setting (focus/exposure)PointOfInterest alone does not initiate a (focus/exposure) operation.
                 Call set(Focus/Exposure)Mode() to apply the new point of interest.
                 */
                if device.isFocusPointOfInterestSupported && device.isFocusModeSupported(focusMode) {
                    device.focusPointOfInterest = devicePoint
                    device.focusMode = focusMode
                }
                
                if device.isExposurePointOfInterestSupported && device.isExposureModeSupported(exposureMode) {
                    device.exposurePointOfInterest = devicePoint
                    device.exposureMode = exposureMode
                }
                
                device.isSubjectAreaChangeMonitoringEnabled = monitorSubjectAreaChange
                device.unlockForConfiguration()
            } catch {
                print("Could not lock device for configuration: \(error)")
            }
        }
    }
    
    
    public func focus(at focusPoint: CGPoint){
        self.configure()
        sessionQueue.async {
            guard let device = self.videoDeviceInput?.device else {
                return
            }
            do {
                try device.lockForConfiguration()
                if device.isFocusPointOfInterestSupported {
                    device.focusPointOfInterest = focusPoint
                    device.exposurePointOfInterest = focusPoint
                    device.exposureMode = .autoExpose
                    device.focusMode = .continuousAutoFocus
                    device.whiteBalanceMode = .continuousAutoWhiteBalance
                    device.unlockForConfiguration()
                }
            }
            catch {
                print(error.localizedDescription)
            }
        }
    }
    
    
//    deinit {
//        stop() // Ensure session is stopped and resources are released
//    }
    
    @objc public func stop(completion: (() -> ())? = nil) {
        sessionQueue.async {
            if self.isSessionRunning {
                if self.setupResult == .success {
                    self.session.stopRunning()
                    self.isSessionRunning = false//self.session.isRunning
                    print("CAMERA STOPPED")
                    self.removeObservers()
                    
                    if !self.session.isRunning {
                        DispatchQueue.main.async {
                            self.isCameraButtonDisabled = true
                            self.isCameraUnavailable = true
                            completion?()
                        }
                    }
                }
            }
        }
    }
    
    @objc public func start() {
        sessionQueue.async {
            if !self.isSessionRunning && self.isConfigured {
                switch self.setupResult {
                case .success:
                    // Only setup observers and start the session if setup succeeded.
                    self.addObservers()
                    self.session.startRunning()
                    print("CAMERA RUNNING")
                    self.isSessionRunning = self.session.isRunning
                    
                    if self.session.isRunning {
                        DispatchQueue.main.async {
                            self.isCameraButtonDisabled = false
                            self.isCameraUnavailable = false
                        }
                    }
                    
                case .notAuthorized:
                    print("Application not authorized to use camera")
                    DispatchQueue.main.async {
                        self.isCameraButtonDisabled = true
                        self.isCameraUnavailable = true
                    }
                    
                case .configurationFailed:
                    DispatchQueue.main.async {
                        self.alertError = AlertError(title: "Camera Error", message: "Camera configuration failed. Either your device camera is not available or other application is using it", primaryButtonTitle: "Accept", secondaryButtonTitle: nil, primaryAction: nil, secondaryAction: nil)
                        self.shouldShowAlertView = true
                        self.isCameraButtonDisabled = true
                        self.isCameraUnavailable = true
                    }
                }
            }
        }
    }

    func stopSessionRunning() {
        self.session.stopRunning()
    }
    
//    func toggleFlash() {
//        flashActive.toggle()
//    }
    
    
    private func set(error: CameraError?) {
        DispatchQueue.main.async {
            self.error = error
        }
    }
    
//    ______
    
    func toggleFrontCamera() {
        print("Before toggle: \(frontCameraActive)")
        frontCameraActive.toggle()
        print("After toggle: \(frontCameraActive)")

        
        guard status == .configured else {
            return
        }
        
        // Set the flag to capture the second photo after toggling the camera
//        delegate?.shouldCaptureSecondPhotoAfterToggle = true

        
        session.beginConfiguration()
        defer {
            session.commitConfiguration()
        }
        
        session.sessionPreset = AVCaptureSession.Preset.photo
        
        if let videoDeviceInput = videoDeviceInput {
            session.removeInput(videoDeviceInput)
        }
        
        let device = AVCaptureDevice.default(
            (self.hasDualWideCamera && !frontCameraActive) ? .builtInDualWideCamera : .builtInWideAngleCamera,
            for: .video,
            position: frontCameraActive ? .front : .back)
        guard let camera = device else {
            set(error: .cameraUnavailable)
            status = .failed
            return
        }
        
        do {
            let cameraInput = try AVCaptureDeviceInput(device: camera)
            if session.canAddInput(cameraInput) {
                session.addInput(cameraInput)
                self.videoDeviceInput = cameraInput
            } else {
                set(error: .cannotAddInput)
                status = .failed
                return
            }
        } catch {
            set(error: .createCaptureInput(error))
            status = .failed
            return
        }
        
        configCamera(camera) { device in
            if self.hasDualWideCamera && !self.frontCameraActive {
//                DispatchQueue.main.async {
                    self.zoomFactor = 2.0
//                }
            } else {
//                DispatchQueue.main.async {
                    self.zoomFactor = 1.0
//                }
            }
            device.videoZoomFactor = self.zoomFactor
            device.whiteBalanceMode = .continuousAutoWhiteBalance
        }
    }
    
    public func toggleZoomFactor() {
        guard status == .configured else {
            return
        }
        
        sessionQueue.async {
            guard let device = self.videoDeviceInput?.device else {
                return
            }
            
            if self.zoomFactor == 2.0 {
                self.zoomFactor = 1.0
            } else {
                self.zoomFactor = 2.0
            }

            self.configCamera(device) { device in
                device.ramp(toVideoZoomFactor: self.zoomFactor, withRate: 6)
            }
        }
    }
    
    @objc public func onPinch(recognizer: UIPinchGestureRecognizer) {
        guard status == .configured else {
            return
        }
        
        sessionQueue.async {
            guard let device = self.videoDeviceInput?.device else {
                return
            }
            
            switch recognizer.state {
            case .began:
                recognizer.scale = device.videoZoomFactor
            case .changed:
                let scale = recognizer.scale
                if scale >= 0.5 {
//                    DispatchQueue.main.async {
                        self.zoomFactor = round(scale)
//                    }
                    }
                do {
                    try device.lockForConfiguration()
                    device.videoZoomFactor = max(device.minAvailableVideoZoomFactor, min(scale, device.maxAvailableVideoZoomFactor))
                    device.unlockForConfiguration()
                }
                catch {
                    print(error)
                }
            default:
                break
            }
        }
    }
    
    
    func toggleFrontBackCameraMode() {
        frontBackCameraModeActive.toggle()
    }
    
    
    
    
    public func reset() {
        // Stop the session if it's running
        if isSessionRunning {
            session.stopRunning()
            isSessionRunning = false
        }

        // Clear internal states
        isConfigured = false
        setupResult = .success
        shouldShowSpinner = false
        shouldShowAlertView = false
        isCameraButtonDisabled = true
        isCameraUnavailable = true
        photo = nil
        secondPhoto = nil

        // Remove all inputs and outputs
        for input in session.inputs {
            session.removeInput(input)
        }

        for output in session.outputs {
            session.removeOutput(output)
        }

        // Remove observers
        removeObservers()

        // Clear delegates
        inProgressPhotoCaptureDelegates.removeAll()

        for (_, captureProcessor) in self.inProgressPhotoCaptureDelegates {
            captureProcessor.resetPhotoData()
        }

        // Reconfigure the session
        configureInBackground()
    }


    

    

    func setFlashMode(_ mode: AVCaptureDevice.FlashMode) {
        self.flashMode = mode
    }
    
    //    MARK: Capture Photo
    
    /// - Tag: CapturePhoto
    public func capturePhoto() {
        /*
         Retrieve the video preview layer's video orientation on the main queue before
         entering the session queue. This to ensures that UI elements are accessed on
         the main thread and session configuration is done on the session queue.
         */
        
        if self.setupResult != .configurationFailed {
            let videoPreviewLayerOrientation: AVCaptureVideoOrientation = .portrait
            self.isCameraButtonDisabled = true
            
            sessionQueue.async {
                if let photoOutputConnection = self.photoOutput.connection(with: .video) {
                    photoOutputConnection.videoOrientation = videoPreviewLayerOrientation
                }
                var photoSettings = AVCapturePhotoSettings()
                
                
                // Only enable high-resolution photos if it's supported
                    if self.photoOutput.isHighResolutionCaptureEnabled {
                        photoSettings.isHighResolutionPhotoEnabled = true
                    }
                
                // Capture HEIF photos when supported. Enable according to user settings and high-resolution photos.
                if  self.photoOutput.availablePhotoCodecTypes.contains(.hevc) {
                    photoSettings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
                }
                
                if self.videoDeviceInput.device.isFlashAvailable {
                    photoSettings.flashMode = self.flashMode
                }
                
                photoSettings.isHighResolutionPhotoEnabled = true
                if !photoSettings.__availablePreviewPhotoPixelFormatTypes.isEmpty {
                    photoSettings.previewPhotoFormat = [kCVPixelBufferPixelFormatTypeKey as String: photoSettings.__availablePreviewPhotoPixelFormatTypes.first!]
                }
                
                photoSettings.photoQualityPrioritization = .speed
                
                let photoCaptureProcessor = PhotoCaptureProcessor(with: photoSettings, delegate: self.delegate, willCapturePhotoAnimation: {
                            // Flash the screen to signal that AVCam took a photo.
                            DispatchQueue.main.async {
                                self.willCapturePhoto.toggle()
                            }
                        }, completionHandler: { (photoCaptureProcessor) in
                            // When the capture is complete, remove a reference to the photo capture delegate so it can be deallocated.
                            if let data = photoCaptureProcessor.photoData {
                                
                                // Check if the camera used is the front camera
                                if self.videoDeviceInput.device.position == .front {
                                    if let capturedImage = UIImage(data: data) {
                                        UIGraphicsBeginImageContextWithOptions(capturedImage.size, false, capturedImage.scale)
                                        let context = UIGraphicsGetCurrentContext()!
                                        context.translateBy(x: capturedImage.size.width, y: 0)
                                        context.scaleBy(x: -1, y: 1)
                                        capturedImage.draw(in: CGRect(x: 0, y: 0, width: capturedImage.size.width, height: capturedImage.size.height))
                                        if let flippedImage = UIGraphicsGetImageFromCurrentImageContext() {
                                            UIGraphicsEndImageContext()
                                            if let flippedImageData = flippedImage.jpegData(compressionQuality: 1.0) {
                                                self.photo = Photo(originalData: flippedImageData)
                                            }
                                        }
                                    }
                                } else {
                                    self.photo = Photo(originalData: data)
                                }
                                
                                print("passing photo")
                            } else {
                                print("No photo data")
                            }
                            
                            self.isCameraButtonDisabled = false
                            
                            self.sessionQueue.async {
                                self.inProgressPhotoCaptureDelegates[photoCaptureProcessor.requestedPhotoSettings.uniqueID] = nil
                            }
                            
                        }, photoProcessingHandler: { animate in
                            // Animates a spinner while photo is processing
                            if animate {
                                self.shouldShowSpinner = true
                            } else {
                                self.shouldShowSpinner = false
                            }
                        })
                        
                        // The photo output holds a weak reference to the photo capture delegate and stores it in an array to maintain a strong reference.
                        self.inProgressPhotoCaptureDelegates[photoCaptureProcessor.requestedPhotoSettings.uniqueID] = photoCaptureProcessor
                        self.photoOutput.capturePhoto(with: photoSettings, delegate: photoCaptureProcessor)
                
                    }
        }
    }
    
    
    /// - Tag: CapturePhoto
    public func doublecapturePhoto() {
           /*
            Retrieve the video preview layer's video orientation on the main queue before
            entering the session queue. This ensures that UI elements are accessed on
            the main thread and session configuration is done on the session queue.
            */
           
           if self.setupResult != .configurationFailed {
               let videoPreviewLayerOrientation: AVCaptureVideoOrientation = .portrait
               self.isCameraButtonDisabled = true
               
               sessionQueue.async {
                   if let photoOutputConnection = self.photoOutput.connection(with: .video) {
                       photoOutputConnection.videoOrientation = videoPreviewLayerOrientation
                   }
                   var photoSettings = AVCapturePhotoSettings()
                   
                   
                   // Only enable high-resolution photos if it's supported
                   if self.photoOutput.isHighResolutionCaptureEnabled {
                       photoSettings.isHighResolutionPhotoEnabled = true
                   }
                   
                   // Capture HEIF photos when supported. Enable according to user settings and high-resolution photos.
                   if  self.photoOutput.availablePhotoCodecTypes.contains(.hevc) {
                       photoSettings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
                   }
                   
                   if self.videoDeviceInput.device.isFlashAvailable {
                       photoSettings.flashMode = self.flashMode
                   }
                   
                   photoSettings.isHighResolutionPhotoEnabled = true
                   if !photoSettings.__availablePreviewPhotoPixelFormatTypes.isEmpty {
                       photoSettings.previewPhotoFormat = [kCVPixelBufferPixelFormatTypeKey as String: photoSettings.__availablePreviewPhotoPixelFormatTypes.first!]
                   }
                   
                   photoSettings.photoQualityPrioritization = .speed
                   
                   let photoCaptureProcessor = PhotoCaptureProcessor(with: photoSettings, delegate: self.delegate, willCapturePhotoAnimation: {
                       // Flash the screen to signal that AVCam took a photo.
                       DispatchQueue.main.async {
                           self.willCapturePhoto.toggle()
                       }
                   }, completionHandler: { (photoCaptureProcessor) in
                       // When the capture is complete, remove a reference to the photo capture delegate so it can be deallocated.
                       if let data = photoCaptureProcessor.photoData {
                           
                           // Check if the camera used is the front camera
                           if self.videoDeviceInput.device.position == .front {
                               if let secondCapturedPhoto = UIImage(data: data) {
                                   UIGraphicsBeginImageContextWithOptions(secondCapturedPhoto.size, false, secondCapturedPhoto.scale)
                                   let context = UIGraphicsGetCurrentContext()!
                                   context.translateBy(x: secondCapturedPhoto.size.width, y: 0)
                                   context.scaleBy(x: -1, y: 1)
                                   secondCapturedPhoto.draw(in: CGRect(x: 0, y: 0, width: secondCapturedPhoto.size.width, height: secondCapturedPhoto.size.height))
                                   if let flippedImage = UIGraphicsGetImageFromCurrentImageContext() {
                                       UIGraphicsEndImageContext()
                                       if let flippedImageData = flippedImage.jpegData(compressionQuality: 1.0) {
                                           self.secondPhoto = Photo(originalData: flippedImageData)
                                       }
                                   }
                               }
                           } else {
                               self.secondPhoto = Photo(originalData: data)
                           }
                           
                           print("passing photo")
                       } else {
                           print("No photo data")
                       }
                       
                       self.isCameraButtonDisabled = false
                       
                       self.sessionQueue.async {
                           self.inProgressPhotoCaptureDelegates[photoCaptureProcessor.requestedPhotoSettings.uniqueID] = nil
                       }
                       
                   }, photoProcessingHandler: { animate in
                       // Animates a spinner while photo is processing
                       if animate {
                           self.shouldShowSpinner = true
                       } else {
                           self.shouldShowSpinner = false
                       }
                   })
                   
                   // The photo output holds a weak reference to the photo capture delegate and stores it in an array to maintain a strong reference.
                   self.inProgressPhotoCaptureDelegates[photoCaptureProcessor.requestedPhotoSettings.uniqueID] = photoCaptureProcessor
                   self.photoOutput.capturePhoto(with: photoSettings, delegate: photoCaptureProcessor)
               }
           }
       }


    
    //  MARK: KVO & Observers
    
    /// - Tag: ObserveInterruption
    private func addObservers() {
        let systemPressureStateObservation = observe(\.videoDeviceInput.device.systemPressureState, options: .new) { _, change in
            guard let systemPressureState = change.newValue else { return }
            self.setRecommendedFrameRateRangeForPressureState(systemPressureState: systemPressureState)
        }
        keyValueObservations.append(systemPressureStateObservation)
        
        //        NotificationCenter.default.addObserver(self, selector: #selector(self.onOrientationChange), name: UIDevice.orientationDidChangeNotification, object: nil)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(subjectAreaDidChange),
                                               name: .AVCaptureDeviceSubjectAreaDidChange,
                                               object: videoDeviceInput.device)
        
        NotificationCenter.default.addObserver(self, selector: #selector(uiRequestedNewFocusArea), name: .init(rawValue: "UserDidRequestNewFocusPoint"), object: nil)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(sessionRuntimeError),
                                               name: .AVCaptureSessionRuntimeError,
                                               object: session)
        
        /*
         A session can only run when the app is full screen. It will be interrupted
         in a multi-app layout, introduced in iOS 9, see also the documentation of
         AVCaptureSessionInterruptionReason. Add observers to handle these session
         interruptions and show a preview is paused message. See the documentation
         of AVCaptureSessionWasInterruptedNotification for other interruption reasons.
         */
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(sessionWasInterrupted),
                                               name: .AVCaptureSessionWasInterrupted,
                                               object: session)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(sessionInterruptionEnded),
                                               name: .AVCaptureSessionInterruptionEnded,
                                               object: session)
    }
    
    private func removeObservers() {
        NotificationCenter.default.removeObserver(self)
        
        for keyValueObservation in keyValueObservations {
            keyValueObservation.invalidate()
        }
        keyValueObservations.removeAll()
    }
    
    @objc private func uiRequestedNewFocusArea(notification: NSNotification) {
        guard let userInfo = notification.userInfo as? [String: Any], let devicePoint = userInfo["devicePoint"] as? CGPoint else { return }
        self.focus(at: devicePoint)
    }
    
    @objc
    private func subjectAreaDidChange(notification: NSNotification) {
        let devicePoint = CGPoint(x: 0.5, y: 0.5)
        focus(with: .continuousAutoFocus, exposureMode: .continuousAutoExposure, at: devicePoint, monitorSubjectAreaChange: false)
    }
    
    /// - Tag: HandleRuntimeError
    @objc
    private func sessionRuntimeError(notification: NSNotification) {
        guard let error = notification.userInfo?[AVCaptureSessionErrorKey] as? AVError else { return }
        
        print("Capture session runtime error: \(error)")
        // If media services were reset, and the last start succeeded, restart the session.
        if error.code == .mediaServicesWereReset {
            sessionQueue.async {
                if self.isSessionRunning {
                    self.session.startRunning()
                    self.isSessionRunning = self.session.isRunning
                }
            }
        }
    }
    
    /// - Tag: HandleSystemPressure
    private func setRecommendedFrameRateRangeForPressureState(systemPressureState: AVCaptureDevice.SystemPressureState) {
        /*
         The frame rates used here are only for demonstration purposes.
         Your frame rate throttling may be different depending on your app's camera configuration.
         */
        let pressureLevel = systemPressureState.level
        if pressureLevel == .serious || pressureLevel == .critical {
            do {
                try self.videoDeviceInput.device.lockForConfiguration()
                print("WARNING: Reached elevated system pressure level: \(pressureLevel). Throttling frame rate.")
                self.videoDeviceInput.device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 20)
                self.videoDeviceInput.device.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 15)
                self.videoDeviceInput.device.unlockForConfiguration()
            } catch {
                print("Could not lock device for configuration: \(error)")
            }
        } else if pressureLevel == .shutdown {
            print("Session stopped running due to shutdown system pressure level.")
        }
    }
    
    /// - Tag: HandleInterruption
    @objc
    private func sessionWasInterrupted(notification: NSNotification) {
        /*
         In some scenarios you want to enable the user to resume the session.
         For example, if music playback is initiated from Control Center while
         using Campus, then the user can let Campus resume
         the session running, which will stop music playback. Note that stopping
         music playback in Control Center will not automatically resume the session.
         Also note that it's not always possible to resume, see `resumeInterruptedSession(_:)`.
         */
        DispatchQueue.main.async {
            self.isCameraUnavailable = true
        }
        
        if let userInfoValue = notification.userInfo?[AVCaptureSessionInterruptionReasonKey] as AnyObject?,
           let reasonIntegerValue = userInfoValue.integerValue,
           let reason = AVCaptureSession.InterruptionReason(rawValue: reasonIntegerValue) {
            print("Capture session was interrupted with reason \(reason)")
            
            if reason == .audioDeviceInUseByAnotherClient || reason == .videoDeviceInUseByAnotherClient {
                print("Session stopped running due to video devies in use by another client.")
            } else if reason == .videoDeviceNotAvailableWithMultipleForegroundApps {
                // Fade-in a label to inform the user that the camera is unavailable.
                print("Session stopped running due to video devies is not available with multiple foreground apps.")
            } else if reason == .videoDeviceNotAvailableDueToSystemPressure {
                print("Session stopped running due to shutdown system pressure level.")
            }
        }
    }
    
    @objc
    private func sessionInterruptionEnded(notification: NSNotification) {
        print("Capture session interruption ended")
        DispatchQueue.main.async {
            self.isCameraUnavailable = false
        }
    }
}

func checkPermissions() -> Bool {
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            return true
        } else {
            return false
        }
    }

enum CameraError: Error {
    case cameraUnavailable
    case cannotAddInput
    case cannotAddOutput
    case createCaptureInput(Error)
    case deniedAuthorization
    case restrictedAuthorization
    case unknownAuthorization
}

extension CameraError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .cameraUnavailable:
            return "Camera unavailable"
        case .cannotAddInput:
            return "Cannot add capture input to session"
        case .cannotAddOutput:
            return "Cannot add video output to session"
        case .createCaptureInput(let error):
            return "Creating capture input for camera: \(error.localizedDescription)"
        case .deniedAuthorization:
            return "Allow access to camera to take photos"
        case .restrictedAuthorization:
            return "Attempting to access a restricted capture device"
        case .unknownAuthorization:
            return "Unknown authorization status for capture device"
        }
    }
}

