
//  PostRowView.swift
//  brief.brief
//
//  Created by Philippe Tchinda on 24/02/2024.

//
import SwiftUI
import Firebase
import FirebaseFirestore



struct SinglePostView: View {
    @StateObject private var viewModel: SinglePostViewModel

    init(postId: String, cameraViewModel: CameraViewModel, commentCameraService: CommentCameraService) {
        self._viewModel = StateObject(wrappedValue: SinglePostViewModel(postId: postId, cameraViewModel: cameraViewModel, commentCameraService: commentCameraService))
    }

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 0) {
                ScrollView {
                    VStack(spacing: 0) {
                        if viewModel.isLoading {
                            ProgressView()
                        } else if let userPost = viewModel.userPost {
                            PostItemView(post: userPost, cameraViewModel: viewModel.cameraViewModel, commentCameraService: viewModel.commentCameraService)

                            Spacer()

//                            CommentView(
//                                post: userPost,
//                                username: userPost.username,
//                                viewModel: CommentCameraViewModel(
//                                    commentCameraService: viewModel.commentCameraService,
//                                    currentUsername: viewModel.currentUsername,
//                                    post: userPost
//                                ),
//                                postId: viewModel.postId,
//                                CommentcameraService: viewModel.commentCameraService
//                            )
                            .frame(maxWidth: .infinity, alignment: .bottom)
                        } else {
                            Text(viewModel.errorMessage)
                        }
                    }
                }
            }
            .background(Color(white: 1, opacity: 0.8))
            .cornerRadius(15)
            .shadow(color: Color.black.opacity(0.4), radius: 10, x: 2, y: 2)
        }
    }
}

class SinglePostViewModel: ObservableObject {
    @Published var userPost: UserPost?
    @Published var isLoading = true
    @Published var errorMessage = ""
    let postId: String
    let cameraViewModel: CameraViewModel
    let commentCameraService: CommentCameraService
    @Published var currentUsername = ""
    
    init(postId: String, cameraViewModel: CameraViewModel, commentCameraService: CommentCameraService) {
        self.postId = postId
        self.cameraViewModel = cameraViewModel
        self.commentCameraService = commentCameraService
        fetchPostData()
    }
    
    private func fetchPostData() {
        isLoading = true
        fetchPost(withId: postId) { result in
            switch result {
            case .success(let post):
                self.userPost = post
                self.isLoading = false
            case .failure(let error):
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    private func fetchPost(withId postId: String, completion: @escaping (Result<UserPost, Error>) -> Void) {
        let postRef = Firestore.firestore().collection("posts").document(postId)
        
        postRef.getDocument { (document, error) in
            if let document = document, document.exists, let data = document.data() {
                // Fetch post data from Firestore and create a UserPost instance
                let id = document.documentID
                let content = data["content"] as? String ?? ""
                let images = data["images"] as? [String] ?? []
                let userID = data["userID"] as? String ?? ""
                let username = data["username"] as? String ?? ""
                let profileImageUrl = data["profileImageUrl"] as? String ?? ""
                let distributionCircles = data["distributionCircles"] as? [String] ?? []
                let likes = data["likes"] as? [String] ?? []
                let audioURLString = data["audioURL"] as? String ?? ""
                let audioURL = URL(string: audioURLString)
                
                let firestoreTimestamp = data["timestamp"] as? Timestamp
                let originalTimestamp = firestoreTimestamp?.dateValue() ?? Date()
                
                let expirationTimestamp = data["expiresAt"] as? Timestamp
                let originalExpirationTime = expirationTimestamp?.dateValue() ?? originalTimestamp.addingTimeInterval(24 * 60 * 60)
                
                let currentDate = Date()
                var location: UserPost.UserLocation? = nil
                
                // Optional location data fetching
                if let locationData = data["location"] as? [String: Any],
                   let latitude = locationData["latitude"] as? Double,
                   let longitude = locationData["longitude"] as? Double,
                   let address = locationData["address"] as? String {
                    location = UserPost.UserLocation(latitude: latitude, longitude: longitude, address: address)
                }
                
                let userPost = UserPost(id: id, content: content, timestamp: originalTimestamp, expiresAt: originalExpirationTime, userID: userID, username: username, profileImageUrl: profileImageUrl, distributionCircles: distributionCircles, images: images, likes: likes, audioURL: audioURL, location: location, isGlobalPost: false, hasSecondaryImage: false)
                completion(.success(userPost))
            } else {
                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Post not found"])))
            }
        }
    }
}
