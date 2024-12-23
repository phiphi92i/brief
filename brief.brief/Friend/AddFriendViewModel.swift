//
//  AddFriendViewModel.swift
//  brief.brief
//
//  Created by Philippe Tchinda on 27/06/2023.
//

import SwiftUI
import Firebase
import FirebaseFirestore

class AddFriendViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var users = [User]()
    @Published var selectedUsers = Set<String>()

    // Connect to Firestore
    private let db = Firestore.firestore()

    // Fetch the list of users
    func fetchUsers() {
        let usersRef = db.collection("users")
        usersRef.getDocuments { snapshot, error in
            if let error = error {
                // Handle the error
                print("Error fetching users: \(error.localizedDescription)")
            } else if let snapshotDocuments = snapshot?.documents {
                self.users = snapshotDocuments.compactMap { document in
                    if let id = document.documentID as? String,
                       let username = document.data()["username"] as? String,
                       let firstName = document.data()["firstName"] as? String,
                       let lastName = document.data()["lastName"] as? String {
                        return User(id: id, username: username, firstName: firstName, lastName: lastName)
                    } else {
                        return nil
                    }
                }
            }
        }
    }

    // Filtered users based on search text
    var searchableUsers: [User] {
        if searchText.isEmpty {
            return users
        } else {
            let lowercasedQuery = searchText.lowercased()

            return users.filter {
                $0.username.lowercased().contains(lowercasedQuery)
            }
        }
    }

    // Toggle user selection
    func toggleUserSelection(_ user: User) {
        if selectedUsers.contains(user.id) {
            selectedUsers.remove(user.id)
        } else {
            // Find the user ID based on username
            if let selectedUser = users.first(where: { $0.username == user.username }) {
                selectedUsers.insert(selectedUser.id)
            }
        }
    }

    // Send friend invitations to selected users
    func sendInvitations() {
        // Perform the invitation sending logic
        for userId in selectedUsers {
            if let userIndex = users.firstIndex(where: { $0.id == userId }) {
                users[userIndex].isInvited = true
            }
            // Perform any other necessary actions to send invitations
            print("Invitation sent to user: \(userId)")
        }
        // Reset selected users
        selectedUsers = Set<String>()
    }

    // Delete friends
    func deleteFriends() {
        // Perform the friend deletion logic
        for userId in selectedUsers {
            if let userIndex = users.firstIndex(where: { $0.id == userId }) {
                users[userIndex].isInvited = false
            }
            // Perform any other necessary actions to delete friends
            print("Friend deleted: \(userId)")
        }
        // Reset selected users
        selectedUsers = Set<String>()
    }
}
