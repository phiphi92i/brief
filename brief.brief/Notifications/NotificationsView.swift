//
//  NotificationsView.swift
//  brief.brief
//
//  Created by Philippe Tchinda on 04/06/2023.
//

import SwiftUI
import Combine
import FirebaseAuth
import FirebaseFirestore
import FirebaseFirestoreSwift
import SDWebImageSwiftUI
import Foundation
import FirebaseAnalytics
import FirebaseAuth
import Nuke
import NukeUI



struct NotificationsView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject  var viewModel : NotificationsViewModel
    @State private var selectView = SelectView.notifications
    @ObservedObject  var activityFeedViewModel : ActivityFeedViewModel
    @ObservedObject  var commentCameraService = CommentCameraService()
    @ObservedObject  var cameraViewModel = CameraViewModel()
    @State private var userId = ""


    enum SelectView {
        case notifications
        case activityFeed
    }

    var body: some View {
        NavigationView {
            VStack {
                Picker("Select View", selection: $selectView) {
                    Text(NSLocalizedString("Pour moi", comment: "No notifications message")).tag(SelectView.notifications)
                    Text(NSLocalizedString("Mes amis", comment: "No notifications message")).tag(SelectView.activityFeed)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)

                // Display content based on the picker's selection
                switch selectView {
                case .notifications:
                    NotificationsListView(
                        notifications: $viewModel.notifications,
                        profileViewModels: $viewModel.profileViewModels,
                        postThumbnails: $viewModel.postThumbnails,
                        loadThumbnail: viewModel.loadThumbnail,
                        cameraViewModel: cameraViewModel,
                        commentCameraService: commentCameraService
                    )
                    
                case .activityFeed:
                    ActivityFeedView(
                          viewModel: activityFeedViewModel,
                          notificationsViewModel: viewModel, postThumbnails: $viewModel.postThumbnails
                      )
                }
            }
            
            .navigationBarTitle("Notifications", displayMode: .large)
//            .navigationBarTitleColor(.white)
            .accentColor(.white)
            .background(Color(red: 0.94, green: 0.93, blue: 0.91).opacity(0.98))

            .refreshable {
                viewModel.loadNotifications()
            }
            .onAppear {
                viewModel.loadNotifications()
                viewModel.hasNewNotifications = false
                UserDefaults.standard.set(false, forKey: "hasNewNotifications")
            }
        }
    }
}
struct NotificationsListView: View {
    @Binding var notifications: [AppNotification]
    @Binding var profileViewModels: [String: ProfileViewModel]
    @Binding var postThumbnails: [String: UIImage?]
    let loadThumbnail: (String, @escaping (UIImage?) -> Void) -> Void
    @ObservedObject var cameraViewModel: CameraViewModel
    @ObservedObject var commentCameraService: CommentCameraService

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if notifications.isEmpty {
                    Text(NSLocalizedString("Aucune notification", comment: "No notifications message"))
                        .font(.headline)
                        .foregroundColor(.gray)
                        .padding()
                } else {
                    ForEach(Array(notifications.enumerated()), id: \.element.id) { _, notification in
                        if let profileViewModel = profileViewModels[notification.fromUserID] {
                            if let postId = notification.postID {
                                NavigationLink(
                                    destination: SinglePostView(
                                        postId: postId,
                                        cameraViewModel: cameraViewModel,
                                        commentCameraService: commentCameraService
                                    )
                                ) {
                                    NotificationRow(
                                        notification: notification,
                                        postThumbnail: postThumbnails[postId] ?? nil,
                                        loadThumbnail: loadThumbnail,
                                        profileViewModel: profileViewModel
                                    )
                                    .padding(.horizontal, 16)
                                }
                            } else {
                                NotificationRow(
                                    notification: notification,
                                    postThumbnail: nil,
                                    loadThumbnail: loadThumbnail,
                                    profileViewModel: profileViewModel
                                )
                                .padding(.horizontal, 16)
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 16)
        }
        .background(Color(red: 0.94, green: 0.93, blue: 0.91).opacity(0.98))
    }
}



struct NotificationRow: View {
    let notification: AppNotification
    let postThumbnail: UIImage?
    let loadThumbnail: (String, @escaping (UIImage?) -> Void) -> Void
    @ObservedObject  var profileViewModel: ProfileViewModel

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            
            NavigationLink(
                destination: ProfileView(userID: notification.fromUserID, viewModel: profileViewModel)
            ) 
            {
                if let urlStr = notification.fromProfileImageUrl, let url = URL(string: urlStr) {
                    WebImage(url: url)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(notification.fromUsername)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.black)
                Text(bodyText(for: notification)) // Change this line
                    .font(.subheadline)
                    .foregroundColor(.black.opacity(0.7))
                Text(timeAgoSince(notification.timestamp.dateValue()))
                    .font(.caption)
                    .foregroundColor(.black.opacity(0.5))
            }
            
            

            Spacer()
            
            
            if notification.type == "friendRequest" {
                          FriendButton(
                              userID: notification.fromUserID,
                              username: notification.fromUsername,
                              userProfileImageUrl: notification.fromProfileImageUrl ?? "",
                              viewModel: profileViewModel
                          )
                          .padding(.top)
//                          .frame(maxWidth: .infinity, alignment: .trailing)
                      }


            if let postId = notification.postID {
                if let thumbnail = postThumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 40, height: 50)
                        .cornerRadius(10)
                } else {
                    Image(systemName: "photo")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 40, height: 50)
                        .cornerRadius(10)
                        .onAppear {
                            self.loadThumbnail(postId) { thumbnail in
                                // The thumbnail is already updated in the postThumbnails dictionary in the loadThumbnail function
                            }
                        }
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
        .background(Color(white: 1, opacity: 0.8))
        .cornerRadius(15)
        .shadow(color: Color.black.opacity(0.4), radius: 10, x: 2, y: 2)
        
    }
    
    
          func timeAgoSince(_ date: Date) -> String {
                let calendar = Calendar.current
                let now = Date()
                let components = calendar.dateComponents([.second, .minute, .hour, .day, .weekOfYear, .month, .year], from: date, to: now)

                if let years = components.year, years >= 1 {
                    return String(format: NSLocalizedString("il y a %d an%@", comment: "Years ago"), years, years > 1 ? "s" : "")
                }

                if let months = components.month, months >= 1 {
                    return String(format: NSLocalizedString("il y a %d mois", comment: "Months ago"), months)
                }

                if let weeks = components.weekOfYear, weeks >= 1 {
                    return String(format: NSLocalizedString("il y a %d semaine%@", comment: "Weeks ago"), weeks, weeks > 1 ? "s" : "")
                }

                if let days = components.day, days >= 1 {
                    return String(format: NSLocalizedString("il y a %d jour%@", comment: "Days ago"), days, days > 1 ? "s" : "")
                }

                if let hours = components.hour, hours >= 1 {
                    return String(format: NSLocalizedString("il y a %d heure%@", comment: "Hours ago"), hours, hours > 1 ? "s" : "")
                }

                if let minutes = components.minute, minutes >= 1 {
                    return String(format: NSLocalizedString("il y a %d minute%@", comment: "Minutes ago"), minutes, minutes > 1 ? "s" : "")
                }

                if let seconds = components.second, seconds >= 1 {
                    return String(format: NSLocalizedString("il y a %d seconde%@", comment: "Seconds ago"), seconds, seconds > 1 ? "s" : "")
                }

                return NSLocalizedString("à l'instant", comment: "Just now")
            }
            
//    func acceptFriendRequest(friendRequestId: String) {
//        guard let currentUserID = Auth.auth().currentUser?.uid else {
//            print("Error: Could not get the current user ID")
//            return
//        }
//
//        let db = Firestore.firestore()
//
//        // Fetch the current user document
//        let currentUserDocRef = db.collection("users").document(currentUserID)
//        currentUserDocRef.getDocument { (currentUserDocument, error) in
//            if let error = error {
//                print("Error getting current user document: \(error)")
//                return
//            }
//
//            guard let currentUserData = currentUserDocument?.data() else {
//                print("Error: Current user document data is nil")
//                return
//            }
//
//            // Fetch the requesting user document using the friendRequestId
//            let requestingUserDocRef = db.collection("friendRequests").document(friendRequestId)
//            requestingUserDocRef.getDocument { (requestingUserDocument, error) in
//                if let error = error {
//                    print("Error getting requesting user document: \(error)")
//                    return
//                }
//
//                guard let requestingUserData = requestingUserDocument?.data(),
//                      let requestingUserID = requestingUserData["fromUserID"] as? String else {
//                    print("Error: Requesting user document data or ID is nil")
//                    return
//                }
//
//                let currentUserFriendsRef = db.collection("Friends").document(currentUserID)
//                let requestingUserFriendsRef = db.collection("Friends").document(requestingUserID)
//
//                currentUserFriendsRef.getDocument { (currentDocument, error) in
//                    if let error = error {
//                        print("Error getting document: \(error)")
//                        return
//                    }
//
//                    var currentFriends = currentDocument?.data()?["friendsList"] as? [String] ?? []
//
//                    requestingUserFriendsRef.getDocument { (userDocument, error) in
//                        if let error = error {
//                            print("Error getting document: \(error)")
//                            return
//                        }
//
//                        var requestingUserFriends = userDocument?.data()?["friendsList"] as? [String] ?? []
//
//                        currentFriends.append(requestingUserID)
//                        requestingUserFriends.append(currentUserID)
//
//                        currentUserFriendsRef.setData(["friendsList": currentFriends], merge: true) { error in
//                            if let error = error {
//                                print("Error setting data: \(error)")
//                                return
//                            }
//
//                            requestingUserFriendsRef.setData(["friendsList": requestingUserFriends], merge: true) { error in
//                                if let error = error {
//                                    print("Error setting data: \(error)")
//                                    return
//                                }
//
//                                // Remove friend request from the sender's document in the users collection
//                                let friendRequestSenderRef = db.collection("users").document(requestingUserID)
//                                friendRequestSenderRef.updateData(["sentRequests": FieldValue.arrayRemove([currentUserID])]) { error in
//                                    if let error = error {
//                                        print("Error removing sentRequests field from sender's document: \(error.localizedDescription)")
//                                        return
//                                    }
//
//                                    // Remove friend request from the receiver's friendRequests subcollection
//                                    let friendRequestReceiverRef = db.collection("users").document(currentUserID).collection("friendRequests").document(friendRequestId)
//                                    friendRequestReceiverRef.delete() { error in
//                                        if let error = error {
//                                            print("Error deleting friend request from receiver: \(error.localizedDescription)")
//                                            return
//                                        }
//
//                                        // Log the event
//                                        Analytics.logEvent("friendRequest_accepted", parameters: ["user_id": requestingUserID])
//
//                                        // Remove the accepted friend request from the local array (assuming you have one)
//                                        // You might need to update this part based on your data structure
////                                         self.friendRequests.removeAll(where: { $0.id == user.id })
//                                    }
//                                }
//                            }
//                        }
//                    }
//                }
//            }
//        }
//    }



    

    private func bodyText(for notification: AppNotification) -> String {
        switch notification.type {
        case "like":
            return NSLocalizedString("vient d'aimer votre post", comment: "Liked your post")
        case "comment":
            return NSLocalizedString("vient de commenter votre post", comment: "Commented on your post")
        case "friendRequest":
            return NSLocalizedString("vous a envoyé une demande d'ami", comment: "Sent you a friend request")
        case "friendAccepted":
            return NSLocalizedString("a accepté votre demande d'ami", comment: "Accepted your friend request")
        case "reply":
            return NSLocalizedString("a répondu à votre commentaire", comment: "Replied to your comment")
        case "newFriend":
            return NSLocalizedString("vous êtes maintenant ami", comment: "You are now friends")
        case "friendPost":
            return NSLocalizedString("vient de faire un post", comment: "You are now friends")
        case "mention":
            return NSLocalizedString("vient de vous mentionner dans un post", comment: "You are now friends")
        case "poke":
            return NSLocalizedString("vient de vous envoyer un 🫵", comment: "Just sent you a poke")
        case "reaction":
            if let reactionType = notification.reactionType {
                 return NSLocalizedString("vient de réagir \(reactionType) à votre post", comment: "Reacted with {reactionType} to your post")
             } else {
                 return NSLocalizedString("vient de réagir à votre post", comment: "Liked your post")
             }
         default:
             return NSLocalizedString("Notification inconnue", comment: "Unknown notification")
         }
     }
}


struct ActivityFeedView: View {
    @StateObject var viewModel: ActivityFeedViewModel
    @ObservedObject var notificationsViewModel: NotificationsViewModel
    @Binding  var postThumbnails: [String: UIImage?]
    let cameraViewModel = CameraViewModel()
    let commentCameraService = CommentCameraService()

    var body: some View {
        ScrollView {
            if viewModel.activities.isEmpty {
                Text(NSLocalizedString("Aucune activités de vos amis ces dernières 24h", comment: ""))
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(viewModel.activities) { activity in
                        ActivityItemView(
                            activity: activity,
                            viewModel: viewModel,
                            notificationsViewModel: notificationsViewModel, postThumbnail: postThumbnails[activity.targetId ?? ""] ?? nil, cameraViewModel: cameraViewModel,
                            commentCameraService: commentCameraService
                        )
                        .onAppear {
                            notificationsViewModel.loadThumbnail(activity.targetId ?? "") { _ in
                                // Handle the thumbnail loading result
                            }
                        }
                    }
                }
                .padding(.vertical)
                .padding(.horizontal)
            }
        }
        .onAppear {
            viewModel.fetchActivities()
        }
    }
}


struct ActivityItemView: View {
    var activity: Activity
    @StateObject var viewModel: ActivityFeedViewModel
    @ObservedObject var notificationsViewModel: NotificationsViewModel
    let postThumbnail: UIImage?
    @ObservedObject  var cameraViewModel: CameraViewModel
    @ObservedObject  var commentCameraService: CommentCameraService
    @State private var isNavigatingToPost = false


    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if let profileImageUrl = activity.profileImageUrl, let url = URL(string: profileImageUrl) {
                NavigationLink(
                    destination: ProfileView(userID: activity.userId, viewModel: viewModel.getProfileViewModel(for: activity.userId))
                ) {
                    WebImage(url: url)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                }
            } else {
                Circle()
                    .fill(Color.secondary)
                    .frame(width: 40, height: 40)
            }
            
            
            
            VStack(alignment: .leading, spacing: 4) {
                NavigationLink(
                    destination: ProfileView(userID: activity.userId, viewModel: viewModel.getProfileViewModel(for: activity.userId))
                ) {
                    Text(activity.username)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.black)
                        .bold()
                }
                
                activityDescription(for: activity)
                
                if let timestamp = activity.timestamp {
                    Text(timeAgoSince(timestamp))
                        .font(.caption)
                        .foregroundColor(.black.opacity(0.5))
                }
            }
            
            Spacer()
            
            
            
            Button(action: {
                self.isNavigatingToPost = true
            }) {
                if let targetId = activity.targetId, let thumbnail = postThumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 40, height: 50)
                        .cornerRadius(10)
                } else {
                    Image(systemName: "photo")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 40, height: 50)
                        .cornerRadius(10)

                        .onAppear {
                            notificationsViewModel.loadThumbnail(activity.targetId ?? "") { _ in
                                // Handle the thumbnail loading result
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                }
            }
            
            NavigationLink(
                destination: SinglePostView(
                    postId: activity.targetId ?? "",
                    cameraViewModel: cameraViewModel,
                    commentCameraService: commentCameraService
                ),
                isActive: $isNavigatingToPost
            ) {
                EmptyView()
            }

            
            
            
            
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
        .background(Color(white: 1, opacity: 0.8))
        .cornerRadius(15)
        .shadow(color: Color.black.opacity(0.4), radius: 10, x: 2, y: 2)
    }
    

       private func activityDescription(for activity: Activity) -> some View {
             switch activity.type {
             case "like":
                 if let targetUsername = activity.targetUsername, let targetUserId = activity.targetUserId {
                     return AnyView(
                         NavigationLink(
                             destination: ProfileView(userID: targetUserId, viewModel: viewModel.getProfileViewModel(for: targetUserId))
                         ) {
                             VStack(alignment: .leading, spacing: 0) { // Replace HStack with VStack
                                 Text("\(activity.username) a aimé le post de")
                                     .font(.subheadline)
                                     .foregroundColor(.black.opacity(0.7))
                                 HStack {
                                     Text("\(targetUsername)") // Apply bold formatting only to the target username
                                         .font(.subheadline)
                                         .foregroundColor(.black)
                                         .bold()
//                                     Text("'s post") // Add this separate Text view for "'s post" without bold formatting
//                                         .font(.subheadline)
//                                         .foregroundColor(.black.opacity(0.7))
                                 }
                             }
                         }
                     )
                 } else {
                     return AnyView(
                         Text("\(activity.username) liked someone's post.")
                             .font(.subheadline)
                             .foregroundColor(.black.opacity(0.7))
                     )
                 }
             case "comment":
                 if let targetUsername = activity.targetUsername, let targetUserId = activity.targetUserId {
                     return AnyView(
                         VStack(alignment: .leading, spacing: 0) { // Replace HStack with VStack
                             Text("\(activity.username) a commenté sur le post de")
                                 .font(.subheadline)
                                 .foregroundColor(.black.opacity(0.7))
                             NavigationLink(
                                 destination: ProfileView(userID: targetUserId, viewModel: viewModel.getProfileViewModel(for: targetUserId))
                             ) {
                                 HStack {
                                     Text("\(targetUsername)") // Apply bold formatting only to the target username
                                         .font(.subheadline)
                                         .foregroundColor(.black)
                                         .bold()
//                                     Text("'s post") // Add this separate Text view for "'s post" without bold formatting
//                                         .font(.subheadline)
//                                         .foregroundColor(.black.opacity(0.7))
                                 }
                             }
                         }
                     )
                 } else {
                     return AnyView(
                         Text("\(activity.username) commented: \(activity.commentContent ?? "No content")")
                             .font(.subheadline)
                             .foregroundColor(.black.opacity(0.7))
                     )
                 }
             case "newFriend":
                 return AnyView(
                     VStack(alignment: .leading, spacing: 0) { // Replace HStack with VStack
                         Text("\(activity.username) is now friends with ")
                             .font(.subheadline)
                             .foregroundColor(.black.opacity(0.7))
                         Text("\(activity.friendName ?? "")") // Remove the period from here
                             .font(.subheadline)
                             .foregroundColor(.black)
                             .bold()
                     }
                 )
             case "reaction":
                    if let targetUsername = activity.targetUsername, let targetUserId = activity.targetUserId {
                        return AnyView(
                            NavigationLink(
                                destination: ProfileView(userID: targetUserId, viewModel: viewModel.getProfileViewModel(for: targetUserId))
                            ) {
                                VStack(alignment: .leading, spacing: 0) {
                                    if let reactionType = activity.reactionType {
                                        Text("\(activity.username) a réagi \(reactionType) au post de")
                                            .font(.subheadline)
                                            .foregroundColor(.black.opacity(0.7))
                                    } else {
                                        Text("\(activity.username) a réagi au post de")
                                            .font(.subheadline)
                                            .foregroundColor(.black.opacity(0.7))
                                    }
                                    HStack {
                                        Text("\(targetUsername)")
                                            .font(.subheadline)
                                            .foregroundColor(.black)
                                            .bold()
//                                        Text("'s post") /*'s post*/
//                                            .font(.subheadline)
//                                            .foregroundColor(.black.opacity(0.7))
                                    }
                                }
                            }
                        )
                    } else {
                        return AnyView(
                            Text("\(activity.username) a réagi au post de")
                                .font(.subheadline)
                                .foregroundColor(.black.opacity(0.7))
                        )
                    }
                 
             default:
                 return AnyView(
                     Text("Unknown activity")
                         .font(.subheadline)
                         .foregroundColor(.black.opacity(0.7))
                 )
             }
         }
     


    func timeAgoSince(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.second, .minute, .hour, .day, .weekOfYear, .month, .year], from: date, to: now)
        
        if let years = components.year, years >= 1 {
            return String(format: NSLocalizedString("il y a %d an%@", comment: "Years ago"), years, years > 1 ? "s" : "")
        }
        
        if let months = components.month, months >= 1 {
            return String(format: NSLocalizedString("il y a %d mois", comment: "Months ago"), months)
        }
        
        if let weeks = components.weekOfYear, weeks >= 1 {
            return String(format: NSLocalizedString("il y a %d semaine%@", comment: "Weeks ago"), weeks, weeks > 1 ? "s" : "")
        }
        
        if let days = components.day, days >= 1 {
            return String(format: NSLocalizedString("il y a %d jour%@", comment: "Days ago"), days, days > 1 ? "s" : "")
        }
        
        if let hours = components.hour, hours >= 1 {
            return String(format: NSLocalizedString("il y a %d heure%@", comment: "Hours ago"), hours, hours > 1 ? "s" : "")
        }
        
        if let minutes = components.minute, minutes >= 1 {
            return String(format: NSLocalizedString("il y a %d minute%@", comment: "Minutes ago"), minutes, minutes > 1 ? "s" : "")
        }
        
        if let seconds = components.second, seconds >= 1 {
            return String(format: NSLocalizedString("il y a %d seconde%@", comment: "Seconds ago"), seconds, seconds > 1 ? "s" : "")
        }
        
        return NSLocalizedString("à l'instant", comment: "Just now")
    }
}

class ActivityFeedViewModel: ObservableObject {
    @Published var activities: [Activity] = []
    @Published var postThumbnails: [String: UIImage?] = [:]
    @Published var profileViewModels: [String: ProfileViewModel] = [:]
    private let db = Firestore.firestore()
    private let userId: String
    

    let cameraViewModel = CameraViewModel()
    let commentCameraService = CommentCameraService()

    init(userId: String) {
        self.userId = userId
        fetchActivities()
    }

    func fetchActivities() {
          let currentTime = Date()
          let twentyFourHoursAgo = Calendar.current.date(byAdding: .hour, value: -24, to: currentTime)!

          db.collection("activities")
              .whereField("visibleTo", arrayContains: userId)
              .whereField("timestamp", isGreaterThanOrEqualTo: twentyFourHoursAgo)
              .order(by: "timestamp", descending: true)
              .getDocuments { [weak self] (querySnapshot, error) in
                  guard let self = self, let documents = querySnapshot?.documents else {
                      print("No documents or an error occurred")
                      return
                  }

                  let newActivities = documents.compactMap { document in
                      do {
                          var activity = try document.data(as: Activity.self)
                          activity.id = document.documentID
                          return activity
                      } catch {
                          print("Error decoding activity: \(error)")
                          return nil
                      }
                  }

                  DispatchQueue.main.async {
                      self.activities = newActivities
                      self.loadThumbnails()
                  }
              }
      }

      func loadThumbnails() {
          let postIds = activities.compactMap { $0.targetId }

          // Load thumbnails for all posts
          postIds.forEach { postId in
              loadThumbnail(postId) { _ in }
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


    func getProfileViewModel(for userId: String) -> ProfileViewModel {
        if let viewModel = profileViewModels[userId] {
            return viewModel
        } else {
            let newViewModel = ProfileViewModel(userID: userId)
            profileViewModels[userId] = newViewModel
            return newViewModel
        }
    }    
    
    func loadPostThumbnail(_ postId: String, completion: @escaping (UIImage?) -> Void) {
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





    
//    func loadThumbnails() {
//        let postIds = activities.compactMap { $0.id }
//
//        // Load thumbnails for all posts
//        postIds.forEach { postId in
//            loadThumbnail(postId) { _ in }
//        }
//    }
}

struct Activity: Identifiable, Codable {
    var id: String?
    var type: String
    var userId: String
    var username: String
    var targetId: String?
    var targetUsername: String?
    var targetUserId: String?
    var commentId: String?
    var commentContent: String?
    var timestamp: Date?
    var friendName: String?
    var profileImageUrl: String?
    var postThumbnailUrl: String?
    var reactionType: String?

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case userId
        case username
        case targetId
        case targetUsername
        case targetUserId
        case commentId
        case commentContent
        case timestamp
        case friendName
        case profileImageUrl
        case postThumbnailUrl
        case reactionType
    }
}
