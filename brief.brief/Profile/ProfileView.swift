//
//  ProfileView.swift
//  brief.brief
//
//  Created by Philippe Tchinda on 26/04/2023.
//

import SwiftUI
import Firebase
import SDWebImageSwiftUI
import FirebaseFirestore
import FirebaseStorage
import PhotosUI
import MessageUI
import SDWebImage
import FirebaseAnalytics


struct ProfileView: View {
    let userID: String
    @StateObject var viewModel: ProfileViewModel

    @State private var showingImagePicker = false
    @State private var inputImage = UIImage()
    @State private var showingSettings = false
    @State private var isRefreshing = false
    @State private var showingBannerImagePicker = false
    @State private var bannerImage = UIImage()
    @State private var isPickingBannerImage = false
    @State public var isSelected = false
    @Environment(\.presentationMode) var presentationMode
    @GestureState private var dragOffset: CGFloat = 0
    @State private var isUserAFriend = false
    @State private var showingBlockUserActionSheet = false
    @State private var isShowingQRScanner = false
    private var commentCameraService = CommentCameraService()
    @State private var showingFriendsList = false

    

    
    // Assuming 'isShowingQRScanner' is a Bool property of the class/struct
    init(userID: String, viewModel: ProfileViewModel) {
        self.userID = userID
        _viewModel = StateObject(wrappedValue: viewModel)
    }



        private func preloadImages() {
            // Pre-cache the profile and banner images if URLs are available
            if let profileURL = viewModel.userProfileImageUrl {
                cacheImage(url: profileURL)
            }
            if let bannerURL = viewModel.userBannerImageUrl {
                cacheImage(url: bannerURL)
            }
        }
    
    private func cacheImage(url: String) {
        guard let imageURL = URL(string: url) else { return }
        SDWebImageManager.shared.loadImage(
            with: imageURL,
            options: .highPriority,
            progress: nil) { (image, data, error, cacheType, finished, url) in
                // Your code here if needed
        }
    }
    
    private func logNumberOfPosts() {
        Analytics.logEvent("user_post_count", parameters: [
            "user_id": userID,
            "post_count": viewModel.posts.count
        ])
    }
    
    private func blockUser() {
        guard let currentUserID = Auth.auth().currentUser?.uid else {
            print("Error: Could not fetch current user ID.")
            return
        }

        let db = Firestore.firestore()
        let userRef = db.collection("users").document(currentUserID)

        // Using Firestore Transaction to ensure atomicity
        db.runTransaction { (transaction, errorPointer) -> Any? in
            let userDocument: DocumentSnapshot
            do {
                try userDocument = transaction.getDocument(userRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }

            guard let oldBlockedUsers = userDocument.data()?["blockedUsers"] as? [String] else {
                let error = NSError(
                    domain: "AppErrorDomain",
                    code: -1,
                    userInfo: [
                        NSLocalizedDescriptionKey: "Unable to retrieve blockedUsers from snapshot \(userDocument)"
                    ]
                )
                errorPointer?.pointee = error
                return nil
            }

            // Add the new blocked user ID to the array
            var updatedBlockedUsers = oldBlockedUsers
            updatedBlockedUsers.append(self.userID)
            
            // Update the blockedUsers field in Firestore
            transaction.updateData(["blockedUsers": updatedBlockedUsers], forDocument: userRef)

            return nil
        } completion: { (object, error) in
            if let error = error {
                print("Transaction failed: \(error)")
            } else {
                print("Transaction successfully committed!")
            }
        }
    }



    


    
    var body: some View {
            ZStack {
                Color(red: 0.94, green: 0.93, blue: 0.91).opacity(0.98)
//                    .edgesIgnoringSafeArea(.all)
                

                ScrollView {
                    VStack {
                        ZStack(alignment: .leading) { // Changed to topLeading for alignment
                            // Banner
                            if let bannerImageUrl = viewModel.userBannerImageUrl {
                                WebImage(url: URL(string: bannerImageUrl))
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.width * 1)
                                    .clipped()
                            } else {
                                Rectangle()
                                    .foregroundColor(.gray)
                                    .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.width * 1)
                            }
                            
                            // Gradient Overlay
                            LinearGradient(gradient: Gradient(colors: [.clear, .black.opacity(1)]),
                                           startPoint: .top,
                                           endPoint: .bottom)
                                .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.width * 1)

                            
                            
                            // Add "+" button to top-right corner of the banner
                            if userID == Auth.auth().currentUser?.uid {
                                VStack {
                                    HStack {
                                        Spacer()
                                        Button(action: {
                                            Analytics.logEvent("banner_image_picker_presented", parameters: ["user_id": userID])
                                            self.showingBannerImagePicker = true
                                        }) {
                                            Image(systemName: "plus.circle.fill")
                                                .foregroundColor(.blue)
                                                .font(.system(size: 16))
                                                .background(Color.white)
                                                .clipShape(Circle())
                                        }
                                        .padding(.trailing, 16)
                                        .padding(.bottom,  180)
                                    }
                                }
                            }
                                
                            VStack {

                                Spacer() // Pushes content to the bottom
                                HStack {
                                    Text("\(viewModel.firstName)")         /*\(viewModel.lastName)*/
                                        .font(.title)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white) // Changed to white for better visibility on dark gradient
                                        .padding(.leading, 20)
                                        .padding(.bottom, 20) // Adjust padding as needed
                                    Spacer() // Pushes content to the leading edge
                                    
                                    Text("brief 📸: \(viewModel.postCount)")
                                        .font(.caption)
                                        .foregroundColor(.white)
                                        .padding(10)
                                        .background(Color.black.opacity(0.5))
                                        .cornerRadius(20)
                                        .padding(.bottom, 20)
                                    
                                    
                                    Button(action: {
                                        viewModel.fetchFriendsList(forUserID: userID) { fetchedFriends in
                                            if let fetchedFriends = fetchedFriends {
                                                viewModel.friends = fetchedFriends
                                                showingFriendsList = true
                                            }
                                        }
                                    }) {
                                        HStack {
                                            Image(systemName: "person.2.fill")
                                                .foregroundColor(.white)
                                            Text(NSLocalizedString("Voir les amis", comment: ""))
                                                .font(.caption)
                                                .foregroundColor(.white)
                                        }
                                        .padding(10)
                                        .background(.ultraThinMaterial)
                                        .cornerRadius(20)
                                    }
                                    .sheet(isPresented: $showingFriendsList) {
                                        NavigationView {
                                            FriendsListView(friends: viewModel.friends)
                                        }
                                    }
                                    
                                }
                            }

                                    

                                    



                            // Profile Picture with "+" button
                            ZStack {
                                // Profile Picture
                                VStack {
                                    if let imageUrl = viewModel.userProfileImageUrl {
                                        WebImage(url: URL(string: imageUrl))
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 90, height: 90)
                                            .clipShape(Circle())
                                            .contentShape(Circle()) // Define the tappable area
                                            .overlay(Circle().stroke(Color.white, lineWidth: 1))
                                            .shadow(radius: 10)
                                            .padding(.leading, 275)
                                    } else {
                                        Color.gray
                                            .frame(width: 90, height: 90)
                                            .clipShape(Circle())
                                            .contentShape(Circle()) // Define the tappable area
                                            .overlay(Circle().stroke(Color.white, lineWidth: 1))
                                            .shadow(radius: 10)
                                            .padding(.leading, 275)
                                    }
                                    
          
                                }
                                
                                if userID == Auth.auth().currentUser?.uid {
                                    Button(action: {
                                        Analytics.logEvent("image_picker_presented", parameters: ["user_id": userID])
                                        self.showingImagePicker = true
                                    }) {
                                        Image(systemName: "plus.circle.fill")
                                            .foregroundColor(.blue)
                                            .font(.system(size: 16))
                                            .background(Color.white)
                                            .clipShape(Circle())

                                    }
                                    .offset(x: 165, y: 40)
                                }
                            }
                            .offset(y: 60)
                        }
                        

                        
                        
                // User's bio
                Text(viewModel.bio)
                    .font(.custom("Nanum Pen", size: 20))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 20)
                    .padding(.top, 3)
                        
                        

                           
                        HStack(alignment: .top, spacing: 10) {
                            
//                            friendButton()
                            
                            FriendButton(userID: userID, username: viewModel.username, userProfileImageUrl: viewModel.userProfileImageUrl ?? "", viewModel: viewModel)
                            
                            Button(action: {
                                
                                Analytics.logEvent("poke", parameters: nil)
                                
                                viewModel.sendPokeToUser(recipientId: userID)
                            }) {
                                HStack {
                                    Text(NSLocalizedString("Envoyer un 🫵", comment: ""))
                                        .foregroundColor(.black)
                                        .font(.system(size: 15, weight: .medium))
                                        .frame(minWidth: 0, maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(Color(red: 0.9, green: 0.9, blue: 0.9))
                                        .cornerRadius(10)
                                }
                                .padding(.horizontal, 20)
                            }
                        }



                            

                            
//                            if viewModel.posts.isEmpty {
//                                VStack {
//                                    Text(NSLocalizedString("Posts", comment: "Posts"))
//                                        .font(.title2)
//                                        .bold()
//                                        .padding(.top, 20)
//                                        .foregroundColor(.black)
//                                    
//                                    // Conditional message for non-friends
//                                    if userID != Auth.auth().currentUser?.uid &&
//                                       !viewModel.friends.contains(where: { $0.id == userID }) {
//                                        Text(NSLocalizedString("Vous devez être ami pour voir les posts de cet utilisateur.", comment: "You must be friends to see this user's posts."))
//                                            .foregroundColor(.black)
//                                    } else {
//                                        Text(NSLocalizedString("L'utilisateur n'a pas encore publié aujourd'hui.", comment: "The user has not posted today."))
//                                            .foregroundColor(.black)
//                                    }
//                                }
//                                .frame(maxWidth: .infinity, maxHeight: .infinity)
//                            } else {
//                                                VStack(alignment: .leading) {
//                                                    Text(NSLocalizedString("Posts", comment: "Posts"))
//                                                        .font(.title2)
//                                                        .bold()
//                                                        .padding(.top, 20)
//                                                        .padding(.leading, 20)
//                                                        .foregroundColor(.black)
                                                    
                                                    
                        LazyVStack {
                            MemoriesCalendarView(userID: userID)
                        }
//                                                    ForEach(viewModel.posts, id: \.id) { post in
//                                                        PostItemView(/*viewModel: FeedViewModel(),*/post: post, cameraViewModel: CameraViewModel(), commentCameraService: commentCameraService)
//
                                                            .frame(maxWidth: .infinity)
//                                                    }
//                                                }
//                                            }
                                        }
                                    }
                                }
        
        
                                .navigationBarTitleDisplayMode(.inline)
        .navigationBarColor(backgroundColor: UIColor(Color(red: 0.94, green: 0.93, blue: 0.91).opacity(0.98))
,
                            titleColor: .white)
//        .refreshable {
//            isRefreshing = true
//            viewModel.fetchPosts()
//            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
//                isRefreshing = false
//                logNumberOfPosts()
//            }
//        }
        .sheet(isPresented: $showingImagePicker, onDismiss: loadImage) {
            ImagePicker(selectedImage: self.$inputImage)
    
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(/*viewModel: viewModel,*/ isShowingQRScanner: $isShowingQRScanner)
            
        }
        .sheet(isPresented: $showingBannerImagePicker, onDismiss: loadBannerImage) {
                    ImagePicker(selectedImage: self.$bannerImage)
                
        }
        
        .onAppear {
            viewModel.fetchPostCount(forUserID: userID)
                   preloadImages()
            
            viewModel.fetchUserProfileImage()
            viewModel.fetchUserFirstName()
            viewModel.fetchUserInfo()
            viewModel.fetchBannerImageUrl()

            
               }
        
                /*.toolbar {
                    // Custom back button with left arrow
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: {
                            self.presentationMode.wrappedValue.dismiss()
                        }) {
                            Image(systemName: "arrow.left") // You can replace this with your custom arrow image
                                .foregroundColor(.black)
                        }
                    }
            
        } */
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Text(viewModel.username)
                            .font(.system(.body, design: .default).weight(.bold))
                            .foregroundColor(.white)
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        trailingBarItem
                    }
                }
                .edgesIgnoringSafeArea(.top) // This ensures the ScrollView content extends into the safe area

            }

            @ViewBuilder
            var trailingBarItem: some View {
                if userID == Auth.auth().currentUser?.uid {
                    Button(action: {
                        Analytics.logEvent("settings_presented", parameters: ["user_id": userID])
                        print("Settings button pressed.")
                        showingSettings = true
                    }) {
                        Image(systemName: "gear")
                            .foregroundColor(.white)
                    }
                } else {
                    Button(action: {
                        showingBlockUserActionSheet = true
                    }) {
                        Image(systemName: "ellipsis")
                            .foregroundColor(.white)
                    }
                    .actionSheet(isPresented: $showingBlockUserActionSheet) {
                        ActionSheet(title: Text("Block User"), message: Text("Are you sure you want to block this user?"), buttons: [
                            .destructive(Text("Block"), action: {
                                blockUser()
                            }),
                            .cancel()
                        ])
                    }
                }
            }
    
    
    struct ProfileView_Previews: PreviewProvider {
        static var previews: some View {
            // Create a mock user ID and ProfileViewModel
            let mockUserID = "12345"
            let mockViewModel = ProfileViewModel(userID: mockUserID)

            // Populate the mock ViewModel with sample data as needed
            mockViewModel.username = "Sample User"
            mockViewModel.bio = "This is a sample bio."
            // Add more mock data as needed

            return ProfileView(userID: mockUserID, viewModel: mockViewModel)
        }
    }
        
        

    func loadBannerImage() {
        if userID == Auth.auth().currentUser?.uid {
            guard bannerImage != UIImage() else { return }
            guard let imageData = bannerImage.jpegData(compressionQuality: 0.5) else { return }
            
            viewModel.uploadBannerImage(imageData: imageData) { url in
                guard let url = url else { return }
                viewModel.userBannerImageUrl = url
                viewModel.updateBannerImageUrlInFirestore(url: url)
            }
        }
    }



    
    func loadImage() {
        if userID == Auth.auth().currentUser?.uid {
            guard inputImage != UIImage() else { return }
            guard let imageData = inputImage.jpegData(compressionQuality: 0.5) else { return }
            
            viewModel.uploadProfilePicture(imageData: imageData) { url in
                guard let url = url else { return }
                viewModel.userProfileImageUrl = url
                viewModel.updateProfileImageUrlInFirestore(url: url)
            }
        }
    }
}

    
extension View {
    public func navigationBarColor(backgroundColor: UIColor, titleColor: UIColor) -> some View {
        self.modifier(NavigationBarModifier(backgroundColor: backgroundColor, titleColor: titleColor))
    }
}


struct FriendsListView: View {
    var friends: [User]

    var body: some View {
        List(friends) { friend in
            NavigationLink(destination: ProfileView(userID: friend.id, viewModel: ProfileViewModel(userID: friend.id))) {
                HStack {
                    if let imageUrl = friend.profileImageUrl, let url = URL(string: imageUrl) {
                        WebImage(url: url) // Assuming you're using SDWebImageSwiftUI
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())
                    } else {
                        Image(systemName: "person.fill")
                            .resizable()
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())
                            .foregroundColor(.gray)
                    }
                    Text(friend.username)
                        .fontWeight(.medium)
                }
            }
        }
    }
}


struct NavigationBarModifier: ViewModifier {
    var backgroundColor: UIColor
    var titleColor: UIColor

    init(backgroundColor: UIColor, titleColor: UIColor) {
        self.backgroundColor = backgroundColor
        self.titleColor = titleColor

        let coloredAppearance = UINavigationBarAppearance()
        coloredAppearance.configureWithTransparentBackground()
        coloredAppearance.backgroundColor = .clear
        coloredAppearance.titleTextAttributes = [.foregroundColor: titleColor]
        coloredAppearance.largeTitleTextAttributes = [.foregroundColor: titleColor]

        UINavigationBar.appearance().standardAppearance = coloredAppearance
        UINavigationBar.appearance().compactAppearance = coloredAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = coloredAppearance
        UINavigationBar.appearance().tintColor = titleColor
    }

    func body(content: Content) -> some View {
        ZStack{
            content
            VStack {
                GeometryReader { geometry in
                    Color(backgroundColor)
                        .frame(height: geometry.safeAreaInsets.top)
                        .edgesIgnoringSafeArea(.top)
                    Spacer()
                }
            }
        }
    }
}


struct FriendButton: View {
    let userID: String
    let username: String
    let userProfileImageUrl: String
    @ObservedObject var viewModel: ProfileViewModel
    
    var body: some View {
        friendButton()
    }
    
    // Add this function
    @ViewBuilder
    private func friendButton() -> some View {
        if userID == Auth.auth().currentUser?.uid || viewModel.currentFriends.contains(userID) {
            // Hide the button if viewing own profile or already friends
        } else if let isSelected = viewModel.isSelected {
            Button(action: {
                if isSelected {
                    Analytics.logEvent("friend_request_canceled", parameters: ["user_id": userID])
                    viewModel.cancelFriendRequest(User(id: userID, username: username, firstName: "", lastName: "", isInvited: false, name: "", friends: [], friendRequestsSent: [], profileImageUrl: userProfileImageUrl))
                    viewModel.isSelected = false
                } else if viewModel.incomingFriendRequests.contains(userID) {
                    Analytics.logEvent("friend_request_accepted", parameters: ["user_id": userID])
                    viewModel.acceptFriendRequest(userID)
                } else {
                    Analytics.logEvent("friend_request_sent", parameters: ["user_id": userID])
                    viewModel.sendFriendRequest(User(id: userID, username: username, firstName: "", lastName: "", isInvited: false, name: "", friends: [], friendRequestsSent: [], profileImageUrl: userProfileImageUrl))
                    viewModel.isSelected = true
                }
            }) {
                Text(isSelected ? NSLocalizedString("Envoyée", comment: "Request sent") : viewModel.incomingFriendRequests.contains(userID) ? NSLocalizedString("Accepter", comment: "Accept friend request") : NSLocalizedString("Ajouter", comment: "Add as friend"))
                    .font(.system(size: 15, weight: .medium)) // Adjust font size and weight as necessary
                    .foregroundColor(.white) // Text color
                    .frame(minWidth: 0, maxWidth: .infinity) // Make the button expand to the maximum width
                    .padding(.vertical, 10) // Vertical padding
                    .background(isSelected ? Color.green : viewModel.incomingFriendRequests.contains(userID) ? Color.black : Color.blue) // Background color of the button
                    .cornerRadius(10) // Rounded corner radius
            }
            .padding(.horizontal, 20) // Padding to the sides of the button
        } else {
            // Data is still loading, you could show a loading spinner here or just hide the button
        }
    }
}
