//
//  CameraViewModel.swift
//  brief.brief
//
//  Created by Philippe Tchinda on 22/09/2023.
//

    import CoreImage
    import AVFoundation
    import UIKit
    import Firebase
    import FirebaseFirestore
    import FirebaseStorage
    import FirebaseAuth
    import SDWebImageSwiftUI
    import Combine
    import SwiftUI
    import CoreGraphics
    import CoreImage.CIFilterBuiltins
    import CoreLocation




class CameraViewModel: NSObject, ObservableObject /*AVCapturePhotoCaptureDelegate*/ {
    
    @Published var frame: CIImage?
    @Published var error: Error?
    @Published var takenImage: UIImage?
    @Published var takenVideoURL: URL?
    @Published var isFlashActive = false  // Add this line to keep track of flash state
    @Published var profileImageUrl: String = ""
    @Published var username: String = ""
    @Published var distributionCircles: [String] = ["Tout mes amis"]
    @Published var selectedCircle = "Tout mes amis"
    var newPostPublisher = PassthroughSubject<UserPost, Never>()
    var cancellables = Set<AnyCancellable>()
    var frameSubject = PassthroughSubject<CIImage?, Never>()
    @Published var photo: Photo?  // Captured photo
    @Published var flashMode: AVCaptureDevice.FlashMode = .off
    @Published var isCameraActive = false  // Whether the camera session is active
    @ObservedObject var cameraService: CameraService
    var image: UIImage?
    @Published var showEditPhotoVC = false
    @Published var capturedImage: UIImage? = nil
    @Published var capturedPhoto: UIImage?
    var photoCaptureProcessor: PhotoCaptureProcessor?
    // Add these properties to your CameraViewModel class
    private var cachedProfileImageUrl: String? = nil
    private var cachedUsername: String? = nil
    private var lastFetchTime: Date? = nil
    @Published var containerHeight: CGFloat = 0
    @Published var temporaryPosts: [UserPost] = []
    //    @Published var imageUploadManager = ImageUploadManager()
    @Published var uploadProgress: Double = 0.0
    var feedViewModel: FeedViewModel?
    @Published var isLocationEnabled = false
    @Published var locationString = ""
    @Published var locationData: (latitude: Double, longitude: Double)? = nil
    @Published var isGlobal: Bool = false
    @Published var hasSecondaryImage: Bool = false
    @Published var takenSecondaryImage: UIImage?
    var shouldCaptureSecondPhotoAfterToggle = false
    @Published var secondCapturedPhoto: UIImage?
    @Published var secondPhoto: UIImage?  // Add this property
    
    @Published var isUploading: Bool = false // Add this line
    
    // Set isUploadingPost to true before starting the upload
    @Published var isUploadingPost: Bool = false
    
    
    init(cameraService: CameraService = CameraService(),feedViewModel: FeedViewModel? = nil) {
        self.cameraService = cameraService
        super.init()
        self.feedViewModel = feedViewModel
        
        cameraService.$photo
            .sink { [weak self] newPhoto in
                guard let self = self else { return }
                if let data = newPhoto?.originalData, let uiImage = UIImage(data: data) {
                    self.capturedPhoto = uiImage
                }
            }
            .store(in: &cancellables)
        
        
        cameraService.$secondPhoto
            .sink { [weak self] newSecondPhoto in
                guard let self = self else { return }
                if let data = newSecondPhoto?.originalData, let uiImage = UIImage(data: data) {
                    self.secondCapturedPhoto = uiImage
                }
            }
            .store(in: &cancellables)
        
        
        fetchProfileImageAndUsername()
        fetchDistributionCircles()
    }
    
    
    
    
    var takenPhoto: Photo? {
        didSet {
            // Do something with the new photo, maybe update the UI
        }
    }
    
    // In CameraViewModel
    //    func adjustCameraZoom(_ scale: CGFloat) {
    //        cameraService.switchCameraBasedOnZoom(scale: scale)
    //    }
    
    
    func startSession() {
        cameraService.checkPermissions()
        cameraService.configureInBackground()
    }
    
    func stopSession() {
        cameraService.stop()
    }
    
    
    
    
    //    func resetCamera() {
    //        cameraService.session.stopRunning()
    //        cameraService.session.beginConfiguration()
    //        cameraService.session.inputs.forEach { cameraService.session.removeInput($0) }
    //        cameraService.session.outputs.forEach { cameraService.session.removeOutput($0) }
    //        cameraService.session.commitConfiguration()
    //        cameraService.configureSession()
    //    }
    //    func reset() {
    //            cameraService.stop()
    //            cameraService.reset()
    //            cameraService.configure()
    //            cameraService.start()
    //            capturedPhoto = nil
    //            secondCapturedPhoto = nil
    //        }
    
    
    func resetCameraToLiveFeed() {
        // Stop the current session before reconfiguring
        cameraService.reset()
        // Reconfigure the camera to show the live feed
        self.startSession()
    }
    
    
    
    //    func takepic() {
    //        cameraService.onTakePhoto(self)
    //    }
    
    
    func resetCameraAfterPost() {
        cameraService.reset()
        startSession()  // Restart the camera session
    }
    
    
    //    func updateZoomLevel(to scale: CGFloat) {
    //        // Delegate to CameraService to handle the zoom
    //        cameraService.toggleZoomFactor()
    //    }
    
    func focusCamera(at point: CGPoint) {
        cameraService.focus(at: point)
    }
    
    
    func resetServices() {
        cameraService.reset()
        // Assuming photoCaptureProcessor is an instance variable
    }
    
    
    func changeCamera() {
        cameraService.toggleFrontCamera()
    }
    
    func resetTakenImage() {
        capturedImage = nil
        secondCapturedPhoto = nil
        takenVideoURL = nil
        capturedPhoto = nil // Add this line
        photo = nil // Add this line
        secondPhoto = nil // Add this line
        
    }
    
    func resetAndPhoto() {
        // Reset CameraService
        cameraService.reset()
        
        // Reset CaptureProcessor
        for (_, captureProcessor) in cameraService.inProgressPhotoCaptureDelegates {
            captureProcessor.resetPhotoData()
        }
        
        // Capture a new photo
    }
    
    //    func onReset() {
    //        resetAndPhoto()
    //
    ////        Haptics.play(.light)
    //
    //        cameraService.stopSessionRunning()
    //
    //        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.4) {
    //            self.cameraService.configureInBackground()
    //            self.cameraService.start()
    //        }
    //    }
    
    func onReset() {
        capturedImage = nil
        capturedPhoto = nil // Add this line
        
        secondCapturedPhoto = nil
        photo = nil // Add this line
        secondPhoto = nil // Add this line
        
        secondCapturedPhoto = nil
        for (_, captureProcessor) in cameraService.inProgressPhotoCaptureDelegates {
            captureProcessor.resetPhotoData()
        }
        cameraService.start() // Use the instance to call start
    }
    
    func resetCameraSession() {
        cameraService.resetCameraSession()
    }
    
    func onVideoFinishedRecording(firstFrame: UIImage, videoURL: URL) {
        self.takenImage = firstFrame
        self.takenVideoURL = videoURL
    }
    
    func capturePhoto() {
        cameraService.capturePhoto()
        //
        //        if cameraService.delegate?.shouldCaptureSecondPhotoAfterToggle == true {
        //            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
        //                self.cameraService.capturePhoto()
        //                self.cameraService.delegate?.shouldCaptureSecondPhotoAfterToggle = false
        //            }
        //        }
    }
    
    
    
    
    
    deinit {
        for cancellable in cancellables {
            cancellable.cancel()
            cancellables.forEach { $0.cancel() }
        }
    }
    
    func toggleLocationEnabled() {
        isLocationEnabled.toggle()
        if isLocationEnabled {
        } else {
            locationString = ""
        }
    }
    
    // Add this to use the locationString from LocationManager
    var currentLocationString: String {
        locationString
    }
    
    func setLocation(latitude: Double, longitude: Double) {
        self.locationData = (latitude, longitude)
        let location = CLLocation(latitude: latitude, longitude: longitude)
        // Start reverse geocoding immediately
        LocationManager.shared.reverseGeocodeLocation(location) { [weak self] address in
            DispatchQueue.main.async {
                self?.locationString = address
            }
        }
    }
    
    
    //    func mergeImages(_ firstImage: UIImage, _ secondImage: UIImage) -> UIImage {
    //        let renderer = UIGraphicsImageRenderer(size: CGSize(width: firstImage.size.width, height: firstImage.size.height + secondImage.size.height))
    //        return renderer.image { context in
    //            firstImage.draw(at: .zero)
    //            secondImage.draw(at: CGPoint(x: 0, y: firstImage.size.height))
    //        }
    //    }
    
    
    
    
    // Fetching the profile image and username
    func fetchProfileImageAndUsername() {
        guard let userID = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        
        db.collection("users").document(userID).getDocument { [weak self] (document, error) in
            guard let self = self else { return }
            if let error = error {
                print("Error getting document: \(error)")
            } else {
                let profileImageUrl = document?.data()?["profileImageUrl"] as? String ?? ""
                let username = document?.data()?["username"] as? String ?? ""
                
                self.cachedProfileImageUrl = profileImageUrl
                self.cachedUsername = username
                self.lastFetchTime = Date()
                
                self.profileImageUrl = profileImageUrl
                self.username = username
            }
        }
    }
    
    func fetchDistributionCircles() {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }
        
        Firestore.firestore().collection("distributionCircles")
            .whereField("creator_id", isEqualTo: currentUserID)
            .getDocuments { [weak self] (querySnapshot, error) in
                guard let self = self else { return }
                if let error = error {
                    print("Error fetching distribution circles: \(error.localizedDescription)")
                } else {
                    let circleNames = querySnapshot?.documents.compactMap { document -> String? in
                        (try? document.data(as: DistributionCircle.self))?.name
                    }
                    self.distributionCircles = ["Tout mes amis"] + (circleNames ?? [])
                }
            }
    }
    
    
    func retryPostUpload(at index: Int) {
        guard index < temporaryPosts.count else { return }
        let post = temporaryPosts[index]
        
        getImageData(from: post) { imageData in
            guard let imageData = imageData else {
                print("Unable to get image data for post at index \(index)")
                return
            }
            self.getImageData(from: post) { secondImageData in
                guard let secondImageData = secondImageData else {
                    print("Unable to get image data for post at index \(index)")
                    return
                }
                
                self.sendPost(imageData: imageData, secondImageData: secondImageData, postCaption: post.content, selectedCircle: post.distributionCircles.first ?? "Tout mes amis")
                    .sink(receiveCompletion: { completion in
                        switch completion {
                        case .failure(let error):
                            print("Retry failed with error: \(error)")
                        case .finished:
                            print("Retry succeeded")
                            self.temporaryPosts.remove(at: index)
                        }
                    }, receiveValue: { _ in })
                    .store(in: &self.cancellables)
            }
        }
    }
    
    
    func getImageData(from post: UserPost, completion: @escaping (Data?) -> Void) {
        guard let imageUrlString = post.images.first,
              let imageUrl = URL(string: imageUrlString) else {
            completion(nil)
            return
        }
        
        let storageRef = Storage.storage().reference(forURL: imageUrlString)
        storageRef.getData(maxSize: 10 * 1024 * 1024) { data, error in
            if let error = error {
                print("Error getting image data: \(error.localizedDescription)")
                completion(nil)
            } else {
                completion(data)
            }
        }
    }
    
    
    
    // Sending the post with imageData, postCaption, and selectedCircle as parameters.
    func sendPost(imageData: Data, secondImageData: Data?, postCaption: String, selectedCircle: String) -> AnyPublisher<Void, Error> {
        guard let userID = Auth.auth().currentUser?.uid else {
            return Fail(error: NSError(domain: "User not logged in", code: 0, userInfo: nil))
                .eraseToAnyPublisher()
        }
        
        let db = Firestore.firestore()
        let expiresAt = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        var distribution: [String] = selectedCircle == "Tout mes amis" ? ["all_friends"] : [selectedCircle]
        
        var data: [String: Any] = [
            "userID": userID,
            "username": self.username,
            "profileImageUrl": self.profileImageUrl,
            "timestamp": Timestamp(date: Date()),
            "expiresAt": Timestamp(date: expiresAt),
            "images": [],
            "content": postCaption,
            "likes": [],
            "distributionCircles": distribution,
            "isGlobalPost": isGlobal,
            "hasSecondaryImage": hasSecondaryImage
        ]
        
        if isLocationEnabled, let locationData = self.locationData {
            data["location"] = [
                "latitude": locationData.latitude,
                "longitude": locationData.longitude,
                "address": locationString
            ]
        }
        
        // Set isUploadingPost to true before starting the upload
        self.isUploadingPost = true
        
        return Future<Void, Error> { [weak self] promise in
            var newDocumentRef: DocumentReference? = nil
            newDocumentRef = db.collection("posts").addDocument(data: data) { error in
                if let error = error {
                    promise(.failure(error))
                    self?.isUploadingPost = false // Set isUploadingPost to false on failure
                    return
                }
                
                guard let documentID = newDocumentRef?.documentID else {
                    promise(.failure(NSError(domain: "Invalid document ID", code: 0, userInfo: nil)))
                    self?.isUploadingPost = false // Set isUploadingPost to false on failure
                    return
                }
                
                let tempPost = UserPost(id: documentID, content: postCaption, timestamp: Date(), expiresAt: expiresAt, userID: userID, username: self?.username ?? "", profileImageUrl: self?.profileImageUrl ?? "", distributionCircles: distribution, images: [], likes: [], isGlobalPost: self?.isGlobal ?? false, hasSecondaryImage: self?.hasSecondaryImage ?? false)
                
                DispatchQueue.main.async {
                    self?.feedViewModel?.posts.insert(tempPost, at: 0)
                }
                
                let storageRef = Storage.storage().reference().child("photos/\(UUID().uuidString).jpg")
                storageRef.putData(imageData, metadata: nil) { (metadata, error) in
                    if let error = error {
                        promise(.failure(error))
                        self?.isUploadingPost = false // Set isUploadingPost to false on failure
                        return
                    }
                    
                    storageRef.downloadURL { (url, error) in
                        if let error = error {
                            promise(.failure(error))
                            self?.isUploadingPost = false // Set isUploadingPost to false on failure
                            return
                        }
                        
                        guard let downloadURL = url else {
                            promise(.failure(NSError(domain: "Invalid download URL", code: 0, userInfo: nil)))
                            self?.isUploadingPost = false // Set isUploadingPost to false on failure
                            return
                        }
                        
                        var updatedImages: [String] = [downloadURL.absoluteString]
                        
                        // Upload the second image if it exists
                        if let secondImageData = secondImageData {
                            let secondStorageRef = Storage.storage().reference().child("photos/\(UUID().uuidString).jpg")
                            secondStorageRef.putData(secondImageData, metadata: nil) { (secondMetadata, secondError) in
                                if let secondError = secondError {
                                    promise(.failure(secondError))
                                    self?.isUploadingPost = false // Set isUploadingPost to false on failure
                                    return
                                }
                                
                                secondStorageRef.downloadURL { (secondURL, secondError) in
                                    if let secondError = secondError {
                                        promise(.failure(secondError))
                                        self?.isUploadingPost = false // Set isUploadingPost to false on failure
                                        return
                                    }
                                    
                                    guard let secondDownloadURL = secondURL else {
                                        promise(.failure(NSError(domain: "Invalid download URL", code: 0, userInfo: nil)))
                                        self?.isUploadingPost = false // Set isUploadingPost to false on failure
                                        return
                                    }
                                    
                                    updatedImages.append(secondDownloadURL.absoluteString)
                                    
                                    // Update the document with the image URLs only after both images are uploaded
                                    db.collection("posts").document(documentID).updateData(["images": updatedImages]) { error in
                                        if let error = error {
                                            promise(.failure(error))
                                            self?.isUploadingPost = false // Set isUploadingPost to false on failure
                                        } else {
                                            var updatedPost = tempPost
                                            updatedPost.images = updatedImages
                                            DispatchQueue.main.async {
                                                if let index = self?.feedViewModel?.posts.firstIndex(where: { $0.id == tempPost.id }) {
                                                    self?.feedViewModel?.posts[index] = updatedPost
                                                }
                                            }
                                            promise(.success(()))
                                            DispatchQueue.main.async {
                                                self?.isUploadingPost = false // Set isUploadingPost to false on success
                                                self?.onReset()
                                                self?.resetCameraSession()
                                            }
                                        }
                                    }
                                }
                            }
                        } else {
                            // If there is no second image, update the document with the single image URL
                            db.collection("posts").document(documentID).updateData(["images": updatedImages]) { error in
                                if let error = error {
                                    promise(.failure(error))
                                    self?.isUploadingPost = false // Set isUploadingPost to false on failure
                                } else {
                                    var updatedPost = tempPost
                                    updatedPost.images = updatedImages
                                    DispatchQueue.main.async {
                                        if let index = self?.feedViewModel?.posts.firstIndex(where: { $0.id == tempPost.id }) {
                                            self?.feedViewModel?.posts[index] = updatedPost
                                        }
                                    }
                                    promise(.success(()))
                                    DispatchQueue.main.async {
                                        self?.isUploadingPost = false // Set isUploadingPost to false on success
                                        self?.onReset()
                                        self?.resetCameraSession()
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .eraseToAnyPublisher()
    }
}


//extension CameraViewModel: AVCapturePhotoCaptureDelegate {
//    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
//        if error != nil {
//            print("did err out")
//            return
//        }
//
//        guard let imageData = photo.fileDataRepresentation() else {
//            print("no pic data")
//            return
//        }
//
//        let newUIImage = UIImage(data: imageData)!
//
//        if cameraService.frontCameraActive {
//            self.takenImage = UIImage(cgImage: newUIImage.cgImage!, scale: newUIImage.scale, orientation: .leftMirrored)
//        } else {
//            self.takenImage = UIImage(/*image: newUIImage*/)
//        }
//
//        if cameraService.frontBackCameraModeActive {
//            cameraService.toggleFrontCamera()
//            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1.2) {
//                if let lastFrame = self.frame {
//                    AudioServicesPlaySystemSound(1108)
//                    if let cgImage = lastFrame.cgImage {
//                        self.takenSecondaryImage = UIImage(cgImage: cgImage, scale: newUIImage.scale, orientation: self.cameraService.frontCameraActive ? .upMirrored : .up)
//                    }
//                    self.cameraService.stopSessionRunning()
//                    self.cameraService.toggleFrontCamera()
//                }
//            }
//        } else {
//            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.1) { [self] in
//                cameraService.stopSessionRunning()
//            }
//        }
//    }
//}
