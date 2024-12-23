//
//  MemoriesPostView.swift
//  brief.brief
//
//  Created by Philippe Tchinda on 10/04/2024.
//

import SwiftUI
import Firebase
import FirebaseFirestore




struct MemoriesPostView: View {
    @StateObject private var viewModel: MemoriesPostViewModel
    let selectedDate: Date
    let userID: String

    init(selectedDate: Date, userID: String, postId: String, cameraViewModel: CameraViewModel, commentCameraService: CommentCameraService) {
        self.selectedDate = selectedDate
        self.userID = userID
        self._viewModel = StateObject(wrappedValue: MemoriesPostViewModel(selectedDate: selectedDate, userID: userID, postId: postId, cameraViewModel: cameraViewModel, commentCameraService: commentCameraService))
    }

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 0) {
                Text(selectedDate.getDayAndDateString())
                    .font(.title)
                    .fontWeight(.bold)
                    .padding()
                

                ScrollView {
                    Spacer()

                    VStack(spacing: 20) {
                        if viewModel.isLoading {
                            ProgressView()
                        } else if !viewModel.userPosts.isEmpty {
                            LazyVStack {
                                ForEach(viewModel.userPosts) { post in
                                    PostItemView(post: post, cameraViewModel: viewModel.cameraViewModel, commentCameraService: viewModel.commentCameraService)
                                }
                            }
                            Spacer()
                        } else {
                            Text(viewModel.errorMessage)
                        }
                    }
//                    .padding()
                }
            }
            .background(Color(white: 1, opacity: 0.8))
            .cornerRadius(15)
            .shadow(color: Color.black.opacity(0.4), radius: 10, x: 2, y: 2)
        }
    }
}




class MemoriesPostViewModel: ObservableObject {
    @Published var userPosts: [UserPost] = []
    @Published var isLoading = true
    @Published var errorMessage = ""
    let selectedDate: Date
    let userID: String
    let cameraViewModel: CameraViewModel
    let commentCameraService: CommentCameraService
    @Published var currentUsername = ""

    init(selectedDate: Date, userID: String, postId: String, cameraViewModel: CameraViewModel, commentCameraService: CommentCameraService) {
        self.selectedDate = selectedDate
        self.userID = userID
        self.cameraViewModel = cameraViewModel
        self.commentCameraService = commentCameraService
        fetchPostsData()
    }
    
    private func fetchPostsData() {
        isLoading = true
        fetchPosts(forDate: selectedDate) { result in
            switch result {
            case .success(let posts):
                self.userPosts = posts
                self.isLoading = false
            case .failure(let error):
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    private func fetchPosts(forDate date: Date, completion: @escaping (Result<[UserPost], Error>) -> Void) {
           let startOfDay = Calendar.current.startOfDay(for: date)
           let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)

           let firestoreRef = Firestore.firestore().collection("posts")
               .whereField("timestamp", isGreaterThanOrEqualTo: startOfDay)
               .whereField("timestamp", isLessThan: endOfDay)
               .whereField("userID", isEqualTo: userID)
        
        firestoreRef.getDocuments { (querySnapshot, error) in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let documents = querySnapshot?.documents else {
                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No documents found"])))
                return
            }
            
            var posts: [UserPost] = []
            for document in documents {
                let data = document.data()
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
                posts.append(userPost)
            }
            
            completion(.success(posts))
        }
    }
}

extension Date {
    func getDayAndDateString() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEEE dd MMMM" // Example: "mercredi 22 avril"
        return dateFormatter.string(from: self)
    }
}
