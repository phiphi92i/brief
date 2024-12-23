






import FirebaseAuth
import FirebaseAnalytics
import FirebaseFirestore

class FriendsData: ObservableObject {

   @Published var friends: [User] = []
   private let db = Firestore.firestore()

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
       friendsRef.addSnapshotListener { [weak self] snapshot, error in
           guard let self = self else { return }

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
           }
       }
   }
}
