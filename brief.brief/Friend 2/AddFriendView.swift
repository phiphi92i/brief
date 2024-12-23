//
//  AddFriendView.swift
//  brief.brief
//
//  Created by Philippe Tchinda on 04/06/2023.
//

import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore
import SDWebImageSwiftUI
import Contacts
import FirebaseDatabase
import AlgoliaSearchClient
import InstantSearch
import InstantSearchSwiftUI

enum SelectedView {
    case suggestions // Add this line for the new view
    case addFriend
    case distributionCircles
}

struct Contact: Identifiable {
    let id: UUID
    let name: String
    let number: String
}




class AlgoliaController: ObservableObject {
    let searcher: HitsSearcher
    let searchBoxInteractor: SearchBoxInteractor
    let searchBoxController: SearchBoxObservableController
    let hitsInteractor: HitsInteractor<User>
    let hitsController: HitsObservableController<User>
    var debounceTimer: Timer?
        var cachedResults: [String: [User]] = [:] // Cache for search results

        @Published var query: String = "" {
            didSet {
                // Cancel any existing timers
                debounceTimer?.invalidate()
                
                // Start a new timer that will call `performSearch` after a delay
                debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { _ in
                    self.performSearch()
                }
            }
        }
    
    func performSearch() {
        // Check if the query length is at least 3
        guard query.count >= 3 else { return }
        
        // Check if the result is already cached
        if let cachedResult = cachedResults[query] {
            self.hitsController.hits = cachedResult
            return
        }
        
        // Perform the actual search here using `query`
        searcher.query = Query(query)
        searcher.search() { result in
            switch result {
            case .success(let response):
                // Update the hits
                self.hitsController.hits = response.hits
                // Cache the result
                self.cachedResults[self.query] = response.hits
            case .failure(let error):
                print("Search error: \(error)")
            }
        }
    }
    
    init() {
        self.searcher = HitsSearcher(appID: "5CVODU9OGE",
                                     apiKey: "d5a617311a989ccf1d347eb79e893d1d",
                                     indexName: "users")
        self.searchBoxInteractor = .init()
        self.searchBoxController = .init()
        self.hitsInteractor = .init()
        self.hitsController = .init()
        setupConnections()
    }
    
    func setupConnections() {
        searchBoxInteractor.connectSearcher(searcher)
        searchBoxInteractor.connectController(searchBoxController)
        hitsInteractor.connectSearcher(searcher)
        hitsInteractor.connectController(hitsController)
    }
    
}




extension AnyTransition {
    static var moveAndFade: AnyTransition {
        let insertion = AnyTransition.move(edge: .trailing)
            .combined(with: .opacity)
        let removal = AnyTransition.move(edge: .leading)
            .combined(with: .opacity)
        return .asymmetric(insertion: insertion, removal: removal)
    }
}


struct SearchBar: View {
    @Binding var text: String
    @Binding var isEditing: Bool
    let onSubmit: () -> Void
    
    var body: some View {
        ZStack(alignment: .leading) {
            if text.isEmpty && !isEditing {
                Text("Rechercher des amis...")
                    .foregroundColor(Color.gray)
                    .padding(.leading, 34)
            }
            
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                
                TextField("", text: $text, onCommit: onSubmit)
                    .padding(.vertical, 8)
                    .foregroundColor(Color.white)
                    .keyboardType(.default)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                
                if isEditing {
                    Button(action: {
                        text = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
        }
        .padding(.leading, 16)
        .padding(.trailing, 0)
        .padding(.vertical, 8)
        .frame(width: 350, height: 40, alignment: .leading)
        .background(Color(red: 0.24, green: 0.19, blue: 0.38))
        .cornerRadius(6)
        .onTapGesture {
            isEditing = true
        }
    }
}


struct AddFriendView: View {
    @State private var users = [User]()
    @State private var selectedUsers = Set<String>()
    @State private var friendRequests = [User]()
    @State private var friends = [User]()
    @State private var contacts: [Contact] = [] // Add your Contact model definition
    @State private var selectedView: SelectedView = .suggestions
    @State private var isEditing = false
    @Environment(\.presentationMode) var presentationMode
    @State private var showPreviousView = false // Add this property to manage navigation
    @Environment(\.dismiss) var dismiss // Add this line to enable custom dismissal
    
    
    @ObservedObject var algoliaSearchBoxController: SearchBoxObservableController
    @ObservedObject var algoliaHitsController: HitsObservableController<User>
    let algoliaSearcher: HitsSearcher
    struct InstantSearchUserResultsView: View {
        let hitsController: HitsObservableController<User>
        let selectedUsers: Set<String>
        let sendFriendRequest: (User) -> Void // Add this closure property
        let shouldShowResults: Bool // Add this property
        
        var body: some View {
            VStack {
                // Algolia search results view
                if shouldShowResults {
                    if hitsController.hits.isEmpty {
                        Text("No Results") // Show "No Results" text when there are no hits
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        HitsList(hitsController) { (hit, _) in
                            if let user = hit {
                                UserCard(user: user, isSelected: selectedUsers.contains(user.id), action: {
                                    sendFriendRequest(user)
                                    // Your action here, like sending a friend request
                                })
                                .padding(.vertical, 10)
                            }
                        }
                    }
                }
            }
        }
    }
    
    var navigationBarTitle: String {
        switch selectedView {
        case .suggestions, .addFriend:
            return "Amis"
        case .distributionCircles:
            return "Modifier vos cercles"
        }
    }
    
    
    
    var body: some View {
        ZStack {
            Color(red: 0.106, green: 0.063, blue: 0.227, opacity: 1.0)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                
                
                
                switch selectedView {
                case .suggestions:
                    
                    SearchBar(text: self.$algoliaSearchBoxController.query, isEditing: $isEditing, onSubmit: self.algoliaSearchBoxController.submit)
                        .padding(.top, 16)
                    
                    // Inside the main view's body property
                    InstantSearchUserResultsView(
                        hitsController: algoliaHitsController,
                        selectedUsers: selectedUsers,
                        sendFriendRequest: { user in
                            self.sendFriendRequest(user) // Use 'self' to refer to the instance method
                        },
                        shouldShowResults: !algoliaSearchBoxController.query.isEmpty // Only show results if the query is not empty
                        
                    )
                    .padding(.top, 16)
                    
                    
                    
                    
                    // Contacts list
                    ScrollView {
                        VStack(spacing: 0) {
                            // Add content for the contacts list here, if needed
                        }
                    }
                    .padding(.horizontal, 16)
                    .background(Color(red: 0.106, green: 0.063, blue: 0.227, opacity: 1.0))
                    .cornerRadius(6)
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity)
                    
                    
                    
                case .addFriend:
                    
                    SearchBar(text: self.$algoliaSearchBoxController.query, isEditing: $isEditing, onSubmit: self.algoliaSearchBoxController.submit)
                    
                        .padding(.top, 16)
                    
                    // Inside the main view's body property
                    InstantSearchUserResultsView(
                        hitsController: algoliaHitsController,
                        selectedUsers: selectedUsers,
                        sendFriendRequest: { user in
                            self.sendFriendRequest(user) // Use 'self' to refer to the instance method
                        },
                        shouldShowResults: !algoliaSearchBoxController.query.isEmpty // Only show results if the query is not empty
                    )
                    .padding(.top, 16)
                    
                    
                    
                    ScrollView {
                        VStack(spacing: 0) {
                            // Algolia search results view
                            
                            if algoliaSearchBoxController.query.isEmpty {
                                VStack(spacing: 8) {
                                    Text("Demandes d'amis")
                                        .font(.headline)
                                        .foregroundColor(.white)
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
                                    .frame(width: 351, height: 190)
                                    .background(Color(red: 0.24, green: 0.19, blue: 0.38))
                                    .cornerRadius(6)
                                    
                                    // New section for list of friends
                                    Text("Mes amis")
                                        .font(.headline)
                                        .foregroundColor(.white)
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
                                    .frame(width: 351, height: 190)
                                    .background(Color(red: 0.24, green: 0.19, blue: 0.38))
                                    .cornerRadius(6)
                                }
                                .padding(.top, 16)
                            } else {
                                ForEach(users) { user in
                                    UserCard(user: user, isSelected: selectedUsers.contains(user.id)) {
                                        sendFriendRequest(user)
                                    }
                                    .padding(.horizontal, 16)
                                    .background(Color(red: 0.106, green: 0.063, blue: 0.227, opacity: 1.0))
                                    .cornerRadius(6)
                                    .padding(.vertical, 4)
                                    .frame(maxWidth: .infinity)
                                }
                            }
                        }
                    }
                    
                case .distributionCircles:
                    DistributionCirclesView()
                }
                
                Picker("", selection: $selectedView) {
                    Text("Suggestions").tag(SelectedView.suggestions) // Add this line for the new view
                    Text("Amis").tag(SelectedView.addFriend)
                    Text("Cercles").tag(SelectedView.distributionCircles)
                    
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(width: 280, height: 80)
                .foregroundColor(.white)
                .colorScheme(.dark)
                
                .pickerStyle(SegmentedPickerStyle())
                .frame(width: 280, height: 80)
                .foregroundColor(.white)
                .colorScheme(.dark)
                
                Spacer()
                
                
            }
            .navigationBarTitleDisplayMode(.inline) // Display title inline
            .transition(.moveAndFade) // Apply the custom transition here
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(navigationBarTitle)
                        .font(.custom("Avenir Next", size: 20))
                        .bold()
                        .foregroundColor(.white)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        withAnimation {
                            dismiss() // Use the custom dismiss method here
                        }
                    }) {
                        Image(systemName: "arrow.right") // Right-facing arrow image
                            .foregroundColor(.white) // Customize the color as needed
                    }
                }
            }
            .navigationBarHidden(false)
            .navigationBarBackButtonHidden(true) // Hide the default back button
            .foregroundColor(.white)
            .onAppear {
                fetchFriendRequests()
                fetchFriends()
                
                algoliaSearcher.search()
            }
        }
    }
    
    
    // Connect to Firestore
    let db = Firestore.firestore()
    
    
    
    
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
                    if let id = document.data()["id"] as? String {
                        group.enter()
                        db.collection("users").document(id).getDocument { (userSnapshot, userError) in
                            if let userError = userError {
                                print("Error fetching user: \(userError.localizedDescription)")
                                group.leave()
                            } else if let userData = userSnapshot?.data(),
                                      let username = userData["username"] as? String,
                                      let firstName = userData["firstName"] as? String,
                                      let lastName = userData["lastName"] as? String {
                                let name = userData["name"] as? String
                                let friends = userData["friends"] as? [String]
                                fetchedRequests.append(User(id: id, username: username, firstName: firstName, lastName: lastName, name: name, friends: friends))
                                group.leave()
                            }
                        }
                    }
                }
                group.notify(queue: .main) {
                    self.friendRequests = fetchedRequests
                }
            }
        }
    }
    
    // Send friend requests to selected users
    func sendFriendRequest(_ user: User) {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }
        
        // Check if the current user is trying to send a friend request to themselves
        if currentUserID == user.id {
            print("Can't send a friend request to yourself")
            return
        }
        
        // Get the current user's document from Firestore
        let currentUserRef = db.collection("users").document(currentUserID)
        
        currentUserRef.getDocument { (document, error) in
            if let document = document, document.exists {
                // Fetch current user's friends list
                if let friends = document.data()?["friends"] as? [String] {
                    // If user is already in friends list, do not send request
                    if friends.contains(user.id) {
                        print("Already friends with user: \(user.id)")
                        return
                    }
                }
            }
            
            // Check if the user has already received a friend request from the current user
            let friendRequestRef = db.collection("users").document(user.id).collection("friendRequests").document(currentUserID)
            
            friendRequestRef.getDocument { (document, error) in
                if let document = document, document.exists {
                    print("Friend request already sent to user: \(user.id)")
                    return
                } else {
                    // Send a friend request
                    friendRequestRef.setData(["id": currentUserID, "username": user.username], merge: true) { error in
                        if let error = error {
                            print("Error sending friend request: \(error.localizedDescription)")
                        } else {
                            print("Friend request sent to user: \(user.id)")
                            // Add the user to the selectedUsers set after a successful request
                            self.selectedUsers.insert(user.id)
                            
                            // Add the receiver to the sentRequests array of the current user
                            currentUserRef.updateData(["sentRequests": FieldValue.arrayUnion([user.id])])
                        }
                    }
                }
            }
        }
    }
    
    
    
    
    
    // Accept a friend request
    func acceptFriendRequest(_ user: User) {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }
        
        // Add each other to friends lists
        let currentUserRef = db.collection("users").document(currentUserID)
        currentUserRef.updateData(["friends": FieldValue.arrayUnion([user.id])])
        
        let userRef = db.collection("users").document(user.id)
        userRef.updateData(["friends": FieldValue.arrayUnion([currentUserID])])
        
        // Remove friend request
        let friendRequestRef = db.collection("users").document(currentUserID).collection("friendRequests").document(user.id)
        friendRequestRef.delete()
    }
    
    // Deny a friend request
    func denyFriendRequest(_ user: User) {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }
        
        // Remove friend request
        let friendRequestRef = db.collection("users").document(currentUserID).collection("friendRequests").document(user.id)
        friendRequestRef.delete()
    }
    
    func deleteFriend(_ user: User) {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }
        
        // Remove each other from friends lists
        let currentUserRef = db.collection("users").document(currentUserID)
        currentUserRef.updateData(["friends": FieldValue.arrayRemove([user.id])])
        
        let userRef = db.collection("users").document(user.id)
        userRef.updateData(["friends": FieldValue.arrayRemove([currentUserID])])
    }
    
    func fetchFriends() {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }
        
        let currentUserRef = Firestore.firestore().collection("users").document(currentUserID)
        currentUserRef.getDocument { (document, error) in
            if let document = document, document.exists,
               let friendsIDs = document.data()?["friends"] as? [String] {
                let group = DispatchGroup()
                var fetchedFriends = [User]()
                for id in friendsIDs {
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
                            fetchedFriends.append(User(id: id, username: username, firstName: firstName, lastName: lastName, isInvited: false, name: name, friends: friends, friendRequestsSent: friendRequestsSent, profileImageUrl: profileImageUrl))
                            group.leave()
                        }
                    }
                }
                group.notify(queue: .main) {
                    self.friends = fetchedFriends
                }
            }
        }
    }
    
    
    struct UserCard: View {
        let user: User
        let isSelected: Bool
        let action: () -> Void
        
        @State private var isProfileViewActive = false // State to control the NavigationLink
        
        var body: some View {
            HStack {
                NavigationLink(destination: ProfileView(userID: user.id, viewModel: ProfileViewModel(userID: user.id)), isActive: $isProfileViewActive) {
                    EmptyView()
                }
                .hidden() // Hide the NavigationLink
                
                // Profile picture or first letter of name
                Button(action: {
                    isProfileViewActive = true // Activate the NavigationLink when tapped
                }) {
                    if let imageUrl = URL(string: user.profileImageUrl ?? "") {
                        WebImage(url: imageUrl)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 50, height: 50)
                            .clipShape(Circle())
                    } else {
                        Text(String(user.username.prefix(1)).uppercased())
                            .font(.system(size: 25, weight: .bold))
                            .frame(width: 50, height: 50)
                            .background(Color.gray.opacity(0.3))
                            .clipShape(Circle())
                    }
                }
                VStack(alignment: .leading) {
                    Button(action: {
                        isProfileViewActive = true // Activate the NavigationLink when tapped
                    }) {
                        Text(user.username) // Display the username
                            .font(.headline)
                            .foregroundColor(.white)
                            .lineLimit(1)
                    }
                }
                
                Spacer() // Spacer to push the following view to the right
                
                // Add Friend Button
                Button(action: {
                    action()
                }) {
                    if isSelected {
                        Text("Request Sent")
                            .padding()
                            .foregroundColor(.white)
                            .background(Color.green)
                            .cornerRadius(10)
                    } else {
                        Text("Ajouter en ami")
                            .padding()
                            .foregroundColor(.white)
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                }
            }
        }
    }
    
    
    struct FriendRequestCard: View {
        let user: User
        let acceptAction: (User) -> Void
        let denyAction: (User) -> Void
        
        var body: some View {
            HStack {
                // Profile picture or first letter of name
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
                
                VStack(alignment: .leading) {
                    Text(user.username) // Display the surname
                        .font(.headline)
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
                
                Spacer() // Spacer to push the following view to the right
                
                // Accept and Deny buttons
                Button(action: {
                    acceptAction(user)
                }) {
                    Text("Accepter")
                        .padding()
                        .foregroundColor(.white)
                        .background(Color.green)
                        .cornerRadius(10)
                }
                
                Button(action: {
                    denyAction(user)
                }) {
                    Text("Refuser")
                        .padding()
                        .foregroundColor(.white)
                        .background(Color.red)
                        .cornerRadius(10)
                }
            }
        }
    }
    
    struct FriendsListCard: View {
        let user: User
        let deleteAction: (User) -> Void
        
        @State private var showingDeleteAlert = false // State to control the alert
        
        var body: some View {
            HStack {
                // Profile picture or first letter of name
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
                
                VStack(alignment: .leading) {
                    Text(user.username) // Display the surname
                        .font(.headline)
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
                
                Spacer() // Spacer to push the following view to the right
                
                // Delete Friend Button
                Button(action: {
                    showingDeleteAlert = true // Show the alert
                }) {
                    Image(systemName: "xmark")
                        .padding()
                        .foregroundColor(.white)
                }
                .alert(isPresented: $showingDeleteAlert) {
                    Alert(title: Text("Supprimer un ami"),
                          message: Text("Êtes-vous sûr de vouloir supprimer cet ami ?"),
                          primaryButton: .destructive(Text("Supprimer")) {
                        deleteAction(user) // Delete the friend
                    },
                          secondaryButton: .cancel())
                }
            }
        }
    }
}
    
    
    struct AddFriendViewWrapper: View {
        let algoliaController = AlgoliaController()
        
        var body: some View {
            AddFriendView(algoliaSearchBoxController: algoliaController.searchBoxController, algoliaHitsController: algoliaController.hitsController, algoliaSearcher: algoliaController.searcher)
        }
    }

