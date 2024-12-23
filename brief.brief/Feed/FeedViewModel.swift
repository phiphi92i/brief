
//  FeedViewModel.swift
//  brief.brief
//
//  Created by Philippe Tchinda on 06/06/2023.
//

import SwiftUI
import FirebaseStorage
import FirebaseAuth
import SDWebImageSwiftUI
import FirebaseFirestore
import Combine
import Dispatch


class FeedViewModel: ObservableObject {
    @Published var userProfileImageUrl: URL?
    @Published var userFirstNameInitial: String = ""
    @Published var posts: [UserPost] = []
    //    @Published var isPostsUpdated: Bool = false
    @Published var isProcessingLike: Bool = false
    //    @Published var hasPosts: Bool = true
    @Published var isUploading: Bool = false
    @Published var uploadProgress: Double = 0.0
    //    @Published var selectedPostId: String?
    @Published var isGlobal: Bool = false
    @Published var hasSecondaryImage: Bool = false
    
    private weak var listener: ListenerRegistration?
    private var subscriptions = Set<AnyCancellable>()
    
    @Published var isError: Bool = false
    
    
    
    init() {
//        fetchUserProfileImage()
//        fetchUserFirstName()
        //        fetchPosts()
        
        //        let cameraViewModelInstance = CameraViewModel()
        //        cameraViewModelInstance.newPostPublisher
        //            .sink { [weak self] newPost in
        //                DispatchQueue.main.async {
        //                    self?.posts.insert(newPost, at: 0)
        //                    self?.isPostsUpdated = true
        //                }
        //            }
        //            .store(in: &subscriptions)
        //
        //
        //
        //        let writePostViewModelInstance = WritePostViewModel()
        //        writePostViewModelInstance.newPostPublisher
        //            .sink { [weak self] newPost in
        //                DispatchQueue.main.async {
        //
        //                    self?.posts.insert(newPost, at: 0)
        //                    self?.isPostsUpdated = true
        //                }
        //            }
        //            .store(in: &subscriptions)
        
        
        
        //        writePostViewModelInstance.newPostPublisher
        //            .sink { [weak self] newPost in
        //                DispatchQueue.main.async {
        //                    print("New post received: \(newPost)")
        //                    self?.posts.insert(newPost, at: 0)
        //                    self?.isPostsUpdated = true
        //                }
        //            }
        //            .store(in: &subscriptions)
        
        
        //        DeepLinkManager.shared.$deepLinkURL
        //            .compactMap { $0 }
        //            .compactMap { url -> String? in
        //                guard let host = URLComponents(url: url, resolvingAgainstBaseURL: true)?.host, host == "post",
        //                      let postId = URLComponents(url: url, resolvingAgainstBaseURL: true)?.path.split(separator: "/").map(String.init).last else { return nil }
        //                return postId
        //            }
        //            .assign(to: &$selectedPostId)
        
        
        
        //        cameraViewModelInstance.$temporaryPosts
        //            .sink { [weak self] newTemporaryPosts in
        //                DispatchQueue.main.async {
        //                    self?.posts.insert(contentsOf: newTemporaryPosts, at: 0)
        //                }
        //            }
        //            .store(in: &subscriptions)
        //
    }
    //
    //    deinit {
    //        removeListenersAndSubscriptions()
    //    }
    
    
    
    func removeListenersAndSubscriptions() {
        listener?.remove()
        subscriptions.forEach { $0.cancel() }
        subscriptions.removeAll()
    }
    
    
    
    
    
    func fetchUserProfileImage() {
//        print("fetchUserProfileImage started.")
        
        guard let currentUser = Auth.auth().currentUser else {
            self.isError = true
            print("No current user.")
            return
        }
        
        let cacheFileName = "\(currentUser.uid)_profileImageURL.txt"
        let cacheFileURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!.appendingPathComponent(cacheFileName)
        
        // Attempt to load cached URL
        if let cachedURLString = try? String(contentsOf: cacheFileURL),
           let cachedURL = URL(string: cachedURLString) {
            DispatchQueue.main.async {
                print("Setting user profile image URL to: \(cachedURL)")
                self.userProfileImageUrl = cachedURL
            }
            return
        }
        
        let storageRef = Storage.storage().reference().child("profileImages/\(currentUser.uid).jpg")
        
        storageRef.downloadURL { [weak self] url, error in
            // Error Handling: Set the error flag and log the error if it occurs
            if let error = error {
                self?.isError = true
                print("Error fetching profile image URL: \(error.localizedDescription)")
                // Maybe notify the user or take corrective action
                return
            }
            
            // Null Handling: Set the error flag and log the issue if the URL is nil
            guard let url = url else {
                self?.isError = true
                print("Received URL is nil.")
                // Maybe notify the user or take corrective action
                return
            }
            
            // Update the UI on the main thread
            DispatchQueue.main.async {
                print("Setting user profile image URL to: \(url)")
                self?.userProfileImageUrl = url
            }
            
            // Cache the URL
            try? url.absoluteString.write(to: cacheFileURL, atomically: true, encoding: .utf8)
        }
        
        print("fetchUserProfileImage completed.")
    }
    
    
    
    func fetchUserFirstName() {
        guard let currentUser = Auth.auth().currentUser else { return }
        let db = Firestore.firestore()
        
        db.collection("users").document(currentUser.uid).getDocument { [weak self] (document, error) in
            DispatchQueue.main.async {
                if let document = document, document.exists {
                    if let firstName = document.data()?["firstName"] as? String {
                        self?.userFirstNameInitial = String(firstName.prefix(1)).uppercased()
                    }
                } else {
                    print("Document does not exist")
                }
            }
        }
    }
    
    

    
    
    
    

    func fetchPosts(completion: @escaping (Result<Void, Error>) -> Void) {
        guard let currentUser = Auth.auth().currentUser else {
            print("No authenticated user found")
            return
        }

        var userIds: [String] = [currentUser.uid]

        Firestore.firestore().collection("Friends").document(currentUser.uid).getDocument { [weak self] (document, error) in
            if let document = document, document.exists {
                if let friendIds = document.data()?["friendsList"] as? [String] {
                    userIds.append(contentsOf: friendIds)
                }
            } else {
                print("Document does not exist")
            }

            Firestore.firestore().collection("distributionCircles")
                .whereField("member_ids", arrayContains: currentUser.uid)
                .getDocuments { (snapshot, error) in
                    if let error = error {
                        print("Error fetching distribution circles: \(error)")
                    } else {
                        var circleIDs = snapshot?.documents.compactMap { $0.data()["name"] as? String } ?? []

                        Firestore.firestore().collection("distributionCircles")
                            .whereField("creator_id", isEqualTo: currentUser.uid)
                            .getDocuments { (creatorSnapshot, error) in
                                if let error = error {
                                    print("Error fetching creator circles: \(error)")
                                } else {
                                    let creatorCircleIDs = creatorSnapshot?.documents.compactMap { $0.data()["name"] as? String } ?? []
                                    circleIDs += creatorCircleIDs

                                    self?.fetchPosts(for: userIds, distributionCircles: circleIDs, completion: completion)
                                    guard let self = self else { return }
                                    completion(.success(()))
                                }
                            }
                    }
                }
        }
    }

    private func fetchPosts(for userIds: [String], distributionCircles: [String], completion: @escaping (Result<Void, Error>) -> Void) {
        let postsCollection = Firestore.firestore().collection("posts")

        let chunkedUserIds = stride(from: 0, to: userIds.count, by: 10).map {
            Array(userIds[$0..<min($0 + 10, userIds.count)])
        }

        var allPosts: [UserPost] = []

        let group = DispatchGroup()

        for chunk in chunkedUserIds {
            group.enter()

            let query = postsCollection.whereField("userID", in: chunk).order(by: "timestamp", descending: true)

            query.getDocuments { [weak self] (snapshot, error) in
                guard let documents = snapshot?.documents else {
                    print("Error fetching documents: \(error?.localizedDescription ?? "")")
                    group.leave()
                    return
                }

                var posts: [UserPost] = []

                for document in documents {
                    let data = document.data()
                    let distributionCirclesFromPost = data["distributionCircles"] as? [String] ?? []

                    if distributionCirclesFromPost.contains(where: { distributionCircles.contains($0) || $0 == "all_friends" }) {
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

                        if let locationData = data["location"] as? [String: Any],
                           let latitude = locationData["latitude"] as? Double,
                           let longitude = locationData["longitude"] as? Double,
                           let address = locationData["address"] as? String {
                            location = UserPost.UserLocation(latitude: latitude, longitude: longitude, address: address)
                        }

                        if originalExpirationTime > currentDate {
                            let userPost = UserPost(id: id, content: content, timestamp: originalTimestamp, expiresAt: originalExpirationTime, userID: userID, username: username, profileImageUrl: profileImageUrl, distributionCircles: distributionCircles, images: images, likes: likes, audioURL: audioURL, location: location, isGlobalPost: self?.isGlobal ?? false, hasSecondaryImage: self?.hasSecondaryImage ?? false)
                            posts.append(userPost)
                        }
                    }
                }

                allPosts.append(contentsOf: posts)
                group.leave()
            }
        }

        group.notify(queue: .main) { [weak self] in
            self?.posts = allPosts.sorted(by: { $0.timestamp > $1.timestamp })
            completion(.success(()))
        }
    }
}


