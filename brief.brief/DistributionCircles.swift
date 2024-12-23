//
//  DistributionCircle.swift
//  brief.brief
//
//  Created by Philippe Tchinda on 08/06/2023.
//

import SwiftUI
import Firebase
import SDWebImageSwiftUI
import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift
import FirebaseAuth
import FirebaseAnalytics

struct DistributionCircle: Identifiable, Codable {
    @DocumentID var id: String?
    var name: String
    var creatorID: String
    var memberIDs: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case creatorID = "creator_id"
        case memberIDs = "member_ids"
    }
}


struct DistributionCirclesView: View {
    @State private var distributionCircles: [DistributionCircle] = []
    @State private var friends: [User] = []
    @State private var selectedUsers = Set<String>()
    @State private var isShowingNameCircleSheet = false
    
    var navigationBarTitle: String {
             NSLocalizedString("Modify your lists", comment: "Modify your circles title")
    }


    var body: some View {
        
        ZStack {
           Color(red: 0.94, green: 0.93, blue: 0.91).opacity(0.98)
            
            
            GeometryReader { fullView in  // Wrap VStack with GeometryReader
                VStack {
                    Spacer().frame(height: fullView.size.height * 0.02)  // Pushes down the content
                    
                    NavigationView {
                        GeometryReader { geometry in
                            VStack {
                                // Distribution Circles
                                ScrollView {
                                    // Check if distributionCircles is empty
                                    if distributionCircles.isEmpty {
                                        Text(NSLocalizedString("Vous n'avez pas encore créer de cercles pour l'instant", comment: "No circles created yet"))
                                            .foregroundColor(.black) // Or any color you want
                                            .font(.headline)
                                            .padding()
                                    } else {
                                        VStack(alignment: .leading) {
                                            ForEach(distributionCircles.indices, id: \.self) { index in
                                                DistributionCircleCard(distributionCircle: $distributionCircles[index])
                                                    .padding(.horizontal, 16)
                                                    .background(Color(red: 0.94, green: 0.93, blue: 0.91).opacity(0.98))
                                                    .cornerRadius(6)
                                                    .padding(.vertical, 4)
                                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                                        Button {
                                                            deleteDistributionCircle(at: IndexSet(integer: index))
                                                        } label: {
                                                            Image(systemName: "trash")
                                                        }
                                                        .tint(.red)
                                                    }
                                            }
                                        }
                                    }
                                }
                                
                                Divider()
                                    .frame(height: 1.0)
                                    .background(Color.black) // Or any other color
                                
                                // Friends List
                                ScrollView {
                                    VStack {
                                        ForEach(friends) { friend in
                                            UserCard(
                                                user: friend,
                                                isSelected: { self.selectedUsers.contains(friend.id ?? "") },
                                                toggleSelection: {
                                                    if self.selectedUsers.contains(friend.id ?? "") {
                                                        self.selectedUsers.remove(friend.id ?? "")
                                                    } else {
                                                        self.selectedUsers.insert(friend.id ?? "")
                                                    }
                                                }
                                            )
                                            .padding(.horizontal, 16)
                                            .background(Color(red: 0.94, green: 0.93, blue: 0.91).opacity(0.98))
                                            .cornerRadius(6)
                                            .padding(.vertical, 4)
                                            .frame(maxWidth: .infinity)
                                        }
                                    }
                                }
                            }
                        }
                        .background(Color(red: 0.94, green: 0.93, blue: 0.91).opacity(0.98))
                    }
                    
                    Spacer()
                    
                    HStack {
                        Spacer()
                        
                        Button(action: {
                            isShowingNameCircleSheet = true
                        }) {
                            Text(NSLocalizedString("Créer une liste", comment: "Create a circle"))
                                .foregroundColor(.white)
                                .font(.system(size: 14))
                                .fontWeight(.semibold)
                                .padding(.horizontal, 13)
                                .padding(.vertical, 10)
                                .background(selectedUsers.count < 2 ? Color.gray : Color(red: 0.07, green: 0.04, blue: 1))
                                .cornerRadius(20)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(Color.black, lineWidth: 0.5)
                                )
                            
                        }
                        .padding(.bottom, 60)
                        .disabled(selectedUsers.count < 2)
                    }
                }
            }
            .onAppear {
                fetchFriends()
                fetchDistributionCircles()
            }
            .sheet(isPresented: $isShowingNameCircleSheet) {
                NameCircleView(isShowing: $isShowingNameCircleSheet, selectedUsers: $selectedUsers, distributionCircles: $distributionCircles)
                    .onDisappear {
                        // Log event when a new distribution circle is created
                        Analytics.logEvent("distributionCircle_created", parameters: [
                            "circle_id": "The id of the created circle",  // Replace with actual circle ID
                            "user_id": Auth.auth().currentUser?.uid ?? "unknown"
                        ])
                    }
            }
            
            .navigationBarTitleDisplayMode(.inline) 
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(navigationBarTitle)
                        .font(.custom("Avenir Next", size: 20))
                        .bold()
                        .foregroundColor(.black)
                }
            }
        }
    }


    
    
    
    
    // Function to fetch friends
    func fetchFriends() {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }


        
        let friendsRef = Firestore.firestore().collection("Friends").document(currentUserID)
        
        // Listen for real-time updates
        friendsRef.addSnapshotListener { (snapshot, error) in
            if let error = error {
                print("Error fetching friends: \(error)")
                return
            }
            
            guard let friendsList = snapshot?.data()?["friendsList"] as? [String] else { return }
            
            let group = DispatchGroup()
            var fetchedFriends = [User]()
            
            for id in friendsList {
                group.enter()
                Firestore.firestore().collection("users").document(id).getDocument { (userSnapshot, userError) in
                    if let userError = userError {
                        print("Error fetching user: \(userError.localizedDescription)")
                        group.leave()
                    } else if let userData = userSnapshot?.data(),
                              let username = userData["username"] as? String,
                              let firstName = userData["firstName"] as? String,
                              let lastName = userData["lastName"] as? String {
                        let profileImageUrl = userData["profileImageUrl"] as? String
                        let name = userData["name"] as? String
                        let friends = userData["friends"] as? [String]
                        let friendRequestsSent = userData["friendRequestsSent"] as? [String]
                        
                        // Create a User object with optional profile image handling
                        let user = User(id: id, username: username, firstName: firstName, lastName: lastName, isInvited: false, name: name, friends: friends, friendRequestsSent: friendRequestsSent, profileImageUrl: profileImageUrl)

                        fetchedFriends.append(user)
                        group.leave()
                    }
                }
            }
            
            group.notify(queue: .main) {
                self.friends = fetchedFriends
                // Log event
                Analytics.logEvent("friends_fetched", parameters: [
                    "user_id": currentUserID,
                    "friend_count": self.friends.count
                ])
                
            
            }
        }
    }



    func fetchDistributionCircles() {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }

        let cacheFileURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!.appendingPathComponent("\(currentUserID)_distributionCircles.json")

        // Attempt to load cached data
        if let cachedData = try? Data(contentsOf: cacheFileURL),
           let cachedCircles = try? JSONDecoder().decode([DistributionCircle].self, from: cachedData) {
            self.distributionCircles = cachedCircles
            return
        }

        Firestore.firestore().collection("distributionCircles")
            .whereField("creator_id", isEqualTo: currentUserID) // Filter circles based on the creator's ID
            .getDocuments { (querySnapshot, error) in
                if let error = error {
                    print("Error fetching distribution circles: \(error.localizedDescription)")
                } else {
                    let circles = querySnapshot?.documents.compactMap { document -> DistributionCircle? in
                        try? document.data(as: DistributionCircle.self)
                    }
                    self.distributionCircles = circles ?? []
                    
                    // Log event to capture the number of distribution circles fetched
                    Analytics.logEvent("distribution_circles_fetched", parameters: [
                    "user_id": currentUserID,
                    "circle_count": self.distributionCircles.count
                    ])
                    
                    // Cache the new data
                    if let jsonData = try? JSONEncoder().encode(self.distributionCircles) {
                        try? jsonData.write(to: cacheFileURL)
                    }
                }
            }
    }

    
    func deleteDistributionCircle(at offsets: IndexSet) {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }  // Moved to the top

        for index in offsets {
            let circleId = distributionCircles[index].id ?? ""
            
            // Delete from Firestore
            let docRef = Firestore.firestore().collection("distributionCircles").document(circleId)
            docRef.delete { err in
                if let err = err {
                    print("Error removing document: \(err)")
                } else {
                    print("Document successfully removed!")
                    
                    // Log event to capture the deletion of a distribution circle
                    Analytics.logEvent("distribution_circle_deleted", parameters: [
                        "user_id": currentUserID,  // Now in scope
                        "circle_id": circleId
                    ])
                }
            }
            
            // Delete from local array
            distributionCircles.remove(at: index)
        }
    }


    
    struct NameCircleView: View {
        @Binding var isShowing: Bool
        @Binding var selectedUsers: Set<String>
        @Binding var distributionCircles: [DistributionCircle]
        @State private var newCircleName = ""
        
        var body: some View {
            ZStack {
                Color(red: 0.94, green: 0.93, blue: 0.91).opacity(0.98)
  // Background color
                    .edgesIgnoringSafeArea(.all)
                
                VStack {
                    TextField(NSLocalizedString("Nom du cercle", comment: "Name of the circle"), text: $newCircleName)
                        .padding()
                        .foregroundColor(.gray)
                        .background(Color.white)
                        .cornerRadius(6)
                    
                    Button(action: {
                        createDistributionCircle()
                        isShowing = false
                    }) {
                        Text(NSLocalizedString("OK", comment: "OK button"))
                            .foregroundColor(.black)
                            .font(.system(size: 14))
                            .fontWeight(.semibold)
                            .padding(.horizontal, 40)
                            .padding(.vertical, 12)
                            .background(Color.white)
                            .cornerRadius(20)
                    }
                    .padding()
                }
            }
        }
        
        func createDistributionCircle() {
            guard let currentUserID = Auth.auth().currentUser?.uid else { return }
            let distributionCircle = DistributionCircle(name: newCircleName, creatorID: currentUserID, memberIDs: Array(selectedUsers))
            
            do {
                let _ = try Firestore.firestore().collection("distributionCircles").addDocument(from: distributionCircle)
                newCircleName = ""  // Reset the text field
                selectedUsers.removeAll() // Reset selected users
                distributionCircles.append(distributionCircle)
            } catch let error {
                print("Error writing distribution circle to Firestore: \(error)")
            }
        }
    }
    
    
    
    
    struct UserCard: View {
        var user: User
        var isSelected: () -> Bool
        var toggleSelection: () -> Void
        
        var body: some View {
            HStack {
                if let imageUrl = URL(string: user.profileImageUrl ?? "") {
                    WebImage(url: imageUrl)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 50, height: 50)
                        .clipShape(Circle())
                } else {
                    Text(String(user.firstName.prefix(1)).uppercased())
                        .font(.system(size: 25, weight: .bold))
                        .frame(width: 50, height: 50)
                        .background(Color.gray.opacity(0.3))
                        .clipShape(Circle())
                }
                
                Text(user.username)
                    .foregroundColor(.black)
                
                Spacer()
                
                Button(action: toggleSelection) {
                    Image(systemName: isSelected() ? "checkmark.circle.fill" : "plus.circle")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 30, height: 30)
                        .foregroundColor(Color(.black))
                }
            }
        }
    }
    
    
    
    struct DistributionCircleCard: View {
        @Binding var distributionCircle: DistributionCircle
        @State var members: [User] = []
        @State private var isShowingEditView: Bool = false
        
        
        var body: some View {
            ZStack {
                VStack(alignment: .leading) {
                    HStack {
                        ForEach(members.prefix(3), id: \.id) { member in  // only show the first 3 members
                            if let imageUrl = URL(string: member.profileImageUrl ?? "") {
                                WebImage(url: imageUrl)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 50, height: 50)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(Color.black, lineWidth: 2))
                            } else {
                                Text(String(member.firstName.prefix(1)).uppercased())
                                    .font(.system(size: 25, weight: .bold))
                                    .frame(width: 50, height: 50)
                                    .background(Color.gray.opacity(0.3))
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(Color.black, lineWidth: 2))
                            }
                        }
                        .padding(.trailing, -15)  // This will make the images overlap
                        
                        Spacer()
                        
                        Button(action: {
                            isShowingEditView = true
                        }) {
                            Text(NSLocalizedString("Modifier", comment: "Edit button"))
                                .foregroundColor(.black)
                                .font(.system(size: 14))
                                .fontWeight(.semibold)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.white)
                                .cornerRadius(20)
                        }
                        .sheet(isPresented: $isShowingEditView) {
                            EditDistributionCircleView(distributionCircle: $distributionCircle, members: $members)
                        }
                        
                    }
                    
                    Text(distributionCircle.name)
                        .font(.system(size: 13))
                        .foregroundColor(.black)
                        .frame(width: 152, height: 15, alignment: .topLeading)
                }
                .onAppear {
                    fetchMembers()
                }
            }
        }
                
        
        
        
        
        func fetchMembers() {
            let group = DispatchGroup()
            var fetchedMembers = [User]()
            for id in distributionCircle.memberIDs {
                group.enter()
                Firestore.firestore().collection("users").document(id).getDocument { (userSnapshot, userError) in
                    if let userError = userError {
                        print("Error fetching user: \(userError.localizedDescription)")
                        group.leave()
                    } else if let userData = userSnapshot?.data(),
                              let username = userData["username"] as? String,
                              let firstName = userData["firstName"] as? String,
                              let lastName = userData["lastName"] as? String,
                              let profileImageUrl = userData["profileImageUrl"] as? String {
                        let name = userData["name"] as? String
                        let friends = userData["friends"] as? [String]
                        let friendRequestsSent = userData["friendRequestsSent"] as? [String]
                        fetchedMembers.append(User(id: id, username: username, firstName: firstName, lastName: lastName, isInvited: false, name: name, friends: friends, friendRequestsSent: friendRequestsSent, profileImageUrl: profileImageUrl))
                        group.leave()
                    }
                }
            }
            group.notify(queue: .main) {
                self.members = fetchedMembers
            }
        }
    }
    
    
    struct EditDistributionCircleView: View {
                @Binding var distributionCircle: DistributionCircle
                @Binding var members: [User]
                @State var newName: String = ""
                @State var availableUsers: [User] = []
                @State var showDeleteAlert = false
                @State var indexToDelete: Int?
                @State var membersToDelete: [Int] = []  // Added this line
                @Environment(\.presentationMode) var presentationMode
                @State var showDeleteCircleAlert = false  // New State for showing delete circle alert



                var body: some View {
                    ZStack {
                        Color(red: 0.94, green: 0.93, blue: 0.91).opacity(0.98)
                            .edgesIgnoringSafeArea(.all)

                        VStack {
                     
                            ScrollView {
                                VStack {
                                    Text(NSLocalizedString("Membres", comment: "Members label"))
                                        .foregroundColor(.black)
                                        .padding(.top, 10)
                                        .font(.system(size: 16, weight: .semibold))

                                    
                                    ForEach(members.indices, id: \.self) { index in
                                        HStack {
                                            // Display profile image or first letter of first name
                                            if let imageUrl = URL(string: members[index].profileImageUrl ?? "") {
                                                WebImage(url: imageUrl)
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fill)
                                                    .frame(width: 50, height: 50)
                                                    .clipShape(Circle())
                                            } else {
                                                Text(String(members[index].username.prefix(1)).uppercased())
                                                    .font(.system(size: 25, weight: .bold))
                                                    .frame(width: 50, height: 50)
                                                    .background(Color.gray.opacity(0.3))
                                                    .clipShape(Circle())
                                            }
                                            
                                            Text(members[index].username)
                                                .foregroundColor(.black)
                                            Spacer()
                                                                            Button(action: {
                                                                                showDeleteAlert = true
                                                                                indexToDelete = index
                                                                            }) {
                                                                                Image(systemName: "minus.circle.fill")
                                                                                    .foregroundColor(.red)
                                                                            }
                                                                            .buttonStyle(PlainButtonStyle())
                                                                            .alert(isPresented: $showDeleteAlert) {
                                                                                Alert(
                                                                                                               title: Text(NSLocalizedString("Supprimer un membre", comment: "Delete a member")),
                                                                                                               message: Text(NSLocalizedString("Tu es sûr de vouloir supprimer ce membre ?", comment: "Are you sure you want to delete this member?")),
                                                                                                               primaryButton: .destructive(Text(NSLocalizedString("Supprimer", comment: "Delete"))) {
                                                                if let index = indexToDelete {
                                                                members.remove(at: index)
                                                                updateMembersInFirestore()  // Update Firestore

                                                                                        }
                                                                                      },
                                                                                      secondaryButton: .cancel())
                                                                            }
                                                                        }
                                                                        .padding(.horizontal)
                                                                        .background(Color(red: 0.94, green: 0.93, blue: 0.91).opacity(0.98))
                                        
                                                                    }
                                    
                                    Divider()
                                    
                                    
                                    Text(NSLocalizedString("Ajouter des membres au cercle", comment: "Add members to circle"))
                                        .foregroundColor(.black)
                                        .padding(.top, 10)
                                        .font(.system(size: 16, weight: .semibold))

                                    ForEach(availableUsers.indices, id: \.self) { index in
                                                                HStack {
                                                                    // Display profile image or first letter of first name
                                                                    if let imageUrl = URL(string: availableUsers[index].profileImageUrl ?? "") {
                                                                        WebImage(url: imageUrl)
                                                                            .resizable()
                                                                            .aspectRatio(contentMode: .fill)
                                                                            .frame(width: 50, height: 50)
                                                                            .clipShape(Circle())
                                                                    } else {
                                                                        Text(String(availableUsers[index].username.prefix(1)).uppercased())
                                                                            .font(.system(size: 25, weight: .bold))
                                                                            .frame(width: 50, height: 50)
                                                                            .background(Color.gray.opacity(0.3))
                                                                            .foregroundColor(.black)
                                                                            .clipShape(Circle())
                                                                    }
                                                                    
                                                                    Text(availableUsers[index].username)
                                                                        .foregroundColor(.black)
                                                                    Spacer()
                                                                    Button(action: {
                                                                        members.append(availableUsers[index])
                                                                        availableUsers.remove(at: index)
                                                                        
                                                                        
                                                                    }) {
                                                                        Image(systemName: "plus.circle.fill")
                                                                            .foregroundColor(.green)
                                                                    }
                                                                }
                                                                .padding(.horizontal)
                                                                .background(Color(red: 0.94, green: 0.93, blue: 0.91).opacity(0.98))
                                                            }
                                                        }
                                                    }
                            
                            
                            
                            
                            Button(action: {
                                for index in membersToDelete.sorted(by: >) {
                                                    members.remove(at: index)
                                                }
                                updateMembersInFirestore()  // Update Firestore
                                membersToDelete.removeAll()
                                self.presentationMode.wrappedValue.dismiss()
                                            }) {
                                                Text(NSLocalizedString("Enregistrer", comment: "Save"))
                                                    .foregroundColor(.black)
                                                    .font(.system(size: 14))
                                                    .fontWeight(.semibold)
                                                    .padding(.horizontal, 40)
                                                    .padding(.vertical, 12)
                                                    .background(Color.white)
                                                    .cornerRadius(20)
                                            }
                                            .padding()
                        }
                        .onAppear {
                            fetchAvailableFriends()
                        }

                        // Adding a trash button at the bottom left corner
                        VStack {
                            Spacer() // Push the content to the bottom
                            HStack {
                                Button(action: {
                                    showDeleteCircleAlert = true
                                }) {
                                    Image(systemName: "trash")
                                        .foregroundColor(.black)
                                        .font(.system(size: 20))
                                        .padding(16)
                                        .background(Color.red)
                                        .cornerRadius(40)
                                }
                                .alert(isPresented: $showDeleteCircleAlert) {
                                    Alert(title: Text(NSLocalizedString("Supprimer le cercle", comment: "Delete the circle")),
                                          message: Text(NSLocalizedString("Tu es sûr de vouloir supprimer ce cercle ?", comment: "Are you sure you want to delete this circle?")),
                                          primaryButton: .destructive(Text(NSLocalizedString("Supprimer", comment: "Delete"))) {
                                              deleteDistributionCircle()
                                          },
                                          secondaryButton: .cancel())
                                }
                                .padding(.bottom, 10) // Padding from the bottom
                                .padding(.leading, 20) // Padding from the left
                                Spacer() // Push the content to the left
                            }
                        }
                    }
                }
        
        
        // New function to delete the distribution circle
        func deleteDistributionCircle() {
            guard let circleId = distributionCircle.id else { return }
            
            let docRef = Firestore.firestore().collection("distributionCircles").document(circleId)
            docRef.delete { err in
                if let err = err {
                    print("Error removing document: \(err)")
                } else {
                    print("Document successfully removed!")
                    self.presentationMode.wrappedValue.dismiss()
                }
            }
        }

        
            
        // Function to fetch available friends
        func fetchAvailableFriends() {
            guard let currentUserID = Auth.auth().currentUser?.uid else { return }

            let friendsRef = Firestore.firestore().collection("Friends").document(currentUserID)
            friendsRef.getDocument { (document, error) in
                if let document = document, document.exists {
                    if let friendsList = document.data()?["friendsList"] as? [String] {

                        let group = DispatchGroup()
                        var fetchedFriends = [User]()

                        for id in friendsList {
                            group.enter()
                            Firestore.firestore().collection("users").document(id).getDocument { (userSnapshot, userError) in
                                defer { group.leave() } // Ensure that group.leave() is called in all cases
                                
                                if let userError = userError {
                                    print("Error fetching user: \(userError.localizedDescription)")
                                } else if let userData = userSnapshot?.data(),
                                          let username = userData["username"] as? String,
                                          let firstName = userData["firstName"] as? String,
                                          let lastName = userData["lastName"] as? String,
                                          let profileImageUrl = userData["profileImageUrl"] as? String,
                                          !profileImageUrl.isEmpty { // Check if profileImageUrl is not empty
                                          
                                    let name = userData["name"] as? String
                                    let friends = userData["friends"] as? [String]
                                    let friendRequestsSent = userData["friendRequestsSent"] as? [String]
                                    
                                    fetchedFriends.append(User(id: id, username: username, firstName: firstName, lastName: lastName, isInvited: false, name: name, friends: friends, friendRequestsSent: friendRequestsSent, profileImageUrl: profileImageUrl))
                                }
                            }
                        }

                        group.notify(queue: .main) {
                            // Filter out friends who are already in the circle and who do not have a profile image
                            let memberIDs = self.members.compactMap { $0.id }
                            self.availableUsers = fetchedFriends.filter {
                                !memberIDs.contains($0.id ?? "") && ($0.profileImageUrl?.isEmpty == false)
                            }
                        }
                    }
                } else {
                    print("Document does not exist or there was an error.")
                }
            }
        }



        // Call this function when a member is deleted or added
        func updateMembersInFirestore() {
            guard let circleId = distributionCircle.id else { return }
            let memberIDs = members.compactMap { $0.id }
            let docRef = Firestore.firestore().collection("distributionCircles").document(circleId)
            
            docRef.updateData([
                "member_ids": memberIDs
            ]) { err in
                if let err = err {
                    print("Error updating members: \(err)")
                } else {
                    print("Members successfully updated")
                }
            }
        }

        
        func updateDistributionCircle() {
            guard let id = distributionCircle.id else { return }
            let distributionCircleRef = Firestore.firestore().collection("distributionCircles").document(id)
            
            distributionCircleRef.updateData([
                "name": newName
            ]) { err in
                if let err = err {
                    print("Error updating distribution circle: \(err)")
                } else {
                    print("Distribution circle successfully updated")
                    distributionCircle.name = newName
                }
            }
        }
    }
}
