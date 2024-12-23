//
//  ProfileViewModel.swift
//  brief.brief
//
//  Created by Philippe Tchinda on 12/06/2023.
//

import Foundation
import FirebaseAnalytics
import Firebase
import FirebaseFirestore
import FirebaseStorage
import FirebaseAuth
import FirebaseFirestoreSwift
import SDWebImageSwiftUI
import SwiftUI


extension View {
    func snapshot() -> UIImage {
        let controller = UIHostingController(rootView: self)
        let view = controller.view
        let targetSize = controller.sizeThatFits(in: CGSize(width: 50, height: 50)) // Thumbnail size
        view?.bounds = CGRect(origin: .zero, size: targetSize)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            view?.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
        }
    }
}



class ProfileViewModel: ObservableObject {
    @Published var userProfileImageUrl: String?
    @Published var userFirstNameInitial: String = ""
    @Published var username: String = ""
    @Published var bio: String = ""
    @Published var firstName: String = ""
    @Published var lastName: String = ""
    @Published var posts: [UserPost] = []
    @Published var isProcessingLike: Bool = false
    @Published var userBannerImageUrl: String?
    @Published var currentFriends: [String] = []
    @Published var isSelected: Bool? = nil
    @Published var selectedUsers = Set<String>()
    @Published var friends: [User] = []
    var onFriendStatusUpdated: ((Bool) -> Void)?
    @Published var isGlobal: Bool = false
    @Published var hasSecondaryImage: Bool = false
    @Published var postCount: Int = 0
    

    @Published var friendRequestsSent: [String] = []
       @Published var friendRequestsReceived: [String] = []
    @Published var incomingFriendRequests: [String] = []

    private let pageSize = 5
    private var lastDocument: DocumentSnapshot?
    private var canLoadMore = true
    private let storage = Storage.storage()
    private let userID: String
    private let db = Firestore.firestore()
    
    private var hasFetchedData = false
    
    init(userID: String) {
        self.userID = userID
        fetchDataIfNeeded()
    }
    
    func fetchDataIfNeeded() {
        guard !hasFetchedData else { return }
//        fetchUserProfileImage()
//        fetchUserFirstName()
//        fetchUserInfo()
//        fetchPosts()
        fetchBannerImageUrl()
        fetchFriendsAndSentRequests()
        hasFetchedData = true
    }
    
    func fetchUserProfileImage() {
        let storageRef = storage.reference().child("profileImages/\(self.userID).jpg")
        storageRef.downloadURL { url, error in
            if let error = error {
                print("Error fetching profile image URL: \(error)")
            } else {
                self.userProfileImageUrl = url?.absoluteString
            }
        }
    }
    
    func fetchUserFirstName() {
        let db = Firestore.firestore()
        db.collection("users").document(self.userID).getDocument { document, error in
            if let document = document, document.exists {
                if let firstName = document.data()?["firstName"] as? String {
                    self.userFirstNameInitial = String(firstName.prefix(1)).uppercased()
                }
            } else {
                print("Document does not exist")
            }
        }
    }
    
    func fetchUserInfo() {
        let db = Firestore.firestore()
        db.collection("users").document(self.userID).getDocument { [weak self] document, error in
            guard let self = self else { return }
            if let document = document, document.exists {
                if let data = document.data() {
                    self.username = data["username"] as? String ?? ""
                    self.bio = data["bio"] as? String ?? ""
                    self.firstName = data["firstName"] as? String ?? ""
                    self.lastName = data["lastName"] as? String ?? ""
                    
                    
                }
            }
        }
    }
    
    
    
    // Send a friend request to a specified user
    func sendFriendRequest(_ user: User) {
        guard let currentUserID = Auth.auth().currentUser?.uid else {
            print("Could not get current user ID")
            return
        }
        
        // Prevent sending friend requests to oneself
        if currentUserID == user.id {
            print("Can't send a friend request to yourself")
            return
        }
        
        let currentUserRef = Firestore.firestore().collection("users").document(currentUserID)
        currentUserRef.getDocument { (document, error) in
            if let error = error {
                print("Error fetching current user document: \(error.localizedDescription)")
                return
            }
            
            guard let document = document, document.exists else {
                print("Current user document does not exist")
                return
            }
            
            // Fetch current user's username
            guard let currentUsername = document.data()?["username"] as? String else {
                print("Could not fetch current user's username")
                return
            }
            
            // Check if a friend request has already been sent to this user
            if let sentRequests = document.data()?["sentRequests"] as? [String], sentRequests.contains(user.id) {
                print("Friend request already sent to user: \(user.id)")
                return
            }
            
            let friendRequestRef = Firestore.firestore().collection("users").document(user.id).collection("friendRequests").document(currentUserID)
            
            // Set the data for the friend request
            friendRequestRef.setData(["fromUserId": currentUserID, "fromUsername": currentUsername], merge: true) { error in
                if let error = error {
                    print("Error sending friend request: \(error.localizedDescription)")
                    return
                }
                
                // Update the 'sentRequests' field for the current user
                currentUserRef.updateData(["sentRequests": FieldValue.arrayUnion([user.id])]) { error in
                    if let error = error {
                        print("Error updating sent requests: \(error.localizedDescription)")
                        return
                    }
                    
                    print("Friend request sent successfully to user: \(user.id)")
                    // Here you can update any UI elements or states, if needed
                }
            }
        }
    }
    
    // Cancel a sent friend request to a specified user
    func cancelFriendRequest(_ user: User) {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }
        
        let friendRequestRef = Firestore.firestore().collection("users").document(user.id).collection("friendRequests").document(currentUserID)
        friendRequestRef.delete() { error in
            if let error = error {
                print("Error canceling friend request: \(error.localizedDescription)")
            } else {
                let currentUserRef = Firestore.firestore().collection("users").document(currentUserID)
                currentUserRef.updateData(["sentRequests": FieldValue.arrayRemove([user.id])]) { _ in
                    self.selectedUsers.remove(user.id)
                    self.isSelected = false  // Update isSelected
                }
            }
        }
    }
    
    func fetchFriendsAndSentRequests() {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }

        let group = DispatchGroup()

        // Fetch 'sentRequests' from the 'users' collection
        group.enter()
        var fetchedSentRequests: [String] = []
        Firestore.firestore().collection("users").document(currentUserID).getDocument { (document, error) in
            if let document = document, document.exists {
                fetchedSentRequests = document.data()?["sentRequests"] as? [String] ?? []
            }
            group.leave()
        }

        // Fetch 'friendsList' from the 'Friends' collection
        group.enter()
        var fetchedFriendsIDs: [String] = []
        var fetchedFriends: [User] = []
        Firestore.firestore().collection("Friends").document(currentUserID).getDocument { (friendsDoc, friendsError) in
            if let friendsDoc = friendsDoc, friendsDoc.exists {
                fetchedFriendsIDs = friendsDoc.data()?["friendsList"] as? [String] ?? []
                let innerGroup = DispatchGroup()
                for id in fetchedFriendsIDs {
                    innerGroup.enter()
                    Firestore.firestore().collection("users").document(id).getDocument { (userSnapshot, userError) in
                        if let userData = userSnapshot?.data(),
                           let username = userData["username"] as? String,
                           let firstName = userData["firstName"] as? String,
                           let lastName = userData["lastName"] as? String,
                           let profileImageUrl = userData["profileImageUrl"] as? String {
                            let user = User(id: id, username: username, firstName: firstName, lastName: lastName, isInvited: false, name: "", friends: [], friendRequestsSent: [], profileImageUrl: profileImageUrl)
                            fetchedFriends.append(user)
                        }
                        innerGroup.leave()
                    }
                }
                innerGroup.notify(queue: .main) {
                    group.leave()
                }
            } else {
                group.leave()
            }
        }

        // Fetch 'incomingFriendRequests' from the 'users' collection
        group.enter()
        var fetchedIncomingFriendRequests: [String] = []
        Firestore.firestore().collection("users").document(currentUserID).collection("friendRequests").getDocuments { (querySnapshot, error) in
            if let querySnapshot = querySnapshot {
                fetchedIncomingFriendRequests = querySnapshot.documents.map { $0.documentID }
            }
            group.leave()
        }

        group.notify(queue: .main) {
            self.friends = fetchedFriends
            self.selectedUsers = Set(fetchedSentRequests)
            self.currentFriends = fetchedFriendsIDs
            self.friendRequestsSent = fetchedSentRequests
            self.incomingFriendRequests = fetchedIncomingFriendRequests
            self.isSelected = self.selectedUsers.contains(self.userID) || self.currentFriends.contains(self.userID)
            self.onFriendStatusUpdated?(self.currentFriends.contains(self.userID))
        }
    }


    func acceptFriendRequest(_ userID: String) {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }

        let currentUserFriendsRef = Firestore.firestore().collection("Friends").document(currentUserID)
        let userFriendsRef = Firestore.firestore().collection("Friends").document(userID)

        currentUserFriendsRef.getDocument { (currentDocument, error) in
            if let error = error {
                print("Error getting document: \(error)")
                return
            }

            var currentFriends = currentDocument?.data()?["friendsList"] as? [String] ?? []

            userFriendsRef.getDocument { (userDocument, error) in
                if let error = error {
                    print("Error getting document: \(error)")
                    return
                }

                var userFriends = userDocument?.data()?["friendsList"] as? [String] ?? []

                currentFriends.append(userID)
                userFriends.append(currentUserID)

                currentUserFriendsRef.setData(["friendsList": currentFriends], merge: true) { error in
                    if let error = error {
                        print("Error setting data: \(error)")
                        return
                    }

                    userFriendsRef.setData(["friendsList": userFriends], merge: true) { error in
                        if let error = error {
                            print("Error setting data: \(error)")
                            return
                        }

                        // Remove friend request from the sender's document in the users collection
                        let friendRequestSenderRef = Firestore.firestore().collection("users").document(userID)
                        friendRequestSenderRef.updateData(["sentRequests": FieldValue.arrayRemove([currentUserID])]) { error in
                            if let error = error {
                                print("Error removing sentRequests field from sender's document: \(error.localizedDescription)")
                                return
                            }

                            // Remove friend request from the receiver's friendRequests subcollection
                            let friendRequestReceiverRef = Firestore.firestore().collection("users").document(currentUserID).collection("friendRequests").document(userID)
                            friendRequestReceiverRef.delete() { error in
                                if let error = error {
                                    print("Error deleting friend request from receiver: \(error.localizedDescription)")
                                    return
                                }

                                // Log the event
                                Analytics.logEvent("friendRequest_accepted", parameters: ["user_id": userID ])

                                // Remove the accepted friend request from the local array (assuming you have one)
                                self.friendRequestsReceived.removeAll(where: { $0 == userID })
                                
                                // Update the isSelected property and call the onFriendStatusUpdated(_:) closure
                                self.isSelected = nil
                                self.onFriendStatusUpdated?(true)

                            }
                        }
                    }
                }
            }
        }
    }

    
    
    
    
    func fetchFriendsList(forUserID userID: String, completion: @escaping ([User]?) -> Void) {
        let friendsRef = db.collection("Friends").document(userID)
        
        friendsRef.getDocument { [weak self] (document, error) in
            guard let self = self else {
                completion(nil)
                return
            }
            
            if let error = error {
                print("Error fetching friends: \(error)")
                completion(nil)
                return
            }
            
            guard let document = document, document.exists, let friendsListIDs = document.data()?["friendsList"] as? [String] else {
                print("No friends found or document does not exist for userID: \(userID)")
                completion(nil)
                return
            }
            
            var fetchedFriends: [User] = []
            var fetchedFriendIDs = Set<String>() // Track IDs to prevent duplicates
            let group = DispatchGroup()
            
            for friendID in friendsListIDs {
                if fetchedFriendIDs.contains(friendID) {
                    // Skip this ID if it's already been processed
                    continue
                }
                fetchedFriendIDs.insert(friendID) // Mark this ID as processed
                
                group.enter()
                self.db.collection("users").document(friendID).getDocument { (userDoc, err) in
                    defer { group.leave() }
                    
                    if let userData = userDoc?.data() {
                        let friend = User(
                            id: friendID,
                            username: userData["username"] as? String ?? "No Username",
                            firstName: "", // Provided empty string as default value
                            lastName: "", // Provided empty string as default value
                            name: "", // Provided empty string as default value
                            friends: [], // Provided empty array as default value
                            profileImageUrl: userData["profileImageUrl"] as? String ?? ""
                        )
                        fetchedFriends.append(friend)
                    }
                }
            }
            
            group.notify(queue: .main) {
                completion(fetchedFriends)
            }
        }
    }
    
    
    
    func fetchFriends(completion: @escaping ([User]?) -> Void) {
        guard let currentUserID = Auth.auth().currentUser?.uid else {
            completion(nil)
            return
        }
        
        let friendsRef = Firestore.firestore().collection("Friends").document(currentUserID)
        
        friendsRef.getDocument { (document, error) in
            if let document = document, document.exists {
                guard let friendsListIDs = document.data()?["friendsList"] as? [String] else {
                    completion(nil)
                    return
                }
                
                var fetchedFriends: [User] = []
                let group = DispatchGroup()
                
                for friendID in friendsListIDs {
                    group.enter()
                    Firestore.firestore().collection("users").document(friendID).getDocument { (userDoc, userError) in
                        if let userData = userDoc?.data(),
                           let username = userData["username"] as? String,
                           let firstName = userData["firstName"] as? String,
                           let lastName = userData["lastName"] as? String,
                           let profileImageUrl = userData["profileImageUrl"] as? String {
                            let user = User(id: friendID, username: username, firstName: firstName, lastName: lastName, isInvited: false, name: "", friends: [], friendRequestsSent: [], profileImageUrl: profileImageUrl)
                            fetchedFriends.append(user)
                        }
                        group.leave()
                    }
                }
                
                group.notify(queue: .main) {
                    completion(fetchedFriends)
                }
                
            } else {
                print("Document does not exist: \(error?.localizedDescription ?? "Unknown error")")
                completion(nil)
            }
        }
    }
    
    
    
    
    
    func fetchPosts() {
        guard let viewingUserID = Auth.auth().currentUser?.uid, canLoadMore else { return }
        
        var query = Firestore.firestore().collection("posts")
            .whereField("userID", isEqualTo: self.userID)
            .order(by: "timestamp", descending: true)
        
        // Check if the user is viewing their own profile or they are friends with the profile owner
        if viewingUserID != self.userID && !self.friends.contains(where: { $0.id == viewingUserID }) {
            // Fetch posts shared in distribution circles where the viewing user is a member
            Firestore.firestore().collection("distributionCircles")
                .whereField("member_ids", arrayContains: viewingUserID)
                .getDocuments { [weak self] (snapshot, error) in
                    guard let self = self, let circleNames = snapshot?.documents.compactMap({ $0.data()["name"] as? String }), !circleNames.isEmpty else { return }
                    
                    var circles = circleNames
                    circles.append("all_friends") // Include posts shared with all friends
                    
                    query = query.whereField("distributionCircles", arrayContainsAny: circles)
                    self.performQuery(query)
                }
        } else {
            // If viewing own profile or a friend's profile, fetch all posts
            performQuery(query)
        }
    }
    
    private func performQuery(_ query: Query) {
        // Paginate the query if lastDocument is available
        let paginatedQuery = lastDocument != nil ? query.start(afterDocument: lastDocument!) : query.limit(to: pageSize)
        
        paginatedQuery.getDocuments { [weak self] (querySnapshot, error) in
            guard let self = self else { return }
            
            if let error = error {
                print("Error getting posts: \(error)")
                return
            }
            
            guard let querySnapshot = querySnapshot, !querySnapshot.isEmpty else {
                self.canLoadMore = false
                return
            }
            
            let newPosts = querySnapshot.documents.compactMap { document -> UserPost? in
                let data = document.data()
                if let timestamp = data["timestamp"] as? Timestamp, let expiresAt = data["expiresAt"] as? Timestamp {
                    let currentDate = Date()
                    let expirationDate = expiresAt.dateValue()
                    if currentDate <= expirationDate {
                        return UserPost(
                            id: document.documentID,
                            content: data["content"] as? String ?? "",
                            timestamp: timestamp.dateValue(),
                            expiresAt: expiresAt.dateValue(),
                            userID: data["userID"] as? String ?? "",
                            username: data["username"] as? String ?? "",
                            profileImageUrl: data["profileImageUrl"] as? String ?? "",
                            distributionCircles: data["distributionCircles"] as? [String] ?? [],
                            images: data["images"] as? [String] ?? [],
                            likes: data["likes"] as? [String] ?? [],
                            audioURL: nil,
                            isGlobalPost: self.isGlobal ?? false, hasSecondaryImage: self.hasSecondaryImage ?? false
                        )
                    }
                }
                return nil
            }
            
            DispatchQueue.main.async {
                self.posts.append(contentsOf: newPosts)
                self.lastDocument = querySnapshot.documents.last
                self.canLoadMore = newPosts.count == self.pageSize
            }
        }
    }
    
    
    
    func fetchAllUserPosts() {
        let db = Firestore.firestore()
        db.collection("posts").whereField("userID", isEqualTo: self.userID)
            .order(by: "timestamp", descending: true)
            .getDocuments { querySnapshot, error in
                if let error = error {
                    print("Error getting posts: \(error)")
                } else {
                    DispatchQueue.main.async {
                        self.posts = querySnapshot?.documents.compactMap { document in
                            let data = document.data()
                            let audioURLString = data["audioURL"] as? String
                            let audioURL = URL(string: audioURLString ?? "")
                            if let timestamp = data["timestamp"] as? Timestamp,
                               let expiresAt = data["expiresAt"] as? Timestamp {
                                let currentDate = Date()
                                let expirationDate = expiresAt.dateValue()
                                if currentDate <= expirationDate {
                                    return UserPost(
                                        id: document.documentID,
                                        content: data["content"] as? String ?? "",
                                        timestamp: timestamp.dateValue(),
                                        expiresAt: expiresAt.dateValue(),
                                        userID: data["userID"] as? String ?? "",
                                        username: data["username"] as? String ?? "",
                                        profileImageUrl: data["profileImageUrl"] as? String ?? "",
                                        distributionCircles: data["distributionCircles"] as? [String] ?? [],
                                        images: data["images"] as? [String] ?? [],
                                        likes: data["likes"] as? [String] ?? [],
                                        audioURL: audioURL,
                                        isGlobalPost: self.isGlobal ?? false, hasSecondaryImage: self.hasSecondaryImage ?? false
                                    )
                                } else {
                                    return nil
                                }
                            } else {
                                return nil
                            }
                        } ?? []
                    }
                }
            }
    }
    
    
    func loadMorePosts() {
        if !isProcessingLike {
            self.fetchPosts()
        }
    }
    
    
    
    
    
    
    func uploadProfilePicture(imageData: Data, completion: @escaping (String?) -> Void) {
        guard let currentUser = Auth.auth().currentUser else {
            completion(nil)
            return
        }
        
        let storageRef = storage.reference().child("profileImages/\(currentUser.uid).jpg")
        
        storageRef.putData(imageData, metadata: nil) { _, error in
            if let error = error {
                print("Error uploading image: \(error)")
                completion(nil)
            } else {
                storageRef.downloadURL { url, error in
                    if let error = error {
                        print("Error fetching download URL: \(error)")
                        completion(nil)
                    } else {
                        completion(url?.absoluteString)
                    }
                }
            }
        }
    }
    
    func uploadBannerImage(imageData: Data, completion: @escaping (String?) -> Void) {
        guard let currentUser = Auth.auth().currentUser else {
            completion(nil)
            return
        }
        
        let storageRef = storage.reference().child("bannerImages/\(currentUser.uid).jpg")
        
        storageRef.putData(imageData, metadata: nil) { _, error in
            if let error = error {
                print("Error uploading banner image: \(error)")
                completion(nil)
            } else {
                storageRef.downloadURL { url, error in
                    if let error = error {
                        print("Error fetching download URL for banner: \(error)")
                        completion(nil)
                    } else {
                        completion(url?.absoluteString)
                    }
                }
            }
        }
    }
    
    func updateBannerImageUrlInFirestore(url: String) {
        guard let currentUser = Auth.auth().currentUser else {
            return
        }
        
        let db = Firestore.firestore()
        db.collection("users").document(currentUser.uid).updateData([
            "bannerImageUrl": url
        ]) { error in
            if let error = error {
                print("Error updating banner image URL: \(error)")
            } else {
                print("Banner image URL successfully updated")
            }
        }
    }
    
    func fetchBannerImageUrl() {
        let storageRef = storage.reference().child("bannerImages/\(self.userID).jpg")
        storageRef.downloadURL { url, error in
            if let error = error {
                print("Error fetching banner image URL: \(error)")
                self.userBannerImageUrl = nil // or set to a default image URL
            } else {
                self.userBannerImageUrl = url?.absoluteString
            }
        }
    }
    
    func sendPokeToUser(recipientId: String) {
        // Assume that `currentUser` is the sender
        guard let currentUser = Auth.auth().currentUser else { return }
        
        // Prepare the data for Firestore with an explicit type annotation
        let pokeData: [String: Any] = [
            "senderId": currentUser.uid,
            "recipientId": recipientId,
            "timestamp": FieldValue.serverTimestamp(),
            "pokeType": "🫵"
        ]
        
        // Write the "poke" action to Firestore
        let db = Firestore.firestore()
        db.collection("pokes").addDocument(data: pokeData) { error in
            if let error = error {
                print("Error sending poke: \(error.localizedDescription)")
            } else {
                print("Poke sent successfully")
            }
        }
    }
    
    
    
    
    
    func updateProfileImageUrlInFirestore(url: String) {
        guard let currentUser = Auth.auth().currentUser else {
            return
        }
        
        let db = Firestore.firestore()
        db.collection("users").document(currentUser.uid).updateData([
            "profileImageUrl": url
        ]) { error in
            if let error = error {
                print("Error updating profile image URL: \(error)")
            } else {
                print("Profile image URL successfully updated")
            }
        }
    }
    
    func updateBio(newBio: String) {
        guard let currentUser = Auth.auth().currentUser else {
            return
        }
        
        let db = Firestore.firestore()
        db.collection("users").document(currentUser.uid).updateData([
            "bio": newBio
        ]) { error in
            if let error = error {
                print("Error updating bio: \(error)")
            } else {
                self.bio = newBio
                print("Bio successfully updated")
            }
        }
    }
    
    func fetchPostCount(forUserID userID: String) {
        let db = Firestore.firestore()
        db.collection("posts").whereField("userID", isEqualTo: userID).getDocuments { (querySnapshot, err) in
            if let err = err {
                print("Error getting documents: \(err)")
            } else {
                self.postCount = querySnapshot?.documents.count ?? 0
            }
        }
    }
}
