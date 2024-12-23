//
//  NotificationsViewModel.swift
//  brief.brief
//
//  Created by Philippe Tchinda on 06/09/2023.
//

import SwiftUI
import Combine
import FirebaseAuth
import FirebaseFirestore
import FirebaseFirestoreSwift
import Nuke

class NotificationsViewModel: ObservableObject {
    @Published var notifications: [AppNotification] = []
    @Published var postThumbnails: [String: UIImage?] = [:]
    @Published var profileViewModels: [String: ProfileViewModel] = [:]
//    @Published var hasNewNotifications: Bool = false
    private let userID: String
    private let db = Firestore.firestore()
    
    
    
    @Published var hasViewedNotifications: Bool {
        didSet {
            UserDefaults.standard.set(hasViewedNotifications, forKey: "hasViewedNotifications")
        }
    }
    
    @Published var hasNewNotifications: Bool {
           didSet {
               UserDefaults.standard.set(hasNewNotifications, forKey: "hasNewNotifications")
           }
       }
    @Published var unreadNotificationsCount: Int = 0

    private var lastDocument: DocumentSnapshot?
    private let pageSize: Int = 20

    private var cachedNotificationIds: Set<String> = []

    init(userID: String) {
        self.userID = userID
        self.hasNewNotifications = UserDefaults.standard.bool(forKey: "hasNewNotifications")
        self.hasViewedNotifications = UserDefaults.standard.bool(forKey: "hasViewedNotifications")
        loadCachedNotifications()
        loadNotifications()
    }

    func loadNotifications() {
        let currentTime = Date()

        // Initialize the query to fetch notifications, ordered by timestamp and limited by page size
        var query = db.collection("users")
                      .document(self.userID)
                      .collection("notifications")
                      .order(by: "timestamp", descending: true)
                      .limit(to: pageSize)

        // If we have a last document, set it as the starting point for pagination
        if let lastDoc = lastDocument {
            query = query.start(afterDocument: lastDoc)
        }

        // Execute the query
        query.getDocuments { [weak self] (snapshot, error) in
            guard let self = self, let documents = snapshot?.documents else {
                print("No documents or an error occurred")
                return
            }

            // Process the fetched documents to create AppNotification objects
            let newNotifications = documents.compactMap { queryDocumentSnapshot -> AppNotification? in
                let data = queryDocumentSnapshot.data()
                var notification = try? queryDocumentSnapshot.data(as: AppNotification.self)

                // Fetch the reactionType field from the Firestore document
                notification?.reactionType = data["reactionType"] as? String

                // Populate profileViewModels only if they don't already exist
                if let userId = notification?.fromUserID, self.profileViewModels[userId] == nil {
                    self.getProfileViewModel(for: userId)
                }

                // Check if the notification is older than 24 hours
                if let timestamp = notification?.timestamp {
                    let notificationTime = timestamp.dateValue()
                    let timeDifference = Calendar.current.dateComponents([.hour], from: notificationTime, to: currentTime).hour ?? 0
                    if timeDifference >= 24 {
                        return nil  // This will filter out notifications older than 24 hours
                    }
                }

                return notification
            }

            // Append only new notifications
            for var newNotification in newNotifications.compactMap({ $0 }) {
                if let id = newNotification.id, !self.cachedNotificationIds.contains(id) {
                    self.notifications.append(newNotification)
                    self.cachedNotificationIds.insert(id)
                    newNotification.isNew = true // Now it's mutable, so this should work
                    self.hasNewNotifications = true
                }
            }

            self.sortNotifications()

            // Update the last document for future pagination
            self.lastDocument = documents.isEmpty ? nil : documents.last

            // Cache the notification ids and their "isNew" status
            self.cacheNotifications()

            // After loading and assigning cached notifications
            self.sortNotifications()
        }
    }


    private func loadCachedNotifications() {
        let userDefaults = UserDefaults.standard
        if let cachedNotificationIds = userDefaults.object(forKey: "\(userID)_cachedNotificationIds") as? [String],
           !cachedNotificationIds.isEmpty, // Ensure the array is not empty
           let cachedIsNewFlags = userDefaults.object(forKey: "\(userID)_cachedIsNewFlags") as? [String: Bool] {
            
            self.cachedNotificationIds = Set(cachedNotificationIds)

            // Since the array is confirmed not to be empty, proceed with the Firestore query
            db.collection("users")
                .document(self.userID)
                .collection("notifications")
                .whereField(FieldPath.documentID(), in: cachedNotificationIds)
                .getDocuments { [weak self] (snapshot, error) in
                    guard let self = self else { return }
                    
                    if let error = error {
                        print("Error loading cached notifications: \(error)")
                        return
                    }

                    guard let documents = snapshot?.documents else {
                        print("No cached notifications found.")
                        return
                    }

                    let loadedNotifications = documents.compactMap { queryDocumentSnapshot -> AppNotification? in
                        var notification = try? queryDocumentSnapshot.data(as: AppNotification.self)
                        if let id = notification?.id, let isNew = cachedIsNewFlags[id] {
                            notification?.isNew = isNew
                        }
                        return notification
                    }

                    self.notifications = loadedNotifications.sorted { $0.timestamp.dateValue() > $1.timestamp.dateValue() }
                    self.hasNewNotifications = self.notifications.contains(where: { $0.isNew })
                }
        } else {
            // Handle the scenario when there are no cached notification IDs or the array is empty
            print("No cached notification IDs to load or the array is empty.")
        }
    }

    private func sortNotifications() {
        notifications.sort { $0.timestamp.dateValue() > $1.timestamp.dateValue() }
    }

    func fetchFriends(completion: @escaping ([String]) -> Void) {
        db.collection("users")
            .document(self.userID)
            .collection("friends")
            .getDocuments { (snapshot, error) in
                guard let documents = snapshot?.documents else {
                    print("No friends or an error occurred")
                    return
                }

                let friendIDs = documents.compactMap { $0.documentID }
                completion(friendIDs)
            }
    }

    
    
    private func cacheNotifications() {
        let userDefaults = UserDefaults.standard
        let notificationIds = self.notifications.map { $0.id }
        let isNewFlags = self.notifications.reduce(into: [String: Bool]()) { $0[$1.id!] = $1.isNew }
        userDefaults.set(notificationIds, forKey: "\(userID)_cachedNotificationIds")
        userDefaults.set(isNewFlags, forKey: "\(userID)_cachedIsNewFlags")
    }

    func resetNewNotificationsFlag() {
        for index in 0..<notifications.count {
            notifications[index].isNew = false
            // Save the updated notification back to Firestore
            updateNotification(notifications[index])
        }
        self.hasNewNotifications = false
        
        self.sortNotifications()
        
        self.cacheNotifications()
    }

    // Function to update the "isNew" field in Firestore
    private func updateNotification(_ notification: AppNotification?) {
        if let notificationId = notification?.id {
            do {
                try db.collection("users")
                    .document(self.userID)
                    .collection("notifications")
                    .document(notificationId)
                    .setData(from: notification!)
            } catch {
                print("Error updating notification: \(error)")
            }
        }
    }

    func getProfileViewModel(for userId: String) -> ProfileViewModel {
        if let viewModel = profileViewModels[userId] {
            return viewModel
        } else {
            let newViewModel = ProfileViewModel(userID: userId)
            profileViewModels[userId] = newViewModel
            return newViewModel
        }
    }

    func removeProfileViewModel(for userId: String) {
        profileViewModels[userId] = nil
    }
    
    
    
    func fetchPost(for postId: String, completion: @escaping (UserPost?) -> Void) {
        let postRef = db.collection("posts").document(postId)

        postRef.getDocument { (documentSnapshot, error) in
            // Check for errors and document existence
            if let error = error {
                print("Error fetching post: \(error.localizedDescription)")
                completion(nil)
                return
            }

            guard let document = documentSnapshot, document.exists, let data = document.data() else {
                print("The document does not exist.")
                completion(nil)
                return
            }

            // Parse the document data into a UserPost object
            let id = document.documentID
            let content = data["content"] as? String ?? ""
            let timestamp = (data["timestamp"] as? Timestamp)?.dateValue() ?? Date()
            let userID = data["userID"] as? String ?? ""
            let username = data["username"] as? String ?? ""
            let profileImageUrl = data["profileImageUrl"] as? String ?? ""
            let distributionCircles = data["distributionCircles"] as? [String] ?? []
            let images = data["images"] as? [String] ?? []
            let likes = data["likes"] as? [String] ?? []
            let audioURLString = data["audioURL"] as? String
            let expiresAt = (data["expiresAt"] as? Timestamp)?.dateValue() ?? Date()

            var location: UserPost.UserLocation?
            if let locationData = data["location"] as? [String: Any],
               let latitude = locationData["latitude"] as? Double,
               let longitude = locationData["longitude"] as? Double,
               let address = locationData["address"] as? String {
                location = UserPost.UserLocation(latitude: latitude, longitude: longitude, address: address)
            }

            let audioURL = audioURLString.map { URL(string: $0) } ?? nil

            let userPost = UserPost(
                id: document.documentID, // Make sure document.documentID is of type String?
                content: content,
                timestamp: timestamp,
                expiresAt: expiresAt,
                userID: userID,
                username: username,
                profileImageUrl: profileImageUrl,
                distributionCircles: distributionCircles,
                images: images,
                likes: likes,
                audioURL: audioURL,
                location: location,
                isGlobalPost: data["isGlobalPost"] as? Bool ?? false,
                hasSecondaryImage: data["hasSecondaryImage"] as? Bool ?? false
            )

            // Call the completion handler with the constructed UserPost
            completion(userPost)
        }
    }


    
    func loadThumbnail(_ postId: String, completion: @escaping (UIImage?) -> Void) {
        if let thumbnailImage = postThumbnails[postId] {
            completion(thumbnailImage)
        } else {
            fetchPost(for: postId) { post in
                guard let post = post, let imageUrl = post.images.first else {
                    completion(nil)
                    print("Error: Could not find post or image URL")
                    return
                }

                if let url = URL(string: imageUrl) {
                    let request = ImageRequest(url: url)
                    ImagePipeline.shared.loadImage(with: request) { result in
                        DispatchQueue.main.async {
                            switch result {
                            case .success(let response):
                                self.postThumbnails[postId] = response.image
                                completion(response.image)
                            case .failure(let error):
                                completion(nil)
                                print("Error loading image: \(error)")
                            }
                        }
                    }
                } else {
                    completion(nil)
                    print("Error: Could not create URL from string")
                }
            }
        }
    }

    
    func loadMoreNotificationsIfNeeded(currentItem: AppNotification? = nil) {
        if let currentItem = currentItem, notifications.last?.id == currentItem.id {
            loadNotifications()
        } else if currentItem == nil && !notifications.isEmpty {
            // Handle this case as you see fit. Maybe load more notifications?
        }
    }
}

struct AppNotification: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    var type: String  // Could be "like", "comment", "friendRequest", "friendAccepted", "reply"
    var fromUserID: String
    var fromUsername: String
    var fromProfileImageUrl: String?
    var title: String?
    var body: String?
    var postID: String?
    var postPreviewUrl: String?
    var timestamp: Timestamp
    var friendRequestId: String?  // Specific to friend request notifications
    var accepted: Bool?           // Specific to friend request acceptance notifications
    var isNew: Bool
    var pokeType: String?  // Specific to poke notifications
    var postThumbnailURL: String? // New field to store the thumbnail URL
    var reactionType: String?  // Add this field to store the reaction type
}

