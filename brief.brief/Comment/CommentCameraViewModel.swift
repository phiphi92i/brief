//
//  CommentCameraViewModel.swift
//  brief.brief
//
//  Created by Philippe Tchinda on 25/01/2024.
//

import SwiftUI
import Combine
import FirebaseAuth
import Firebase
import FirebaseStorage

public class CommentCameraViewModel: ObservableObject {
    private var cameraService: CommentCameraService
    private var cancellables = Set<AnyCancellable>()
    
    @Published var photo: Photo?
    @Published var secondPhoto: UIImage?  // Add this property
    @Published var isCameraAvailable: Bool = false
    @Published var showAlert: Bool = false
    @Published var alertError: AlertError?
    @Published var capturedPhoto: UIImage?
    @Published var commentText: String = ""
    @Published var username: String = ""
    let post: UserPost
    @State private var showSendButton = false
    var image: UIImage?
    @Published var showEditPhotoVC = false
    @Published var secondCapturedPhoto: UIImage?

    
    init(commentCameraService: CommentCameraService, currentUsername: String, post: UserPost) {
        self.cameraService = commentCameraService
        self.post = post
        
        // Initialize your subscriptions, or any other setup
        commentCameraService.$photo
            .sink { [weak self] newPhoto in
                if let data = newPhoto?.originalData, let uiImage = UIImage(data: data) {
                    self?.capturedPhoto = uiImage
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

        
        self.fetchCurrentUsername()
    }

    
    func uploadPhotoAndPostComment() {
        guard let currentUserID = Auth.auth().currentUser?.uid else {
            return
        }

        // Handle the captured photo
        if let capturedImage = capturedPhoto, let imageData = capturedImage.jpegData(compressionQuality: 0.7) {
            print("Uploading photo with size: \(imageData.count) bytes")
            let textComment = Comment(userUID: currentUserID, username: self.username, text: commentText, timestamp: Date(), profileImageUrl: nil, mentionedUsernames: [], audioURL: nil, photoURL: [])

            // Upload the first photo and post the comment
            uploadPhotoComment(imageData: imageData, secondImageData: secondCapturedPhoto?.jpegData(compressionQuality: 0.7), comment: textComment)
        }

        // Reset UI state
        commentText = ""
        showSendButton = false
    }

    private func uploadPhotoComment(imageData: Data, secondImageData: Data?, comment: Comment) {
        let ref = Storage.storage().reference().child("comments/\(UUID().uuidString).jpg")
        ref.putData(imageData, metadata: nil) { metadata, error in
            if let error = error {
                print("Error uploading photo: \(error.localizedDescription)")
            } else {
                print("Photo uploaded successfully. Fetching URL...")
                ref.downloadURL { url, error in
                    if let photoURL = url {
                        print("Photo URL: \(photoURL.absoluteString)")

                        // Upload the second photo if it exists
                        if let secondImageData = secondImageData {
                            let secondRef = Storage.storage().reference().child("comments/\(UUID().uuidString).jpg")
                            secondRef.putData(secondImageData, metadata: nil) { secondMetadata, secondError in
                                if let secondError = secondError {
                                    print("Error uploading second photo: \(secondError.localizedDescription)")
                                } else {
                                    print("Second photo uploaded successfully. Fetching URL...")
                                    secondRef.downloadURL { secondURL, secondError in
                                        if let secondPhotoURL = secondURL {
                                            print("Second Photo URL: \(secondPhotoURL.absoluteString)")

                                            // Create a new variable to hold the modified comment
                                            var updatedComment = comment

                                            // Append the String representation of the URLs to the photoURL array
                                            updatedComment.photoURL.append(photoURL.absoluteString)
                                            updatedComment.photoURL.append(secondPhotoURL.absoluteString)

                                            // Call the function with the modified comment
                                            self.uploadComment(updatedComment)
                                        } else if let secondError = secondError {
                                            print("Error getting second photo URL: \(secondError.localizedDescription)")
                                        }
                                    }
                                }
                            }
                        } else {
                            // If there is no second image, append the String representation of the URL to the photoURL array
                            var updatedComment = comment
                            updatedComment.photoURL.append(photoURL.absoluteString)

                            // Call the function with the modified comment
                            self.uploadComment(updatedComment)
                        }
                    } else if let error = error {
                        print("Error getting photo URL: \(error.localizedDescription)")
                    }
                }
            }
        }
    }


    func fetchCurrentUsername() {
        guard let currentUserID = Auth.auth().currentUser?.uid else {
            print("Failed to fetch current user ID")
            return
        }
        
        Firestore.firestore().collection("users").document(currentUserID).getDocument { [weak self] (document, error) in
            guard let self = self else { return }
            
            if let document = document, document.exists {
                if let username = document.data()?["username"] as? String {
                    DispatchQueue.main.async {
                        self.username = username
                        print("Fetched username: \(username)")
                    }
                } else {
                    print("Username not found in document")
                }
            } else {
                print("Document does not exist or failed to fetch document: \(error?.localizedDescription ?? "Unknown error")")
            }
        }
    }

    
    
    private func uploadComment(_ comment: Comment) {
        Firestore.firestore()
            .collection("posts")
            .document(post.id ?? "")
            .collection("comments")
            .addDocument(data: comment.dictionary) { [self] error in
                if let error = error {
                    print("Error adding comment: \(error)")
                } else {
                    print("Comment added successfully.")
                    // Log event when a comment is submitted
                    Analytics.logEvent("comment_submitted", parameters: [
                        "post_id": post.id ?? "",
                        "username": comment.username,
                        "comment_text": comment.text
                    ])
                }
            }
    }
    
    
    
    func startCamera() {
        cameraService.start() // Use the instance to call start
    }
    
    func stopCamera() {
        cameraService.stop() // Use the instance to call stop
    }
    
    func capturePhoto() {
        cameraService.capturePhoto(delegate: self)
    }
    
    
    func doublecapturePhoto() {
        cameraService.doublecapturePhoto(delegate: self)
    }
    
    func zoom(with factor: CGFloat) {
        cameraService.set(zoom: factor) // Use the instance to call set(zoom:)
    }
    
    func focusCamera(at point: CGPoint) {
        cameraService.focus(at: point) // Use the instance to call focus(at:)
    }
    func updateZoomLevel(to zoomFactor: CGFloat) {
        cameraService.setZoomLevel(to: zoomFactor)
    }

    func resetCamera() {
        capturedPhoto = nil // Clear captured photo
        secondCapturedPhoto = nil
        startCamera() // Restart camera session
    }

    
    func clearCapturedPhoto() {
        capturedPhoto = nil
        secondCapturedPhoto = nil
        }

    
    func changeCamera() {
        cameraService.changeCamera() // Use the instance to call changeCamera
    }
}



struct Comment: Identifiable {
     let id = UUID()
     let userUID: String
     let username: String
     let text: String
     let timestamp: Date
     let profileImageUrl: URL? // Profile image URL
     let mentionedUsernames: [String] // Array of mentioned usernames
     let audioURL: URL? // Audio URL
     var photoURL: [String]


     var displayTimestamp: String {
         let formatter = DateComponentsFormatter()
         formatter.allowedUnits = [.second, .minute, .hour]
         formatter.unitsStyle = .abbreviated
         formatter.maximumUnitCount = 1

         return formatter.string(from: timestamp, to: Date()) ?? ""
     }

     var dictionary: [String: Any] {
         return [
             "userUID": userUID,
             "username": username,
             "text": text,
             "timestamp": timestamp,
             "mentionedUsernames": mentionedUsernames,
             "audioURL": audioURL?.absoluteString ?? "",
             "photoURL": photoURL
         ]
     }
 }
