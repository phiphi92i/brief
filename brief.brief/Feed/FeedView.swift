//
//  FeedView.swift
//  brief
//
//  Created by Philippe Tchinda on 20/04/2023.
//

import SwiftUI
import FirebaseStorage
import FirebaseAuth
import SDWebImageSwiftUI
import FirebaseFirestore
import FirebaseAnalytics
import NukeUI


struct FeedView: View {
    
    @StateObject private var viewModel = FeedViewModel()
    @State private var posts: [UserPost] = []
    @State private var isRefreshing = false
    @StateObject var cameraViewModel = CameraViewModel()
    @State private var showingWritePostView = false
    let addFriendView = AddFriendView()
    
    let currentUserId: String = Auth.auth().currentUser?.uid ?? ""
    @StateObject var profileViewModel: ProfileViewModel // This was already correctly set as @StateObject
    
//    @Binding var shouldNavigateToComments: Bool
//    @Binding var selectedPostId: String?
    var onVoiceRecordComplete: (URL?) -> Void
//    @State private var activePostIdForComments: String? = nil
    private var commentCameraService = CommentCameraService()
    @StateObject var inviteContactViewModel = InviteContactViewModel()
    @State private var recommendations: [FriendRecommendation] = []
    @State private var page: Int = 0
    @State private var showingWelcomeSheet = false
    @StateObject private var contactsManager = ContactsManager()


    
    init(/*shouldNavigateToComments: Binding<Bool>, selectedPostId: Binding<String?>*/) {
//        self._shouldNavigateToComments = shouldNavigateToComments
//        self._selectedPostId = selectedPostId
        self.onVoiceRecordComplete = { _ in }

        if let currentUserId = Auth.auth().currentUser?.uid {
            _profileViewModel = StateObject(wrappedValue: ProfileViewModel(userID: currentUserId))
        } else {
            _profileViewModel = StateObject(wrappedValue: ProfileViewModel(userID: ""))
            
        }
    }


    
    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.94, green: 0.93, blue: 0.91).opacity(0.98)
                    .ignoresSafeArea()
                
                
                ZStack {
                    
                    VStack {

                        

                        // Main content area with posts
                        ScrollView {
                            
                                
                            LazyVStack {
                                    
                                    HStack {
                                        
                                        
                                        Image("brief-feed-logo")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(height: 25)
                                        
                                        
                                        Spacer()
                                        
                                        HStack(spacing: 20) {
                                            
                                            if let imageUrl = viewModel.userProfileImageUrl {
                                            NavigationLink(destination: ProfileView(userID: currentUserId, viewModel: profileViewModel)) {
                                            WebImage(url: imageUrl)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 25, height: 25)
                                            .clipShape(Circle())
//                                            .padding(.trailing, 15)
                                            
                                            }
                                            } else {
                                            NavigationLink(destination: ProfileView(userID: currentUserId, viewModel: profileViewModel)) {
                                            Text(viewModel.userFirstNameInitial)
                                            .font(.system(size: 18, weight: .bold))
                                            .foregroundColor(.white)
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 25, height: 25)
                                            .background(Color.green)
                                            .clipShape(Circle())
//                                            .padding(.trailing, 15)
                                            
                                            }
                                            }
                                            
//                                            NavigationLink(destination: DoubleCameraView(cameraModel: DoubleCameraViewModel())) {
//                                                Image(systemName: "camera")
//                                                    .resizable()
//                                                    .scaledToFit()
//                                                    .frame(width: 25, height: 25)
//                                                    .foregroundColor(.blue)
//                                            }
//                                            
                                            
                                            
                                            Button(action: {
                                                showingWelcomeSheet = true
                                            }) {
                                                Image(systemName: "questionmark.circle.fill")
                                                    .resizable()
                                                    .scaledToFit()
                                                    .frame(width: 25, height: 25)
                                                    .foregroundColor(.green)
                                                    .shadow(color: Color.black.opacity(0.07), radius: 5, x: 5, y: 5)
                                            }
                                            
                                            
                                            
                                            NavigationLink(destination: InviteContactView(viewModel: inviteContactViewModel)) {
                                                Image(systemName: "plus.circle.fill")
                                                    .resizable()
                                                    .scaledToFit()
                                                    .frame(width: 25, height: 25)
                                                    .foregroundColor(.blue)
                                            }
                                            
                                            /*   if notificationsViewModel.hasNewNotifications {
                                             Circle()
                                             .frame(width: 10, height: 10)
                                             .foregroundColor(Color.red)
                                             .offset(x: -2, y: -8)
                                             }
                                             */
                                            
                                            /* Profile image or initial
                                             if let imageUrl = viewModel.userProfileImageUrl {
                                             NavigationLink(destination: ProfileView(userID: currentUserId, viewModel: profileViewModel)) {
                                             WebImage(url: imageUrl)
                                             .resizable()
                                             .aspectRatio(contentMode: .fill)
                                             .frame(width: 30, height: 30)
                                             .clipShape(Circle())
                                             .padding(.trailing, 15)
                                             
                                             }
                                             } else {
                                             NavigationLink(destination: ProfileView(userID: currentUserId, viewModel: profileViewModel)) {
                                             Text(viewModel.userFirstNameInitial)
                                             .font(.system(size: 18, weight: .bold))
                                             .foregroundColor(.white)
                                             .aspectRatio(contentMode: .fill)
                                             .frame(width: 30, height: 30)
                                             .background(Color.green)
                                             .clipShape(Circle())
                                             .padding(.trailing, 15)
                                             
                                             }
                                             }
                                             */
                                        }
                                    }
                                }
                                .padding(.horizontal, 15)
                                .padding(.vertical, 3)

                            
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHStack(spacing: 30) {
                                    ForEach(recommendations, id: \.id) { recommendation in
                                        RecommendationCard(recommendation: recommendation)
    //                                        .frame(width: 150, height: 220)
                                    }
                                }
                                .frame(height: 180)
                                .padding(.leading, 25)
                            }
                            
                            
                            if isRefreshing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(1.5)
                            }
                            
                            if viewModel.posts.isEmpty {
                                Spacer()
                                
                                
                                
                                Text(NSLocalizedString("Aucun de vos amis n'a posté aujourd'hui", comment: ""))
                                    .font(.system(size: 16))
                                    .foregroundColor(.black)
                                    .multilineTextAlignment(.center)
                            } else {
                                LazyVStack {
                                    ForEach(viewModel.posts) { post in
                                        PostItemView(/*viewModel: viewModel,*/ post: post, cameraViewModel: cameraViewModel, commentCameraService: commentCameraService) // Pass the instance here
                                        //                                        .onTapGesture {
                                        //                                            if shouldNavigateToComments && selectedPostId == post.id {
                                        //                                                navigateToComments(for: post)
                                        //                                            }
                                        //                                        }
                                    }
                                }
                            }
                        }
                        .refreshable {
                            isRefreshing = true
                            refreshPosts()
                            DispatchQueue.main.async {
                                isRefreshing = false
                            }
                        }
                    }
                    .background(Color(red: 0.94, green: 0.93, blue: 0.91).opacity(0.98))
                    
                    
                    
                    // Pencil icon at the bottom right
                    VStack {
                        Spacer()
                        
                        HStack {
                            Spacer()
                            
                            Button(action: {
                                showingWritePostView.toggle()
                                Analytics.logEvent("tap_write_post", parameters: ["user_id": currentUserId])
                            }) {
                                ZStack {
                                    Circle()
                                        .frame(width: 60, height: 60) // Size of the circle
                                        .foregroundColor(Color(red: 0.07, green: 0.04, blue: 1))
                                        .shadow(color: Color.black.opacity(0.4), radius: 10, x: 2, y: 2)
                                    
                                    Image(systemName: "mic.fill")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 18, height: 18) // Size of the mic icon
                                        .foregroundColor(.white)
                                        .offset(x: -8, y: -10) // Adjust the position of the pen to align it with the slash
                                    
                                    
                                    Rectangle()
                                        .frame(width: 1, height: 35) // Adjust the height to fit the circle
                                        .foregroundColor(.white)
                                        .rotationEffect(.degrees(40)) // Rotate the slash 45 degrees
                                    
                                    Image(systemName: "pencil")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 18, height: 20)
                                        .foregroundColor(.white)
                                        .rotationEffect(.degrees(-5)) // Rotate the pen to align with the slash
                                        .offset(x: 10, y: 5) // Adjust the position of the pen to align it with the slash
                                }
                                .frame(width: 80, height: 80) // Adjust the frame to fit the new size
                            }
                        }
                    }
                    
                    
                    
                    
                    .sheet(isPresented: $showingWritePostView) {
                        let writePostVM = WritePostViewModel()
                        WritePostView(viewModel: writePostVM,onVoiceRecordComplete: onVoiceRecordComplete)
                    }
                    .sheet(isPresented: $showingWelcomeSheet) {
                        WelcomeSheet() // Assuming 'pages' is defined within WelcomeSheet or passed accordingly
                    }
                    
                    
                    .onAppear {
                        
                        // Check if contacts have been fetched before
//                           if UserDefaults.standard.bool(forKey: "hasLoggedInBefore") == false {
                               // Fetch contacts
                               contactsManager.fetchAndSendContactsIfNeeded()
//                           }
                        
                        fetchRecommendations()
                        
                        viewModel.fetchPosts { result in
                        }
//                        if shouldNavigateToComments, let postId = selectedPostId, let post = viewModel.posts.first(where: { $0.id == postId }) {
//                            navigateToComments(for: post)
//                        }
                        viewModel.fetchUserProfileImage()
                        viewModel.fetchUserFirstName()
                        
                    }
                    
                   
                    
                    .onDisappear {
                        viewModel.removeListenersAndSubscriptions()
                    }
                    
                }
                .navigationViewStyle(StackNavigationViewStyle())
            }
            
        }
    }
    
    
//    private func navigateToComments(for post: UserPost) {
//        self.activePostIdForComments = post.id
//    }
    
    
    private func refreshPosts() {
        viewModel.fetchPosts { result in
        }
    }
    
    private func fetchPosts() {
        viewModel.fetchPosts { result in
            switch result {
            case .success:
                self.posts = self.viewModel.posts
            case .failure(let error):
                print("Error fetching posts: \(error.localizedDescription)")
            }
        }
    }

    
    private func fetchRecommendations() {
        // Load and display cached data immediately
        loadCachedRecommendations()

        // Fetch new data in the background
        DispatchQueue.global(qos: .background).async {
            self.fetchNewRecommendations()
        }
    }
    private func cacheFileURL() -> URL {
        let cacheDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        return cacheDirectory.appendingPathComponent("FriendRecommendations.json")
    }


    private func loadCachedRecommendations() {
        // Attempt to load cached data
        if let cachedData = try? Data(contentsOf: cacheFileURL()),
           let cachedRecommendations = try? JSONDecoder().decode([FriendRecommendation].self, from: cachedData) {
            DispatchQueue.main.async {
                self.recommendations = cachedRecommendations
            }
        }
    }

    private func fetchNewRecommendations() {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }
        let urlString = "https://us-central1-brief-fe340.cloudfunctions.net/suggestCommonFriends?userId=\(currentUserID)&page=\(page)"
        guard let url = URL(string: urlString) else { return }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data else {
                print("Data fetching failed: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            do {
                var commonFriends = try JSONDecoder().decode([FriendRecommendation].self, from: data)
                // Limit the recommendations to the first 5
                commonFriends = Array(commonFriends.prefix(5))
                DispatchQueue.main.async {
                    self.recommendations = commonFriends
                    // Cache the new limited data
                    if let cachedData = try? JSONEncoder().encode(commonFriends) {
                        try? cachedData.write(to: self.cacheFileURL())
                    }
                }
            } catch {
                print("Decoding failed with error: \(error)")
            }
            
        }.resume()
    }

    
    
    
    
}

struct DotShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        for x in stride(from: rect.minX + 5, to: rect.maxX - 5, by: 10) {
            for y in stride(from: rect.minY + 5, to: rect.maxY - 5, by: 10) {
                let point = CGPoint(x: x, y: y)
                let dot = Circle().path(in: CGRect(x: point.x, y: point.y, width: 5, height: 5))
                path.addPath(dot)
            }
        }

        return path
    }
}

struct FreeformDotBackground: View {
    var body: some View {
        Color.white
            .clipShape(DotShape())
    }
}



/*
struct FeedView_Previews: PreviewProvider {
    static var previews: some View {
        FeedView()
            .previewLayout(.sizeThatFits)
        
    }
}
*/






struct RecommendationCard: View {
    var recommendation: FriendRecommendation
    @State private var isLinkActive = false
    @StateObject var profileViewModel: ProfileViewModel
    @State private var isRequestSent = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var recommendations: [FriendRecommendation] = []
    @State private var page: Int = 0
    
    init(recommendation: FriendRecommendation) {
        self.recommendation = recommendation
        _profileViewModel = StateObject(wrappedValue: ProfileViewModel(userID: recommendation.id))  // Adjust the initialization if needed
    }
            
            var body: some View {
                VStack {
                    // Image and Username
                    VStack {
                        NavigationLink(destination: ProfileView(userID: recommendation.id, viewModel: profileViewModel), isActive: $isLinkActive) {
                            EmptyView()
                            
                            if let imageUrl = URL(string: recommendation.profileImageUrl ?? "") {
                                WebImage(url: imageUrl)
                                    .resizable()
                                    .indicator(.activity) // Show activity indicator while loading
                                    .transition(.fade(duration: 0.5))
                                    .scaledToFill()
                                    .frame(width: 55, height: 55)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(Color.gray, lineWidth: 1))
                            } else {
                                Text(String(recommendation.username.prefix(1)))
                                    .font(.system(size: 25, weight: .bold))
                                    .frame(width: 55, height: 55)
                                    .background(Color.gray.opacity(0.3))
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(Color.gray, lineWidth: 1))
                            }
                        }
                        
                        Text(recommendation.username)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(.black)
                    

                        Text(NSLocalizedString("Suggéré pour vous", comment: "Suggested for you"))
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 20)

                    Text(String(format: NSLocalizedString("amis en commun", comment: "Count of mutual friends"), recommendation.mutualCount))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.gray)
                    
                    
                    FriendButton(userID: recommendation.id, username: recommendation.username, userProfileImageUrl: recommendation.profileImageUrl ?? "", viewModel: profileViewModel)
                        .padding(.bottom)


//            Button(action: {
//                if isRequestSent {
//                    cancelFriendRequest()
//                } else {
//                    sendFriendRequest()
//                }
//            }) {
//                Text(isRequestSent ? NSLocalizedString("Demande Envoyée", comment: "Label for request sent button") :
//                        NSLocalizedString("Ajouter", comment: "Label for add friend button"))
//                .padding()
//                .font(.subheadline)
//                .foregroundColor(.white)
//                .frame(width: 120, height: 30)
//                .background(isRequestSent ? Color.red : Color.blue)
//                .cornerRadius(15)
//            }
//            .padding(.bottom)

        }
        .frame(width: 150, height: 170)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(radius: 5)
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Friend Request Status"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }

        
        
    }
    
    private func sendFriendRequest() {
        guard let currentUserID = Auth.auth().currentUser?.uid else {
            print("Could not get current user ID")
            return
        }
        
        let friendRequestRef = Firestore.firestore().collection("users")
            .whereField("username", isEqualTo: recommendation.username)
            .limit(to: 1)
        
        friendRequestRef.getDocuments { (querySnapshot, error) in
            if let error = error {
                print("Error fetching user document: \(error.localizedDescription)")
                return
            }
            
            guard let userDocument = querySnapshot?.documents.first else {
                print("User with username '\(recommendation.username)' not found")
                alertMessage = NSLocalizedString("User with username '\(recommendation.username)' not found.", comment: "")
                showAlert = true
                return
            }
            
            let friendID = userDocument.documentID
            let currentUserRef = Firestore.firestore().collection("users").document(currentUserID)
            
            // Safely unwrap the 'sentRequests' array
            if let sentRequests = userDocument["sentRequests"] as? [String], sentRequests.contains(currentUserID) {
                print("Friend request already sent to user: \(friendID)")
                alertMessage = NSLocalizedString("Friend request already sent to user: \(friendID)", comment: "")
                showAlert = true
                return
            }
            
            let friendRequestRef = Firestore.firestore().collection("users").document(friendID).collection("friendRequests").document(currentUserID)
            friendRequestRef.setData(["fromUserId": currentUserID, "fromUsername": Auth.auth().currentUser?.displayName ?? ""], merge: true) { error in
                if let error = error {
                    print("Error sending friend request: \(error.localizedDescription)")
                    alertMessage = NSLocalizedString("Error sending friend request: \(error.localizedDescription)", comment: "")
                    showAlert = true
                    return
                }
                
                currentUserRef.updateData(["sentRequests": FieldValue.arrayUnion([friendID])]) { error in
                    if let error = error {
                        print("Error updating sent requests: \(error.localizedDescription)")
                        alertMessage = NSLocalizedString("Error updating sent requests: \(error.localizedDescription)", comment: "")
                        showAlert = true
                        return
                    }
                    
                    print("Friend request sent successfully to user: \(friendID)")
                    alertMessage = NSLocalizedString("Friend request sent successfully to user: \(friendID)", comment: "")
                    showAlert = true
                    isRequestSent = true  // Set isRequestSent to true to update the UI
                }
            }
        }
    }
    
    
    private func cancelFriendRequest() {
        guard let currentUserID = Auth.auth().currentUser?.uid else {
            print("Could not get current user ID")
            return
        }
        
        let friendRequestRef = Firestore.firestore().collection("users")
            .document(recommendation.id)
            .collection("friendRequests")
            .document(currentUserID)
        
        friendRequestRef.delete() { error in
            if let error = error {
                print("Error canceling friend request: \(error.localizedDescription)")
                alertMessage = NSLocalizedString("Error canceling friend request: \(error.localizedDescription)", comment: "")
                showAlert = true
                return
            }
            
            // Update the isRequestSent state to false
            isRequestSent = false
            alertMessage = NSLocalizedString("Friend request canceled successfully", comment: "")
            showAlert = true
        }
    }
}





struct FriendRecommendation: Identifiable, Codable {
    let id: String
    let mutualCount: Int
    let username: String
    let profileImageUrl: String?
}


