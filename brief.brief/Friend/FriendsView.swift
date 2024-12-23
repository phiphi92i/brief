//
//  FriendsView.swift
//  brief.brief
//
//  Created by Philippe Tchinda on 20/02/2024.
//

import Foundation
import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseAnalytics
import SDWebImageSwiftUI



struct FriendsView: View {
    
    
    let db = Firestore.firestore()
    @State private var friends = [User]()
    @State private var friendRequests = [User]()
    @State public var hasNewFriendRequests: Bool = false  //
    @State private var isRequestSent = false
    @State private var users = [User]()
    @State private var selectedUsers = Set<String>()
    
    
    
    
    
    var body: some View {
        ZStack {
            VStack {
                VStack(spacing: 0) {
                    // Algolia search results view
                    
                    VStack(spacing: 8) {
                        Text(String(format: NSLocalizedString("Demandes d'amis (%d)", comment: "Friend Requests title"), friendRequests.count))
                            .font(.headline)
                            .foregroundColor(.black)
                            .padding(.leading, 16)
                            .padding(.trailing, 16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        ScrollView {
                            LazyVStack(spacing: 8) {
                                ForEach(friendRequests) { user in
                                    FriendRequestCard(user: user, acceptAction: acceptFriendRequest, denyAction: denyFriendRequest)
                                        .padding(.horizontal, 16)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                        .frame(width: UIScreen.main.bounds.width * 0.931, height: UIScreen.main.bounds.height * 0.223)
                        
                        .background(Color(red: 0.94, green: 0.93, blue: 0.91).opacity(0.98))
                        .cornerRadius(6)
                        
                        // New section for list of friends
                        Text(String(format: NSLocalizedString("Mes amis (%d)", comment: "My Friends title"), friends.count))
                            .font(.headline)
                            .foregroundColor(.black)
                            .padding(.leading, 16)
                            .padding(.trailing, 16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        ScrollView {
                            LazyVStack(spacing: 8) {
                                ForEach(friends) { friend in
                                    FriendsListCard(user: friend, deleteAction: deleteFriend)
                                        .padding(.horizontal, 16)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                        .frame(width: UIScreen.main.bounds.width * 0.931, height: UIScreen.main.bounds.height * 0.45)
                        .background(Color(red: 0.94, green: 0.93, blue: 0.91).opacity(0.98))
                        .cornerRadius(6)
                    }
                    .padding(.top, 16)
                    
                    .onAppear {
                        fetchFriendRequests()
                        fetchFriends()
                    }
                }
            }
            
        }
    }
    
    
    
    
    
    
    
    // Fetch the list of friend requests
    func fetchFriendRequests() {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }
        
        let friendRequestsRef = db.collection("users").document(currentUserID).collection("friendRequests")
        friendRequestsRef.getDocuments { snapshot, error in
            if let error = error {
                print("Error fetching friend requests: \(error.localizedDescription)")
            } else if let snapshotDocuments = snapshot?.documents {
                let group = DispatchGroup()
                var fetchedRequests = [User]()
                
                for document in snapshotDocuments {
                    if let id = document.data()["fromUserId"] as? String {  // Use "fromUserId" instead of "id"
                        group.enter()
                        
                        db.collection("users").document(id).getDocument { (userSnapshot, userError) in
                            if let userError = userError {
                                print("Error fetching user: \(userError.localizedDescription)")
                                group.leave()
                            } else if let userData = userSnapshot?.data(),
                                      let username = userData["username"] as? String,
                                      let firstName = userData["firstName"] as? String,
                                      let lastName = userData["lastName"] as? String {
                                
                                let profileImageUrl = userData["profileImageUrl"] as? String  // Make this optional
                                let name = userData["name"] as? String
                                let friends = userData["friends"] as? [String]
                                
                                
                                
                                let user = User(id: id, username: username, firstName: firstName, lastName: lastName, isInvited: false, name: name, friends: friends, friendRequestsSent: nil, profileImageUrl: profileImageUrl)  // Include profileImageUrl, even if it's nil
                                
                                fetchedRequests.append(user)
                                group.leave()
                            }
                        }
                    }
                }
                
                group.notify(queue: .main) {
                    self.friendRequests = fetchedRequests
                    self.hasNewFriendRequests = !self.friendRequests.isEmpty  // Update this line
                }
            }
        }
    }
    
    
    func resetNewFriendRequestsFlag() {
        self.hasNewFriendRequests = false
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
    
    
    // Accept a friend request
    func acceptFriendRequest(_ user: User) {
        guard let currentUserID = Auth.auth().currentUser?.uid else {
            print("Error: Could not get the current user ID")
            return
        }
        
        let db = Firestore.firestore()
        
        let currentUserFriendsRef = db.collection("Friends").document(currentUserID)
        let userFriendsRef = db.collection("Friends").document(user.id)
        
        currentUserFriendsRef.getDocument { (currentDocument, error) in
            if let error = error {
                print("Error getting document: \(error)")
                // Handle the error, possibly by showing an alert to the user
                return
            }
            
            var currentFriends = currentDocument?.data()?["friendsList"] as? [String] ?? []
            
            userFriendsRef.getDocument { (userDocument, error) in
                if let error = error {
                    print("Error getting document: \(error)")
                    // Handle the error, possibly by showing an alert to the user
                    return
                }
                
                var userFriends = userDocument?.data()?["friendsList"] as? [String] ?? []
                
                currentFriends.append(user.id)
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
                        let friendRequestSenderRef = db.collection("users").document(user.id)
                        friendRequestSenderRef.updateData(["sentRequests": FieldValue.arrayRemove([currentUserID])]) { error in
                            if let error = error {
                                print("Error removing sentRequests field from sender's document: \(error.localizedDescription)")
                                return
                            }
                            
                            // Remove friend request from the receiver's friendRequests subcollection
                            let friendRequestReceiverRef = db.collection("users").document(currentUserID).collection("friendRequests").document(user.id)
                            friendRequestReceiverRef.delete() { error in
                                if let error = error {
                                    print("Error deleting friend request from receiver: \(error.localizedDescription)")
                                    return
                                }
                                
                                // Log the event
                                Analytics.logEvent("friendRequest_accepted", parameters: ["user_id": user.id ])
                                
                                // Remove the accepted friend request from the local array (assuming you have one)
                                self.friendRequests.removeAll(where: { $0.id == user.id })
                            }
                        }
                    }
                }
            }
        }
    }
    
    
    
    
    
    
    
    func cancelFriendRequest(_ user: User) {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }
        
        // Remove the friend request
        let friendRequestRef = db.collection("users").document(user.id).collection("friendRequests").document(currentUserID)
        friendRequestRef.delete() { _ in
            self.selectedUsers.remove(user.id)
            // Remove the receiver from the sentRequests array of the current user
            let currentUserRef = db.collection("users").document(currentUserID)
            currentUserRef.updateData(["sentRequests": FieldValue.arrayRemove([user.id])])
        }
    }
    
    
    
    // Deny a friend request
    func denyFriendRequest(_ user: User) {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }
        
        // Remove friend request from Firestore
        let friendRequestRef = db.collection("users").document(currentUserID).collection("friendRequests").document(user.id)
        friendRequestRef.delete() { _ in
            // Remove the denied friend request from the local array
            self.friendRequests.removeAll(where: { $0.id == user.id })
            
            // Remove the friend request from the sender's "sentRequests" subcollection
            let senderDocRef = db.collection("users").document(currentUserID)
            senderDocRef.updateData(["sentRequests": FieldValue.arrayRemove([user.id])]) { error in
                if let error = error {
                    print("Error removing friend request from sender's sentRequests: \(error.localizedDescription)")
                    // Handle the error, possibly by showing an alert to the user
                    return
                }
                
                // Log event when friend request is successfully denied, deleted, and removed from sender's sentRequests
                Analytics.logEvent("friendRequest_denied", parameters: ["user_id": user.id ])
            }
            
            // Log event when friend request is successfully denied and deleted
            Analytics.logEvent("friendRequest_denied", parameters: ["user_id": user.id ])
        }
    }
    
    
    
    
    struct FriendRequestCard: View {
        let user: User
        let acceptAction: (User) -> Void
        let denyAction: (User) -> Void
        @StateObject var profileViewModel: ProfileViewModel  // Use @StateObject
        
        init(user: User, acceptAction: @escaping (User) -> Void, denyAction: @escaping (User) -> Void) {
            self.user = user
            self.acceptAction = acceptAction
            self.denyAction = denyAction
            _profileViewModel = StateObject(wrappedValue: ProfileViewModel(userID: user.id))  // Initialize ProfileViewModel here
        }
        
        var body: some View {
            HStack {
                Button(action: {}) {
                    NavigationLink(destination: ProfileView(userID: user.id, viewModel: profileViewModel)) {
                        profileImageView(user: user)
                    }
                }
                
                VStack(alignment: .leading) {
                    Text(user.username)
                        .font(.headline)
                        .foregroundColor(.black)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Button(action: {
                    acceptAction(user)
                }) {
                    Text(NSLocalizedString("Accepter", comment: ""))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .foregroundColor(.white)
                        .background(Color.green)
                        .cornerRadius(10)
                }
                
                Button(action: {
                    denyAction(user)
                }) {
                    Image(systemName: "xmark")
                        .padding()
                        .foregroundColor(.black)
                }
            }
        }
        
        private func profileImageView(user: User) -> some View {
            if let imageUrl = URL(string: user.profileImageUrl ?? "") {
                return WebImage(url: imageUrl)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
                    .eraseToAnyView()
            } else {
                return Text(String(user.username.prefix(1)).uppercased())
                    .font(.system(size: 25, weight: .bold))
                    .frame(width: 50, height: 50)
                    .background(Color.gray.opacity(0.3))
                    .clipShape(Circle())
                    .eraseToAnyView()
            }
        }
    }
    
    
    
    struct FriendsListCard: View {
        let user: User
        let deleteAction: (User) -> Void  // Closure to handle deletion
        
        @State private var showingDeleteAlert = false
        @StateObject var profileViewModel: ProfileViewModel
        
        init(user: User, deleteAction: @escaping (User) -> Void) {
            self.user = user
            self.deleteAction = deleteAction
            _profileViewModel = StateObject(wrappedValue: ProfileViewModel(userID: user.id))
        }
        
        var body: some View {
            HStack {
                Button(action: {}) {
                    NavigationLink(destination: ProfileView(userID: user.id, viewModel: profileViewModel)) {
                        profileImageView(user: user)
                    }
                }
                
                VStack(alignment: .leading) {
                    Text(user.username)
                        .font(.headline)
                        .foregroundColor(.black)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Button(action: {
                    showingDeleteAlert = true
                }) {
                    Image(systemName: "xmark")
                        .padding()
                        .foregroundColor(.black)
                }
                .alert(isPresented: $showingDeleteAlert) {
                    Alert(
                        title:Text(NSLocalizedString("Supprimer un ami", comment: "")),
                        message: Text(NSLocalizedString("Êtes-vous sûr de vouloir supprimer cet ami ?", comment :"")),
                        primaryButton: .destructive(Text(NSLocalizedString("Supprimer", comment :""))) {
                            deleteAction(user)  // Call the delete friend function passed in
                        },
                        secondaryButton: .cancel()
                    )
                }
            }
        }
        
        private func profileImageView(user: User) -> some View {
            if let imageUrl = URL(string: user.profileImageUrl ?? "") {
                return WebImage(url: imageUrl)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
                    .eraseToAnyView()
            } else {
                return Text(String(user.username.prefix(1)).uppercased())
                    .font(.system(size: 25, weight: .bold))
                    .frame(width: 50, height: 50)
                    .background(Color.gray.opacity(0.3))
                    .clipShape(Circle())
                    .eraseToAnyView()
            }
        }
    }
    
    func fetchFriends() {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }
        
        let friendsRef = Firestore.firestore().collection("Friends").document(currentUserID)
        
        // Removed [weak self] as it's not needed for structs
        friendsRef.getDocument { (snapshot, error) in
            if let error = error {
                print("Error fetching friends: \(error)")
                return
            }
            
            guard let friendsList = snapshot?.data()?["friendsList"] as? [String] else { return }
            
            // Clear the list to avoid duplications on subsequent fetches
            self.friends.removeAll()
            
            // Fetch details for each friend in the list
            for id in friendsList {
                self.fetchUser(by: id) { user in
                    if let user = user {
                        DispatchQueue.main.async {
                            self.friends.append(user)
                        }
                    }
                }
            }
        }
    }
    
    
    
    func fetchUser(by id: String, completion: @escaping (User?) -> Void) {
        Firestore.firestore().collection("users").document(id).getDocument { (snapshot, error) in
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
}

