//
//  CommentView.swift
//  brief.brief
//
//  Created by Philippe Tchinda on 05/07/2023.
//

import SwiftUI
import UIKit
import Firebase
import FirebaseFirestore
import FirebaseStorage
import SDWebImageSwiftUI
import Combine
import FirebaseAnalytics
import SwipeActions
import Nuke


struct CommentImageView: View {
    var imageUrl: String?
    @State private var uiImage: UIImage? = nil
    @State private var isLoading = true
    @State private var loadFailed = false
    @State private var secondUIImage: UIImage? = nil
    var secondImageUrl: String?
    @State private var secondUIImagePosition: CGSize = .zero

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(LinearProgressViewStyle())
                        .frame(width: geometry.size.width, height: geometry.size.width * 1.95)
                } else if let uiImage = uiImage {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.width * 1.95)
                        .clipped()
                        .overlay(
                            Group {
                                if let secondUIImage = secondUIImage {
                                    Image(uiImage: secondUIImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: geometry.size.width / 2.2, height: geometry.size.height / 2.5)
                                        .cornerRadius(15)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 15)
                                                .stroke(Color.white, lineWidth: 2)
                                        )
                                        .padding(4)
                                        .position(x: geometry.size.width - geometry.size.width / 4 - 15 + secondUIImagePosition.width,
                                                  y: geometry.size.height / 6 + 30 + secondUIImagePosition.height)
                                        .gesture(
                                            DragGesture(minimumDistance: 0, coordinateSpace: .local)
                                                .onChanged { value in
                                                    self.secondUIImagePosition = value.translation
                                                }
                                                .onEnded { _ in
                                                    self.secondUIImagePosition = .zero
                                                }
                                                .simultaneously(with: TapGesture()
                                                .onEnded { _ in
                                                    let temp = self.uiImage
                                                    self.uiImage = self.secondUIImage
                                                    self.secondUIImage = temp
                                                    Haptics.shared.play(.light)
                                                }
                                        )
                                    )
                                }
                            }
                        )
                } else if loadFailed {
                    Image(systemName: "photo")
                        .foregroundColor(.gray)
                }
            }
        }
        .cornerRadius(25)
        .onAppear {
            loadImages()
        }
        .frame(height: UIScreen.main.bounds.width * 1.3)
    }

    private func loadImages() {
        guard let imageUrl = imageUrl, let url = URL(string: imageUrl) else {
            isLoading = false
            loadFailed = true
            return
        }

        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let data = data, let image = UIImage(data: data) {
                DispatchQueue.main.async {
                    self.uiImage = image
                    self.isLoading = false
                }

                if let secondImageUrl = secondImageUrl, let url = URL(string: secondImageUrl) {
                    let task = URLSession.shared.dataTask(with: url) { data, response, error in
                        if let data = data, let image = UIImage(data: data) {
                            DispatchQueue.main.async {
                                self.secondUIImage = image
                            }
                        }
                    }
                    task.resume()
                }
            } else {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.loadFailed = true
                }
            }
        }
        task.resume()
    }
    
    class Haptics {
        static let shared = Haptics()
        
        private init() { }
        
        func play(_ feedbackStyle: UIImpactFeedbackGenerator.FeedbackStyle) {
            UIImpactFeedbackGenerator(style: feedbackStyle).impactOccurred()
        }
        
        func notify(_ feedbackType: UINotificationFeedbackGenerator.FeedbackType) {
            UINotificationFeedbackGenerator().notificationOccurred(feedbackType)
        }
    }
}


struct CommentView: View {
    @State private var commentText = ""
    @State private var comments: [Comment] = []
    let post: UserPost
    let username: String
    @State private var mentionedUsernames: [String] = []
    @State private var replyToUsername: String?
    @State private var currentUsername: String = ""
    @State private var likesCount: Int = 0
    @State private var isLiked: Bool = false
    @StateObject private var audioRecorder = AudioRecorder()
    @StateObject var viewModel: CommentCameraViewModel 
    let postId: String
    var CommentcameraService: CommentCameraService
    @State public var friends: [User] = []
    private let db = Firestore.firestore()
    
    
    
    
    var body: some View {
        NavigationView {
            VStack(spacing: 10) {
                // Comments title
                Text(NSLocalizedString("Commentaires", comment: "Title for the comment section"))
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .foregroundColor(.black)
                Divider() // Add a divider below each comment
                
                
                
                // Comments list
                // Inside your ScrollView where you're listing comments
                ScrollView {
                    LazyVStack(spacing: 5) {
                        ForEach(comments) { comment in
                            CommentCell(comment: comment, replyToUsername: $replyToUsername, commentText: $commentText, deleteAction: {
                                // Call your deleteComment function here with the comment's ID
                                self.deleteComment(comment.id)
                            })
                         
                        }
                    }
                    .padding(.horizontal)

                }
                
                
                
                
                // Chat input view
                
                ChatInputView(
                    commentText: $commentText,
                    onSubmit: { submitComment() },
                    onVoiceRecordComplete: { recordingURL in
                        guard let recordingURL = recordingURL else { return }
                        self.submitAudioComment(audioURL: recordingURL)
                    },
                    CommentcameraService: CommentcameraService,
                    post: post, currentUsername: currentUsername
                )
                .environmentObject(audioRecorder)


                Spacer()
            }
            .background(Color(red: 0.94, green: 0.93, blue: 0.91).opacity(0.98))
            .navigationBarHidden(true)
            
            
            .onAppear {
                fetchComments()
                fetchCurrentUserUsername()
//                fetchFriends()
                
                
            }
        }
    }
    
    
    
    
    struct CommentCell: View {
        let comment: Comment
        @Binding var replyToUsername: String?
        @Binding var commentText: String
        @State private var likesCount: Int = 0
        @State private var isLiked: Bool = false
        var deleteAction: () -> Void

        var body: some View {
            HStack(alignment: .top, spacing: 10) {
                NavigationLink(destination: ProfileView(userID: comment.userUID, viewModel: ProfileViewModel(userID: comment.userUID))) {
                    if let imageUrl = comment.profileImageUrl {
                        WebImage(url: imageUrl)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 30, height: 30)
                            .clipShape(Circle())
                    } else {
                        Circle()
                            .frame(width: 30, height: 30)
                            .foregroundColor(.gray)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.leading, 10)

                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(comment.username)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.black)

                        Spacer()
                        
                        Text(comment.displayTimestamp)
                            .font(.caption)
                            .foregroundColor(.gray)

                        Menu {
                            if comment.userUID == Auth.auth().currentUser?.uid {
                                Button(role: .destructive, action: deleteAction) {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .foregroundColor(.gray)
                        }

                        
                    }
                    

                    Text(comment.text)
                        .font(.system(size: 14))
                        .foregroundColor(.black)
                        .fixedSize(horizontal: false, vertical: true)

                    if let audioURL = comment.audioURL {
                        AudioVisualization(audioURL: audioURL)
                            .padding(.bottom, 10)
                    }

                    VStack(alignment: .leading, spacing: 5) {
                                        ForEach(Array(zip(comment.photoURL, comment.photoURL.dropFirst())), id: \.0) { photoURL, secondPhotoURL in
                                            CommentImageView(imageUrl: photoURL, secondImageUrl: secondPhotoURL)
                                        }
                                    }

                    Button(NSLocalizedString("Répondre", comment: "Reply button text")) {
                        self.replyToUsername = comment.username
                        self.commentText = "@\(comment.username) "
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
                
                

                Spacer(minLength: 0)
            }
            .padding(.all, 8)
            .background(Color(white: 1, opacity: 0.8))
            .cornerRadius(10)
            .shadow(color: Color.black.opacity(0.2), radius: 10, x: 2, y: 2)
            .padding(.horizontal, 5)
        }
    }
    
    private func likeOrUnlikeComment(commentID: String, currentUserID: String) {
        let db = Firestore.firestore()
        let commentRef = db.collection("comments").document(commentID)
        let likeRef = commentRef.collection("likes").document(currentUserID)
        
        db.runTransaction({ (transaction, errorPointer) -> Any? in
            let commentDocument: DocumentSnapshot
            do {
                try commentDocument = transaction.getDocument(commentRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }
            
            guard let oldLikesCount = commentDocument.data()?["likesCount"] as? Int else {
                let error = NSError(domain: "AppErrorDomain", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "Unable to retrieve likes count from snapshot \(commentDocument)"
                ])
                errorPointer?.pointee = error
                return nil
            }
            
            if isLiked {
                transaction.updateData(["likesCount": oldLikesCount - 1], forDocument: commentRef)
                transaction.deleteDocument(likeRef)
            } else {
                transaction.updateData(["likesCount": oldLikesCount + 1], forDocument: commentRef)
                transaction.setData([:], forDocument: likeRef)
            }
            
            return nil
        }) { (object, error) in
            if let error = error {
                print("Transaction failed: \(error)")
            } else {
                print("Transaction successfully committed!")
                self.isLiked.toggle() // Ensure this is executed on the main thread if necessary
                self.likesCount += self.isLiked ? 1 : -1
            }
        }
    }
    
    private func fetchLikeStatusAndCount(commentID: String, currentUserID: String) {
        let db = Firestore.firestore()
        let commentRef = db.collection("comments").document(commentID)
        
        // Fetch like count
        commentRef.getDocument { (document, error) in
            if let document = document, document.exists, let data = document.data() {
                if let likesCount = data["likesCount"] as? Int {
                    DispatchQueue.main.async {
                        self.likesCount = likesCount
                    }
                }
            } else {
                print("Document does not exist or failed to fetch likes count")
            }
        }
        
        // Check if the current user has liked the comment
        commentRef.collection("likes").document(currentUserID).getDocument { (document, error) in
            if let document = document, document.exists {
                DispatchQueue.main.async {
                    self.isLiked = true
                }
            } else {
                DispatchQueue.main.async {
                    self.isLiked = false
                }
            }
        }
    }
    
    
    
    struct ChatInputView: View {
        @Binding var commentText: String
        var onSubmit: () -> Void
        
        @State private var dragOffset = CGSize.zero
        @State private var cancelRecording = false
        let darkGray = Color(red: 0.15, green: 0.15, blue: 0.15)
        @StateObject private var audioRecorder = AudioRecorder()
        var onVoiceRecordComplete: (URL?) -> Void
        @EnvironmentObject var friendsData: FriendsData
        @State private var showFriendPicker = false
        @State private var showBin = false
        @State private var friendFilterText = ""
        @State private var showCameraView = false
        var CommentcameraService: CommentCameraService
        var post: UserPost
        @State private var dynamicHeight: CGFloat = 36
        @State  var currentUsername: String
        @State private var friends: [User] = []

        
        
        var body: some View {
            HStack {
                // Camera button
                Button(action: {
                    showCameraView.toggle()
                }) {
                    Image(systemName: "camera.fill")
                        .foregroundColor(.white)
                }
                .padding(10)
                .background(Color.purple)
                .clipShape(Circle())
                
                // Text field inside a ZStack
                VStack {
                    ZStack(alignment: .leading) {
                        if commentText.isEmpty {
                            Text(NSLocalizedString("Écrire un commentaire", comment: ""))
                                .foregroundColor(darkGray)
                                .padding(.leading, 10)
                        }
                        TextField("", text: $commentText)
                            .foregroundColor(.black)
                            .padding(.leading, 10)
                    }
                    .background(Color(red: 244/255, green: 244/255, blue: 243/255))
                    .cornerRadius(8)
                    .frame(maxWidth: .infinity)
                }
                    
                
                
                
                // Voice record and send buttons
                HStack(spacing: 0) {
                    if showBin {
                        Button(action: {}) { // Replace with your delete action
                            Image(systemName: "trash")
                                .foregroundColor(.blue)
                                .padding(10)
                        }
                        .transition(.move(edge: .leading))
                    }
                    
                    VoiceRecordButton(onVoiceRecordComplete: onVoiceRecordComplete)
                    .environmentObject(audioRecorder)
                    
                    Button(action: onSubmit) {
                        Image(systemName: "paperplane.fill")
                            .foregroundColor(.white)
                            .padding(10)
                    }
                    .background(Color(red: 0.07, green: 0.04, blue: 1))
                    .clipShape(Circle())
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color(white: 1, opacity: 0.8))
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.2), radius: 10, x: 2, y: 2)
            .onChange(of: commentText) { newValue in
                showFriendPicker = newValue.contains("@")
                updatePickerState(with: newValue)
            }

            
            
        
            
            if showCameraView {
                CommentCameraView(
                    isShown: $showCameraView,
                    commentCameraService: CommentcameraService,
                    post: post,
                    currentUsername: currentUsername
                )
            }

                
            

//            if showFriendPicker {
//                FriendPickerView(commentText: $commentText, friends: friends, friendFilterText: friendFilterText, showFriendPicker: $showFriendPicker)
//            }
        }
    

    private func updatePickerState(with text: String) {
        if let lastAtSymbolIndex = text.lastIndex(of: "@"),
           lastAtSymbolIndex < text.endIndex {
            showFriendPicker = true
            friendFilterText = String(text[text.index(after: lastAtSymbolIndex)...])
        } else {
            showFriendPicker = false
        }
    }
}
    
    // Function to fetch a single user
    private func fetchUser(by id: String, completion: @escaping (User?) -> Void) {
        db.collection("users").document(id).getDocument { (snapshot, error) in
            guard let userData = snapshot?.data(),
                              let username = userData["username"] as? String,
                              let firstName = userData["firstName"] as? String,
                              let lastName = userData["lastName"] as? String else {
                            completion(nil)
                            return
                        }
                        
                        let profileImageUrl = userData["profileImageUrl"] as? String
                        let name = userData["name"] as? String
                        let friends = userData["friends"] as? [String]
                        let friendRequestsSent = userData["friendRequestsSent"] as? [String]
                        
                        let user = User(id: id, username: username, firstName: firstName, lastName: lastName, isInvited: false, name: name, friends: friends, friendRequestsSent: friendRequestsSent, profileImageUrl: profileImageUrl)
                        
                        completion(user)
                    }
                }
    
    func deleteFriend(_ user: User) {
            guard let currentUserID = Auth.auth().currentUser?.uid else { return }
        
        // Remove each other from friends lists in the Friends collection
        let currentUserFriendsRef = db.collection("Friends").document(currentUserID)
        currentUserFriendsRef.updateData(["friendsList": FieldValue.arrayRemove([user.id])]) { _ in
            // Remove the deleted friend from the local array
            self.friends.removeAll(where: { $0.id == user.id })
        }
        
        // Log the friend deletion event
                Analytics.logEvent("friend_deleted", parameters: [
                    "deleted_friend_id": user.id ?? "unknown",
                    "current_user_id": currentUserID
                ])
            
        
        let userFriendsRef = db.collection("Friends").document(user.id)
        userFriendsRef.updateData(["friendsList": FieldValue.arrayRemove([currentUserID])])
    }

    // Function to fetch friends
    func fetchFriends() {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }
        
        let friendsRef = db.collection("Friends").document(currentUserID)
        
        // Listen for real-time updates
        friendsRef.addSnapshotListener { snapshot, error in
            if let error = error {
                print("Error fetching friends: \(error)")
                return
            }
            
            guard let friendsList = snapshot?.data()?["friendsList"] as? [String] else { return }
            
            let group = DispatchGroup()
            var fetchedFriends = [User]()
            
            for id in friendsList {
                group.enter()
                self.fetchUser(by: id) { user in
                    if let user = user {
                        fetchedFriends.append(user)
                    }
                    group.leave()
                }
            }
            
            group.notify(queue: .main) {
                self.friends = fetchedFriends
                print("Friends: \(self.friends)")
            }
        }
    }
 

    
    struct FriendPickerView: View {
           @Binding var commentText: String
           var friends: [User]
           var friendFilterText: String
           @Binding var showFriendPicker: Bool
           
           var body: some View {
               List(filteredFriends, id: \.id) { friend in
                   HStack {
                       if let imageUrl = URL(string: friend.profileImageUrl ?? "") {
                           WebImage(url: imageUrl)
                               .resizable()
                               .aspectRatio(contentMode: .fill)
                               .frame(width: 40, height: 40)
                               .clipShape(Circle())
                       } else {
                           Circle()
                               .frame(width: 40, height: 40)
                               .foregroundColor(.gray)
                       }
                       Text(friend.username)
                           .onTapGesture {
                               if commentText.last != "@" {
                                   commentText.removeLast()
                               }
                               self.commentText += "\(friend.username) "
                               self.showFriendPicker = false
                           }
                   }
               }
           }
           
           var filteredFriends: [User] {
               if friendFilterText.isEmpty {
                   return friends
               } else {
                   return friends.filter { $0.username.lowercased().contains(friendFilterText.lowercased()) }
               }
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
        var secondPhotoURL: String? // Add this line



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
                 "photoURL": photoURL,
                 "secondPhotoURL": secondPhotoURL

             ]
         }
     }


    private func findMentionedUsernames(in text: String) -> [String] {
        let regex = try! NSRegularExpression(pattern: "(?<!\\w)@(\\w+\\.?\\w+)")
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))

        let usernames = matches.map { match in
            String(text[Range(match.range(at: 1), in: text)!])
        }

        return usernames
    }

    private func fetchComments() {
        Firestore.firestore()
            .collection("posts")
            .document(post.id ?? "")
            .collection("comments")
            .order(by: "timestamp", descending: false)
            .addSnapshotListener { (snapshot, error) in
                guard let documents = snapshot?.documents else {
                    print("Error fetching comments: \(error?.localizedDescription ?? "")")
                    return
                }

                var newComments: [String: Comment] = [:]
                let dispatchGroup = DispatchGroup()

                for document in documents {
                    dispatchGroup.enter()
                    let data = document.data()
                    let docID = document.documentID
                    let userUID = data["userUID"] as? String ?? ""
                    let username = data["username"] as? String ?? ""
                    let text = data["text"] as? String ?? ""
                    let timestamp = data["timestamp"] as? Timestamp
                    let commentTimestamp = timestamp?.dateValue() ?? Date()
                    let mentionedUsernames = data["mentionedUsernames"] as? [String] ?? []
                    let audioURLString = data["audioURL"] as? String // Assuming audioURL is a String in Firestore
                    let photoURLs = data["photoURL"] as? [String] ?? [] // Extracting photo URLs

                    // Fetch audioURL if available
                    let audioURL: URL? = audioURLString != nil ? URL(string: audioURLString!) : nil

                    fetchUserProfileImageURL(userUID: userUID) { url in
                        let comment = Comment(userUID: userUID, username: username, text: text, timestamp: commentTimestamp, profileImageUrl: url, mentionedUsernames: mentionedUsernames, audioURL: audioURL, photoURL: photoURLs)
                        newComments[docID] = comment
                        dispatchGroup.leave()
                    }
                }

                dispatchGroup.notify(queue: .main) {
                    // Sort based on document IDs or timestamps and update `self.comments`
                    self.comments = Array(newComments.values).sorted(by: { $0.timestamp < $1.timestamp })
                }
            }
    }





    private func fetchUserProfileImageURL(userUID: String, completion: @escaping (URL?) -> Void) {
        Firestore.firestore()
            .collection("users")
            .document(userUID)
            .getDocument { snapshot, error in
                guard let data = snapshot?.data(),
                      let profileImageUrlString = data["profileImageUrl"] as? String,
                      let profileImageUrl = URL(string: profileImageUrlString) else {
                    completion(nil)
                    return
                }

                completion(profileImageUrl)
            }
    }
    
    private func fetchCurrentUserUsername() {
        // Fetch current user's username
        let currentUser = Auth.auth().currentUser
        if let currentUser = currentUser {
            Firestore.firestore()
                .collection("users")
                .document(currentUser.uid)
                .getDocument { (document, error) in
                    if let document = document, document.exists, let data = document.data() {
                        self.currentUsername = data["username"] as? String ?? ""
                    }
                }
        }
    }
    

    private func submitComment() {
        guard let currentUserID = Auth.auth().currentUser?.uid else {
            return
        }
        
        var isTextCommentSubmitted = false
        
        // Handle text comment submission
        if !commentText.isEmpty {
            let textComment = Comment(userUID: currentUserID, username: currentUsername, text: commentText, timestamp: Date(), profileImageUrl: nil, mentionedUsernames: mentionedUsernames, audioURL: nil, photoURL: [])
            uploadComment(textComment)
            commentText = ""
            mentionedUsernames = []
            isTextCommentSubmitted = true
        }
        
        // Handle audio comment submission
        if let recordingURL = audioRecorder.recordingURL {
            uploadAudioFile(url: recordingURL) { result in
                switch result {
                case .success(let downloadURL):
                    let audioCommentText = isTextCommentSubmitted ? "" : commentText
                    let audioComment = Comment(userUID: currentUserID, username: currentUsername, text: audioCommentText, timestamp: Date(), profileImageUrl: nil, mentionedUsernames: mentionedUsernames, audioURL: downloadURL, photoURL: [])
                    uploadComment(audioComment)
                    self.resetCommentInput() // Reset text and recording after audio upload
                case .failure(let error):
                    print("Error uploading audio file: \(error.localizedDescription)")
                    self.resetCommentInput() // Reset text and recording if there's an error
                }
            }
            audioRecorder.recordingURL = nil // Reset the recording URL
        } else if isTextCommentSubmitted {
            resetCommentInput() // Reset text if only text comment was submitted
        }
    }

    private func submitAudioComment(audioURL: URL) {
        guard let currentUserID = Auth.auth().currentUser?.uid else {
            return
        }
        uploadAudioFile(url: audioURL) { result in
            switch result {
            case .success(let downloadURL):
                let audioComment = Comment(userUID: currentUserID, username: currentUsername, text: "", timestamp: Date(), profileImageUrl: nil, mentionedUsernames: [], audioURL: downloadURL, photoURL: [])
                uploadComment(audioComment)
            case .failure(let error):
                print("Error uploading audio file: \(error.localizedDescription)")
            }
        }
    }

    
    
    
    
    private func resetCommentInput() {
        commentText = ""
        mentionedUsernames = []
        // Add any additional reset logic if needed
    }
    
    
    
    
    private func uploadComment(_ comment: Comment) {
        Firestore.firestore()
            .collection("posts")
            .document(post.id ?? "")
            .collection("comments")
            .addDocument(data: comment.dictionary) { error in
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
    
    
    // CommentView.swift - Add this function
    private func deleteComment(_ commentId: UUID) {
        let commentIdString = commentId.uuidString // Convert UUID to String
        guard let postId = post.id else {
            print("Post ID is nil")
            return
        }
        
        // Assuming 'postId' is correct and exists
        Firestore.firestore().collection("posts").document(postId)
            .collection("comments").document(commentIdString).delete { error in
                if let error = error {
                    // Consider showing this error to the user or handling it accordingly
                    print("Error removing comment document: \(error.localizedDescription)")
                } else {
                    // Success, the document has been removed
                    print("Comment document successfully removed!")
                    // Perform UI update on main thread if necessary
                    DispatchQueue.main.async {
                        self.comments.removeAll { $0.id == commentId }
                    }
                }
        }
    }

    
    
    func uploadAudioFile(url: URL, completion: @escaping (Result<URL, Error>) -> Void) {
        let ref = Storage.storage().reference().child("audioComments/\(UUID().uuidString).m4a")
        ref.putFile(from: url, metadata: nil) { metadata, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            ref.downloadURL { url, error in
                if let url = url {
                    completion(.success(url))
                } else if let error = error {
                    completion(.failure(error))
                }
            }
        }
    }
}


func splitCommentText(_ text: String) -> [String] {
    let pattern = "(@\\w+)|(\\s+)|(\\w+)"
    let regex = try! NSRegularExpression(pattern: pattern, options: [])
    let range = NSRange(text.startIndex..., in: text)
    
    var segments = [String]()
    
    regex.enumerateMatches(in: text, options: [], range: range) { (match, _, _) in
        guard let match = match else { return }
        
        for rangeIndex in 1..<match.numberOfRanges {
            let matchRange = match.range(at: rangeIndex)
            
            if matchRange.length > 0, let substringRange = Range(matchRange, in: text) {
                let matchString = String(text[substringRange])
                segments.append(matchString)
            }
        }
    }
    
    return segments.filter { !$0.isEmpty }
}

