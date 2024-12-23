//
//  CameraModel.swift
//  brief.brief
//
//  Created by Philippe Tchinda on 13/07/2023.
//

import AVFoundation
import UIKit

class CameraManager: NSObject, ObservableObject {
    
    @Published var error: CameraError?
    @Published var flashActive = false
    @Published var frontCameraActive = true
    @Published var isUltraWideCamera = false
    @Published var hasDualWideCamera = false
    @Published var isRecordingVideo = false
    @Published var zoomFactor = 1.0
    let session = AVCaptureSession()
    let videoOutput = AVCaptureVideoDataOutput()
    let audioOutput = AVCaptureAudioDataOutput()
    var status = Status.unconfigured
    private let sessionQueue = DispatchQueue(label: "com.nibble.SessionQ")
    private let photoOutput = AVCapturePhotoOutput()
    private let metadataOutput = AVCaptureMetadataOutput()
    
    private var videoDeviceInput: AVCaptureDeviceInput?
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
    
    enum Status {
        case unconfigured
        case configured
        case unauthorized
        case failed
    }
    
    static let shared = CameraManager()
    
    func configure() {
        checkPermissions()
        sessionQueue.async {
            self.prepareAudioSession()
            self.configureCaptureSession()
            self.session.startRunning()
        }
    }
    
    private func set(error: CameraError?) {
        DispatchQueue.main.async {
            self.error = error
        }
    }
    
    
    private func checkPermissions() {
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
    
    private func configureCaptureSession() {
        
        guard status == .unconfigured else {
            return
        }
        
        session.beginConfiguration()
        defer {
            session.commitConfiguration()
        }
        
        let wasFrontCameraActive = UserDefaults.standard.bool(forKey: "wasFrontCameraActive")
                frontCameraActive = wasFrontCameraActive
        
        session.sessionPreset = AVCaptureSession.Preset.photo
        session.automaticallyConfiguresApplicationAudioSession = false
        
        let device = AVCaptureDevice.default(
            self.hasDualWideCamera ? .builtInDualWideCamera : .builtInWideAngleCamera,
            for: .video,
            position: frontCameraActive ? .front : .back)
        
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
            videoOutput.videoSettings =
            [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
            let videoConnection = videoOutput.connection(with: .video)
            videoConnection?.videoOrientation = .portrait
            
            if (videoConnection?.isVideoStabilizationSupported)! {
                videoConnection?.preferredVideoStabilizationMode = AVCaptureVideoStabilizationMode.cinematic
            }
                    
            //For frontCamera settings to capture mirror image
            if frontCameraActive {
                videoConnection?.automaticallyAdjustsVideoMirroring = false
                videoConnection?.isVideoMirrored = true
            } else {
                videoConnection?.automaticallyAdjustsVideoMirroring = true
            }
            
            session.addOutput(photoOutput)
            session.addOutput(metadataOutput)
            session.addOutput(audioOutput)
            
            metadataOutput.metadataObjectTypes = [.qr]
        } else {
            set(error: .cannotAddOutput)
            status = .failed
            return
        }
        
        if AVCaptureDevice.authorizationStatus(for: .audio) == .authorized {
            setupAudioInput()
        }
        
        status = .configured
    }
    
    
    func setupAudioInput() {
        let device = AVCaptureDevice.default(for: .audio)
        
        guard let mic = device else {
            print("no device")
            return
        }
        
        do {
            let micInput = try AVCaptureDeviceInput(device: mic)
            if session.canAddInput(micInput) {
                session.addInput(micInput)
                self.audioDeviceInput = micInput
            } else {
                print("mic input fail")
                return
            }
        } catch {
            return
        }
    }
    
    func onTakePhoto(
        _ delegate: AVCapturePhotoCaptureDelegate
    ) {
        DispatchQueue.global(qos: .background).async {
            let settings = AVCapturePhotoSettings()
            
            if self.flashActive {
                settings.flashMode = .on
            } else {
                settings.flashMode = .off
            }
            
            self.photoOutput.capturePhoto(with: settings, delegate: delegate)
        }
    }
    
    func getVideoFileUrl() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let fileUrl = paths[0].appendingPathComponent("video_recording.mp4")
        return fileUrl
    }
    
    func setupVideoWriter() {
        do {
            let outputFileLocation = getVideoFileUrl()
            try? FileManager.default.removeItem(at: outputFileLocation)
            videoWriter = try AVAssetWriter(outputURL: outputFileLocation, fileType: AVFileType.mov)

            let outputPreset = AVOutputSettingsAssistant(preset: .preset1280x720)
            
            var videoSettings = outputPreset?.videoSettings
            
//            switch vid width and height (for portrait mode)
            if videoSettings != nil {
                let tempWidth = videoSettings!["AVVideoWidthKey"]
                videoSettings!["AVVideoWidthKey"] = videoSettings!["AVVideoHeightKey"]
                videoSettings!["AVVideoHeightKey"] = tempWidth
////
                videoSettings!["AVVideoScalingModeKey"] = "AVVideoScalingModeResizeAspectFill"
            }
                
            // add video input
            videoWriterInput = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: videoSettings)

            guard let videoWriter = videoWriter, let videoWriterInput = videoWriterInput else {
                return
            }
            
            videoWriterInput.expectsMediaDataInRealTime = true

            if videoWriter.canAdd(videoWriterInput) {
                videoWriter.add(videoWriterInput)
            } else {
            }

            // add audio input
            audioWriterInput = AVAssetWriterInput(mediaType: AVMediaType.audio, outputSettings: outputPreset?.audioSettings)

            guard let audioWriterInput = audioWriterInput else {
                return
            }
            
            audioWriterInput.expectsMediaDataInRealTime = true

            if videoWriter.canAdd(audioWriterInput) {
                videoWriter.add(audioWriterInput)
            }

            videoWriter.startWriting()
        } catch let error {
            debugPrint(error.localizedDescription)
        }
    }
    
    func startRecordingVideo(completionCall: @escaping (_ firstFrame: UIImage, _ videoURL: URL) -> Void) {
        if AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined {
            sessionQueue.suspend()
            AVCaptureDevice.requestAccess(for: .audio) { authorized in
                if authorized {
//                    if authorized, setup audio input
                    self.session.beginConfiguration()
                    defer {
                        self.session.commitConfiguration()
                    }
                    self.setupAudioInput()
                }
                self.sessionQueue.resume()
            }
            return
        }
        
        
        self.isRecordingVideo = true
        
        
        setupVideoWriter()
        
//        timer to stop recording after 30sec
        videoRecordingTimer = Timer.scheduledTimer(timeInterval: 30, target: self, selector: #selector(stopRecordingVideo), userInfo: nil, repeats: false)
        
//        also disable front back mode if recording video
        //frontBackCameraModeActive = false
        
        videoCompletionCall = completionCall
    }
    
    @objc func stopRecordingVideo() {
        if isRecordingVideo != true {
            return
        }
        
        if self.hasDualWideCamera && !self.frontCameraActive {
            self.zoomFactor = 2.0
        } else {
            self.zoomFactor = 1.0
        }
        
        self.isRecordingVideo = false
        
        self.videoWriterSessionAtSourceTime = nil
        
        if let videoRecordingTimer = self.videoRecordingTimer {
            videoRecordingTimer.invalidate()
            self.videoRecordingTimer = nil
        }
        
        videoWriterInput!.markAsFinished()
        videoWriter!.finishWriting { [weak self] in
            self!.videoWriterSessionAtSourceTime = nil
        }
        
        if let videoCompletionCall = videoCompletionCall, let videoFirstFrameImage = videoFirstFrameImage {
//            TODO: investigate if there's a better way to get the first frame image than in the frame delegate
            videoCompletionCall(videoFirstFrameImage, getVideoFileUrl())
        }
        videoFirstFrameImage = nil
    }
    
    func stopSessionRunning() {
        self.session.stopRunning()
        self.deactivateAudioSession()
    }
    
    func toggleFlash() {
        flashActive.toggle()
    }
    
    func toggleFrontCamera() {
        frontCameraActive.toggle()
        
        guard status == .configured else {
            return
        }
        
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
        
        let videoConnection = videoOutput.connection(with: .video)
        videoConnection?.videoOrientation = .portrait
        
        if (videoConnection?.isVideoStabilizationSupported)! {
            videoConnection?.preferredVideoStabilizationMode = AVCaptureVideoStabilizationMode.cinematic
        }
                
        //For frontCamera settings to capture mirror image
        if frontCameraActive {
            videoConnection?.automaticallyAdjustsVideoMirroring = false
            videoConnection?.isVideoMirrored = true
        } else {
            videoConnection?.automaticallyAdjustsVideoMirroring = true
        }
        
        configCamera(camera) { device in
            if self.hasDualWideCamera && !self.frontCameraActive {
                self.zoomFactor = 2.0
            } else {
                self.zoomFactor = 1.0
            }
            device.videoZoomFactor = self.zoomFactor
            device.whiteBalanceMode = .continuousAutoWhiteBalance
        }
        
        UserDefaults.standard.setValue(frontCameraActive, forKey: "wasFrontCameraActive")
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
                    self.zoomFactor = round(scale)
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
    
    public func zoomWithOneFingerWhileRecording(scale: CGFloat) {
        guard status == .configured else {
            return
        }
        
        sessionQueue.async {
            guard let device = self.videoDeviceInput?.device else {
                return
            }
            
            if scale >= 0.5 {
                self.zoomFactor = round(scale)
            }
            do {
                try device.lockForConfiguration()
                device.videoZoomFactor = max(device.minAvailableVideoZoomFactor, min(scale, device.maxAvailableVideoZoomFactor))
                device.unlockForConfiguration()
            }
            catch {
                print(error)
            }
        }
    }
    
    public func focus(at focusPoint: CGPoint){
        CameraManager.shared.configure()
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
    
    private func prepareAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord, options: [.mixWithOthers, .defaultToSpeaker, .allowBluetoothA2DP, .allowAirPlay])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Could not set audio category")
        }
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleAudioSessionInterruption),
                                               name: AVAudioSession.interruptionNotification,
                                               object: nil)
    }
    
    private func deactivateAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            print("Could not deactivate audio session")
        }
        
        NotificationCenter.default.removeObserver(self,
                                                  name: AVAudioSession.interruptionNotification,
                                                  object: nil)
    }
    
    @objc private func handleAudioSessionInterruption(notification: Notification) {
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        if type == .ended, let optionsValue = info[AVAudioSessionInterruptionOptionKey] as? UInt {
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            if options.contains(.shouldResume) {
                do {
                    try AVAudioSession.sharedInstance().setActive(true)
                } catch {
                    print("Could not reactivate audio session")
                }
            }
        }
    }
    
    func set(
        _ delegate: AVCaptureVideoDataOutputSampleBufferDelegate,
        queue: DispatchQueue
    ) {
        sessionQueue.async {
            self.videoOutput.setSampleBufferDelegate(delegate, queue: queue)
        }
    }
    
    func setAudioDelegate(
        _ delegate: AVCaptureAudioDataOutputSampleBufferDelegate,
        queue: DispatchQueue
    ) {
        sessionQueue.async {
            self.audioOutput.setSampleBufferDelegate(delegate, queue: queue)
        }
    }
    
    func set(
        _ delegate: AVCaptureMetadataOutputObjectsDelegate,
        queue: DispatchQueue
    ) {
        sessionQueue.async {
            self.metadataOutput.setMetadataObjectsDelegate(delegate, queue: queue)
        }
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
