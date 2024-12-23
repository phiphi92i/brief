//
//  AddFriendView.swift
//  brief.brief
//
//  Created by Philippe Tchinda on 04/06/2023.
//

import SwiftUI
import UIKit
import Firebase
import FirebaseAuth
import FirebaseFirestore
import SDWebImageSwiftUI
import Contacts
import FirebaseDatabase
import MessageUI
import CoreImage.CIFilterBuiltins
import AVFoundation
import Photos
import FirebaseAnalytics
import NukeUI
import Foundation
import FirebaseStorage




enum SelectedView {
    case suggestions
    case addFriend
    case distributionCircles
}

extension View {
    func eraseToAnyView() -> AnyView {
        AnyView(self)
    }
}



struct QRCodeView: View {
    @Binding var isShowingQRScanner: Bool
    @State private var qrCodeImage: UIImage?
    @State private var isShareSheetShowing: Bool = false
    @State public var userProfileImageUrl: String?
    @State public var userFirstNameInitial: String = ""
    @Environment(\.dismiss) var dismiss
    @State public var username: String = ""
    @State private var fetchedProfileImage: UIImage?

    
    public let storage = Storage.storage()
    @State public var  userID: String
    
    var codeScannerView = CodeScannerView(
        codeTypes: [AVMetadataObject.ObjectType.qr],
        completion: { result in
            // handle the result
        }
    )
    
    

    
    var body: some View {
        ZStack {
            Color(red: 0.94, green: 0.93, blue: 0.91).opacity(0.98).ignoresSafeArea()
            
            VStack {
                // Top bar with Close, Title, and Share buttons
                HStack {
                    // Close Button
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .imageScale(.large)
                            .foregroundColor(.black)
                    }
                    Spacer()
                    // Title Text
                    Text(NSLocalizedString("Mon code QR", comment: "My QR Code Text"))
                        .font(.subheadline)
                    Spacer()
                    // Share Button Action
                    Button(action: {
                        Analytics.logEvent("clicked_share_qr", parameters: nil)
                        // Ensure the profile image has been fetched before trying to generate the composite image
                        if fetchedProfileImage != nil {
                            let compositeImage = generateCompositeImage()
                            self.qrCodeImage = compositeImage // Update this to share the composite image
                        }
                        // Now show the share sheet
                        self.isShareSheetShowing.toggle()
                    }) {
                        Image(systemName: "square.and.arrow.up")
                            .imageScale(.large)
                            .foregroundColor(.blue)
                    }

                }
                .padding()
                
                Spacer()
                
                // QR Code and Profile Image
                ZStack {
                    RoundedRectangle(cornerRadius: 15)
                        .frame(width: 300, height: 300)
                        .foregroundColor(.white)
                    
                    if let image = qrCodeImage {
                        Image(uiImage: image)
                            .resizable()
                            .frame(width: 200, height: 200)
                    }
                    
                    // Profile Image
                    VStack {
                        if let imageUrl = URL(string: userProfileImageUrl ?? "") {
                            WebImage(url: imageUrl)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 50, height: 50)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.white, lineWidth: 4))
                                .background(Color.white)
                                .clipShape(Circle())
                        } else {
                            Text(userFirstNameInitial)
                                .font(.largeTitle)
                                .frame(width: 50, height: 50)
                                .background(Color.gray)
                                .clipShape(Circle())
                                .foregroundColor(.black)
                        }
                        
                        Text(username)
                               .font(.subheadline)
                               .foregroundColor(.black)
                    }
                    .offset(y: -150)
                }
                
                Spacer()
                
                // Scanner Button
                Button(action: {
                    Analytics.logEvent("clicked_open_qr_scanner", parameters: nil)
                    self.isShowingQRScanner = true
                }) {

                    Label(NSLocalizedString("Scanner", comment: "Invite friends"), systemImage: "barcode.viewfinder")
                        .labelStyle(.titleAndIcon)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(8)
                }
            }
        }
    

        
        .sheet(isPresented: $isShowingQRScanner) {
            self.codeScannerView
        }
        .sheet(isPresented: $isShareSheetShowing) {
            if let qrCodeImage = qrCodeImage {
                ShareSheet(activityItems: [qrCodeImage, "Ajoute moi en scannant mon code QR sur brief ! : https://brief-social.com"])
            }
        }


        
        .onAppear {
            generateAndSetQRCode()
            fetchUserProfileImage()
            fetchUserInfo()
            if let userProfileImageUrl = userProfileImageUrl {
                   fetchImageAsync(from: userProfileImageUrl) { [ self] image in
                       self.fetchedProfileImage = image
                     
                   }
               }
           
        }
        
    }
    

    
    
    func generateAndSetQRCode() {
        if let currentUserID = Auth.auth().currentUser?.uid {
            if let image = generateQRCode(from: currentUserID) {
                self.qrCodeImage = image
            }
        }
    }
    
    func generateCompositeImage() -> UIImage? {
        let size = CGSize(width: 300, height: 350) // Size of the entire composite image
        let qrCodeSize: CGFloat = 200 // Define qrCodeSize within the function scope

        UIGraphicsBeginImageContextWithOptions(size, false, UIScreen.main.scale)
        
        // Draw the QR code centered in the context
        if let qrCodeImage = qrCodeImage {
            qrCodeImage.draw(in: CGRect(
                x: (size.width - qrCodeSize) / 2,
                y: (size.height - qrCodeSize) / 2 - 50, // Adjust the Y position to match your design
                width: qrCodeSize,
                height: qrCodeSize
            ))
        }
        
        // Draw the profile image (circle)
        if let profileImage = fetchedProfileImage {
            let profileImageSize: CGFloat = 50 // Size of the profile image
            let profileImageRect = CGRect(
                x: (size.width - profileImageSize) / 2,
                y: (size.height - qrCodeSize) / 2 - profileImageSize - qrCodeSize / 2, // Adjust Y position to match your design
                width: profileImageSize,
                height: profileImageSize
            )
            profileImage.draw(in: profileImageRect)
        }
        
        // Draw the username text below the profile image
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 16),
            .foregroundColor: UIColor.black
        ]
        let textString = NSAttributedString(string: username, attributes: textAttributes)
        let textPoint = CGPoint(
            x: (size.width - textString.size().width) / 2,
            y: (size.height - qrCodeSize) / 2 + qrCodeSize / 2 + 10 // Adjust Y position to match your design
        )
        textString.draw(at: textPoint)
        
        let finalImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return finalImage
    }


    
    
    func generateQRCode(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        let data = Data(string.utf8)
        filter.setValue(data, forKey: "inputMessage")
        
        if let outputImage = filter.outputImage {
            let transform = CGAffineTransform(scaleX: 10, y: 10) // Scale by 10 times
            let scaledOutputImage = outputImage.transformed(by: transform)
            
            if let cgImage = context.createCGImage(scaledOutputImage, from: scaledOutputImage.extent) {
                return UIImage(cgImage: cgImage)
            }
        }
        return nil
    }
    
    
    
    struct ShareSheet: UIViewControllerRepresentable {
        let activityItems: [Any]
        let excludedActivityTypes: [UIActivity.ActivityType]?
        var completion: UIActivityViewController.CompletionWithItemsHandler? // Add this line

        // Provide a default value for `excludedActivityTypes` and initialize `completion`
        init(activityItems: [Any], excludedActivityTypes: [UIActivity.ActivityType]? = nil, completion: UIActivityViewController.CompletionWithItemsHandler? = nil) {
            self.activityItems = activityItems
            self.excludedActivityTypes = excludedActivityTypes
            self.completion = completion // Initialize completion
        }

        func makeUIViewController(context: Context) -> UIActivityViewController {
            let activityViewController = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
            activityViewController.excludedActivityTypes = excludedActivityTypes
            activityViewController.completionWithItemsHandler = completion // Use completion here
            return activityViewController
        }
        
        func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
            // This method can be left empty if there's nothing to update.
        }
    }

    // Extension for saving images and possibly extending for more direct Instagram interactions
        private func saveImageToPhotosAlbum(image: UIImage?) {
            PHPhotoLibrary.requestAuthorization { status in
                switch status {
                case .authorized:
                    if let imageToSave = image {
                        UIImageWriteToSavedPhotosAlbum(imageToSave, nil, nil, nil)
                    }
                default:
                    // Handle other cases such as .denied, .restricted, etc.
                    break
                }
            }
        }
    
    
    func fetchUserProfileImage() {
        guard !userID.isEmpty else {
            print("UserID is empty, cannot fetch profile image.")
            return
        }
        
        let storageRef = storage.reference().child("profileImages/\(userID).jpg")
        storageRef.downloadURL { [ self] url, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Error fetching profile image URL: \(error)")
                    // Handle error or set a default image
                } else if let downloadURL = url {
                    self.userProfileImageUrl = downloadURL.absoluteString
                }
            }
        }
    }
    
    
    func fetchImageAsync(from urlString: String, completion: @escaping (UIImage?) -> Void) {
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }

        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, error == nil, let image = UIImage(data: data) else {
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }
            DispatchQueue.main.async {
                completion(image)
            }
        }.resume()
    }

    
    func fetchUserInfo() {
        guard !userID.isEmpty else {
            print("UserID is empty.")
            return
        }
        
        let db = Firestore.firestore()
        db.collection("users").document(self.userID).getDocument { document, error in // Removed [weak self]
            guard let document = document, document.exists else {
                print("Document does not exist.")
                return
            }
            if let data = document.data() {
                self.username = data["username"] as? String ?? ""
                // Further processing...
            }
        }
    }
}


   
    
    





struct MyPicker: View {
    @Binding var selectedView: SelectedView
    
    var body: some View {
        Picker("", selection: $selectedView) {
            Text(NSLocalizedString("Suggestions", comment: "For Suggestions tab")).tag(SelectedView.suggestions)
            Text(NSLocalizedString("Amis", comment: "For Add Friend tab")).tag(SelectedView.addFriend)
            Text(NSLocalizedString("Cercles", comment: "For Distribution Circles tab")).tag(SelectedView.distributionCircles)
        }
        .pickerStyle(SegmentedPickerStyle())
        .frame(width: 280, height: 80)
        .foregroundColor(.black)
        .colorScheme(.dark)
        .cornerRadius(10)
        .offset(y: 10)  // Exact positioning
        .onChange(of: selectedView, perform: { value in
            // Log the selected view
            Analytics.logEvent("picker_value_changed", parameters: ["selectedView": "\(value)"])
        })
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
    @State private var searchText: String = ""
    @State private var isRequestSent: Bool = false
    @State private var currentUsername: String = Auth.auth().currentUser?.displayName ?? ""
    @State private var alertMessage: String?
    @State private var showAlert = false
    private let strokeWidth: CGFloat = 0.5

    
    var body: some View {
        VStack {
            HStack {
                TextField(NSLocalizedString("Enter your friend username", comment: ""), text: $searchText)
                    .padding(10)
                    .padding(.horizontal, 25)
                    .background(Color(.systemGray6))
                    .foregroundColor(.black)
                    .cornerRadius(10)
                    .overlay(
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.gray)
                                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                                .padding(.leading, 8)
                            
                            Button(action: {
                                sendFriendRequest(username: searchText)
                            }) {
                                Image(systemName: "paperplane.circle.fill")
                                    .resizable()
                                    .frame(width: 28, height: 28)
                                    .foregroundColor(searchText.count > 2 ? .purple : .gray)
                                    .padding(.trailing, 8)
                            }
                        }
                    )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.gray, lineWidth: strokeWidth)
                            )
            }
            .padding(.horizontal, 10)
            .colorScheme(.light)
            
            if isRequestSent {
                Text("Friend request sent to \(searchText)")
                    .foregroundColor(.green)
                    .padding()
            }
        }
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("Friend Request"),
                message: Text(alertMessage ?? ""),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    private func sendFriendRequest(username: String) {
        guard let currentUserID = Auth.auth().currentUser?.uid else {
            print("Could not get current user ID")
            return
        }

        if let currentUsername = Auth.auth().currentUser?.displayName, currentUsername == username {
            print("Can't send a friend request to yourself")
            alertMessage = NSLocalizedString("You cannot send a friend request to yourself.", comment: "")
            showAlert = true
            return
        }

        let friendRequestRef = Firestore.firestore().collection("users")
            .whereField("username", isEqualTo: username)
            .limit(to: 1)

        friendRequestRef.getDocuments { (querySnapshot, error) in
            if let error = error {
                print("Error fetching user document: \(error.localizedDescription)")
                return
            }

            guard let userDocument = querySnapshot?.documents.first else {
                print("User with username '\(username)' not found")
                alertMessage = NSLocalizedString("User with username '\(username)' not found.", comment: "")
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
            friendRequestRef.setData(["fromUserId": currentUserID, "fromUsername": currentUsername], merge: true) { error in
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
                    isRequestSent = true
                    alertMessage = NSLocalizedString("Friend request sent successfully to user: \(friendID)", comment: "")
                    showAlert = true
                }
            }
        }
    }
}




struct AddFriendView: View {
    @State private var users = [User]()
    @State private var selectedUsers = Set<String>()
    @State private var friendRequests = [User]()
    @State private var friends = [User]()
    @State private var contacts: [String: [Contact]] = [:]
    @State private var selectedView: SelectedView = .suggestions
    @State private var isEditing = false
    @Environment(\.presentationMode) var presentationMode
    @State private var showPreviousView = false
    @Environment(\.dismiss) var dismiss
    @State public var hasNewFriendRequests: Bool = false  //
    

    @State private var isShowingQRCodeView = false
    @State private var isShowingQRScanner = false
    @State private var friendRequestSearchText = ""
    @State private var isRequestSent = false
    @State private var currentUsername = ""
    @EnvironmentObject var friendsData: FriendsData




    
    
    var navigationBarTitle: String {
        switch selectedView {
        case .suggestions, .addFriend:
            return NSLocalizedString("Amis", comment: "Friends title")
        case .distributionCircles:
            return NSLocalizedString("Modifier vos listes", comment: "Modify your circles title")
        }
    }
    
    var codeScannerView = CodeScannerView(
        codeTypes: [AVMetadataObject.ObjectType.qr],
        completion: { result in
            // Handle the result
        }
    )
    
    
    
    var body: some View {
        GeometryReader { geometry in
        ZStack {
            Color(red: 0.94, green: 0.93, blue: 0.91).opacity(0.98)
             .ignoresSafeArea()
            
            VStack(spacing: 0) {
                
                            
                switch selectedView {
                case .suggestions:
                    SearchBar()
                        .padding(.top)

                    
                     
                    VStack {
                        Spacer().frame(height: 50) // Pushes the elements below it down by 50 units
                        
                        HStack {
                            // Left-hand side VStack for "Inviter des contacts"
                            Button(action: {
                                // Log event for camera button
                                Analytics.logEvent("clicked_open_camera", parameters: nil)
                                
                                self.isShowingQRScanner = true
                            }) {
                                Image(systemName: "barcode.viewfinder")
                                    .resizable()
                                    .frame(width: 60, height: 60)
                                    .foregroundColor(.white)
                                    .padding()
                                    .background(Color(red: 0.07, green: 0.04, blue: 1))
                                    .cornerRadius(30)
                            }
                            .padding(.all, 16)
                            .sheet(isPresented: $isShowingQRScanner) {
                                self.codeScannerView
                            }
                            
                            Spacer().frame(minWidth: 20)  // Takes up a minimum space of 20 units, pushing adjacent items closer
                            
                            // Right-hand side VStack for QR code
                            Button(action: {
                                self.isShowingQRCodeView = true
                            }) {
                                Image(systemName: "qrcode")
                                    .resizable()
                                    .frame(width: 60, height: 60)
                                    .foregroundColor(.white)
                                    .padding()
                                    .background(Color.black)
                                    .cornerRadius(30)
                            }
                            .sheet(isPresented: $isShowingQRCodeView) {
                                QRCodeView(isShowingQRScanner: $isShowingQRScanner, userID: "")
                            }
                        }
                        .padding(.horizontal, 30) // Adds horizontal padding on both sides of the HStack
                        .padding(.bottom, 30) // Adds padding at the bottom of the HStack
                    }
                    
                    
                    // Friend Recommendations List
                        FriendRecommendationList()
                            .padding(.horizontal, 16)
                            .background(.ultraThinMaterial)
                            .cornerRadius(6)
                            .padding(.vertical, 4)
                            .frame(maxWidth: .infinity)
            

                    // Contacts list
                        ScrollView {
                            LazyVStack {
                                ForEach(contacts.keys.sorted(by: { (a, b) -> Bool in
                                    if a == "#" { return false }
                                    if b == "#" { return true }
                                    return a < b
                                }), id: \.self) { key in
                                    Section(header: Text(key)) {
                                        ForEach(contacts[key]!) { contact in
                                            ContactRow(contact: contact)
                                        }
                                    }
                                }
                            }
                        
                        .padding(.horizontal, 16)
                        .background(Color(red: 0.94, green: 0.93, blue: 0.91).opacity(0.98))
                        .cornerRadius(6)
                        .padding(.vertical, 4)
                        .frame(maxWidth: .infinity)
                    }
                                               



                    
                case .addFriend:

                    
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
                                                FriendsListCard(user: friend)
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
                                
                            }
                        }
                    
                    
                case .distributionCircles:
                    DistributionCirclesView()
                }
                                    
                                    // Floating Picker at the bottom
                                    Spacer(minLength: 0)  // This will push the Picker down
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .zIndex(0)  // Lower zIndex

                                VStack {
                                    Spacer()  // This will push the Picker down
                                    MyPicker(selectedView: $selectedView)
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                                .zIndex(1)  // Higher zIndex to ensure it appears on top
        
               
                
                
            }
        .navigationBarTitleDisplayMode(.inline) // Display title inline
                    .transition(.moveAndFade) // Apply the custom transition here
                    .toolbar {
                        ToolbarItem(placement: .principal) {
                            Text(navigationBarTitle)
                                .font(.custom("Avenir Next", size: 20))
                                .bold()
                        .foregroundColor(.black)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        withAnimation {
                            dismiss()
                        }
                    }) {
                        Image(systemName: "arrow.right") 
                            .foregroundColor(.black)
                    }
                }
            }
            .navigationBarHidden(false)
            .navigationBarBackButtonHidden(true)
            .foregroundColor(.white)
            .onAppear {
                fetchFriendRequests()
                fetchFriends()
                fetchContacts()
            }
        }
    }
    
    
    
    // Connect to Firestore
    let db = Firestore.firestore()
    
    
    func fetchFriends() {
        guard let currentUserID = Auth.auth().currentUser?.uid else {
            print("Current user ID not found")
            return
        }

        let db = Firestore.firestore()
        let friendsRef = db.collection("Friends").document(currentUserID)

        friendsRef.getDocument { documentSnapshot, error in
            guard let snapshot = documentSnapshot, error == nil else {
                print("Error fetching friends: \(error?.localizedDescription ?? "")")
                return
            }

            if let friendsList = snapshot.data()?["friendsList"] as? [String] {
                fetchFriendDetails(friendIDs: friendsList, db: db)
            }
        }
    }
    
    private func fetchFriendDetails(friendIDs: [String], db: Firestore) {
        var friendsArray: [User] = []
        let group = DispatchGroup()

        for id in friendIDs {
            group.enter()
            db.collection("users").document(id).getDocument { (document, error) in
                if let document = document, document.exists, let user = try? document.data(as: User.self) {
                    friendsArray.append(user)
                } else {
                    print("Error fetching user details: \(error?.localizedDescription ?? "")")
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            self.friends = friendsArray
            print("Fetched friends: \(friendsArray)") // Debug print
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
            self.selectedUsers.remove(user.id)  // Update the selectedUsers set after canceling the request

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
                    Text("Accepter")
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
        @State private var showingDeleteAlert = false
        @StateObject var profileViewModel: ProfileViewModel
        

        init(user: User) {
            self.user = user
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
                        title: Text("Supprimer un ami"),
                        message: Text("Êtes-vous sûr de vouloir supprimer cet ami ?"),
                        primaryButton: .destructive(Text("Supprimer")) {
                            // Call the delete friend method from FriendsData
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


    
    struct ContactRow: View {
        var contact: Contact
        @State private var isShowingMessageComposer = false // Add this state property to control the message composer view
        var body: some View {
            HStack {
                if let image = contact.image {
                    Image(uiImage: image)
                        .resizable()
                        .frame(width: 50, height: 50)
                        .clipShape(Circle())
                } else {
                    Text(String(contact.name.prefix(1)).uppercased())
                        .font(.system(size: 25, weight: .bold))
                        .frame(width: 50, height: 50)
                    
                        .background(Color.gray.opacity(0.3))
                        .foregroundColor(.black)

                        .clipShape(Circle())
                }
                Text(contact.name) // Display the contact's name
                    .foregroundColor(.black)
                
                Spacer()
                
                Button(NSLocalizedString("Inviter", comment: "Invite")) {
                            isShowingMessageComposer = true // Set this to true when the button is tapped
                                
                                // Log the event for clicking the "Inviter" button
                                Analytics.logEvent("clicked_invite_button", parameters: [
                                    "contact_name": contact.name
                                ])
                            }
                            .buttonStyle(DefaultButtonStyle())
                            .foregroundColor(.black)
                            .sheet(isPresented: $isShowingMessageComposer) {
                                MessageComposerView(contact: contact) // Show the message composer view as a sheet
                            }
                        }
                    }
                }
    
    struct MessageComposerView: UIViewControllerRepresentable {
        var contact: Contact

        func makeUIViewController(context: Context) -> MFMessageComposeViewController {
            let messageComposeVC = MFMessageComposeViewController()
            
            // Log the event when the message composer is shown
            Analytics.logEvent("message_composer_shown", parameters: [
                "contact_name": contact.name,
                "contact_number": contact.number
            ])
            
            // Include the link to your website in the message body
                    let websiteURL = "https://brief-social.com" // Replace with the actual URL
                    let messageBody = String(format: NSLocalizedString("Salut %@, Utilisons Brief pour se tenir informer de notre quotidien de manière plus privée ! Télécharge l'application : %@", comment: "Invite message"), contact.name, websiteURL)
                    
                    messageComposeVC.recipients = [contact.number] // Set the recipient's phone number
                    messageComposeVC.body = messageBody
                    messageComposeVC.messageComposeDelegate = context.coordinator // Set the delegate
                    return messageComposeVC
                }

        func updateUIViewController(_ uiViewController: MFMessageComposeViewController, context: Context) {
            // No need to update anything here
        }

        func makeCoordinator() -> Coordinator {
            Coordinator(self)
        }

        class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
            var parent: MessageComposerView

            init(_ parent: MessageComposerView) {
                self.parent = parent
            }

            func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
                // Handle the result of the message sending here if needed
                controller.dismiss(animated: true, completion: nil)
            }
        }
    }
    
    
    struct FriendRecommendationList: View {
        @State private var recommendations: [FriendRecommendation] = []
        @State private var page: Int = 0
        
        var body: some View {
            VStack(spacing: 10) {
                Text(NSLocalizedString("Friend Recommendations", comment: "Header for friend recommendations section"))
                    .font(.headline)
                    .foregroundColor(.black)
                    .padding(.leading, 16)
                    .padding(.trailing, 16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(recommendations) { recommendation in
                            RecommendationCard(recommendation: recommendation)
                                .padding(.horizontal, 16)
                        }

                    }
                    .padding(.vertical, 8)
                }
                .frame(width: 351)
                .background(Color(red: 0.94, green: 0.93, blue: 0.91).opacity(1.98))
                .cornerRadius(6)
            }
            .onAppear {
                fetchRecommendations()
            }
        }
        
        private func fetchRecommendations() {
            // Attempt to load cached data
            if let cachedData = try? Data(contentsOf: cacheFileURL()),
               let cachedRecommendations = try? JSONDecoder().decode([FriendRecommendation].self, from: cachedData) {
                self.recommendations = cachedRecommendations
            }
            
            if let currentUserID = Auth.auth().currentUser?.uid {
                let url = URL(string: "https://us-central1-brief-fe340.cloudfunctions.net/suggestCommonFriends?userId=\(currentUserID)&page=\(page)")!
                URLSession.shared.dataTask(with: url) { data, response, error in
                    guard let data = data else {
                        print("Data fetching failed: \(error?.localizedDescription ?? "Unknown error")")
                        return
                    }
                    
                    do {
                        let commonFriends = try JSONDecoder().decode([FriendRecommendation].self, from: data)
                        DispatchQueue.main.async {
                            self.recommendations = commonFriends
                            // Cache the new data
                            try? data.write(to: cacheFileURL())
                        }
                    } catch {
                        print("Decoding failed with error: \(error)")
                    }

                }.resume()
            }
        }
        
        private func cacheFileURL() -> URL {
            let cacheDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            return cacheDirectory.appendingPathComponent("FriendRecommendations.json")
        }
    }
    
    
    struct RecommendationCard: View {
            var recommendation: FriendRecommendation
            @State private var isLinkActive = false
            @StateObject var profileViewModel: ProfileViewModel
            @State private var isRequestSent = false
            @State private var showAlert = false
            @State private var alertMessage = ""

        
        init(recommendation: FriendRecommendation) {
                self.recommendation = recommendation
                _profileViewModel = StateObject(wrappedValue: ProfileViewModel(userID: recommendation.id))  // Adjust the initialization if needed
            }
        
        
        var body: some View {
            HStack {
                NavigationLink(destination: ProfileView(userID: recommendation.id, viewModel: profileViewModel), isActive: $isLinkActive) {
                                EmptyView()  // This is hidden and won't be displayed, but the link will still work
                            }
                            .hidden()
                
                Button(action: {
                    isLinkActive = true  // Activate the link when the button is pressed
                }) {
                    if let imageUrl = URL(string: recommendation.profileImageUrl ?? "") {
                        WebImage(url: imageUrl)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 50, height: 50)
                            .clipShape(Circle())
                    } else {
                        Text(String(recommendation.username.prefix(1)))
                            .font(.system(size: 25, weight: .bold))
                            .frame(width: 50, height: 50)
                            .background(Color.gray.opacity(0.3))
                            .clipShape(Circle())
                    }
                }
                
                VStack(alignment: .leading) {
                    Button(action: {
                        isLinkActive = true
                    }) {
                        Text(recommendation.username)
                            .font(.headline)
                            .foregroundColor(.black)
                            .lineLimit(1)
                    }
                    
                    Text("\(recommendation.mutualCount) " + NSLocalizedString("mutual friends", comment: "Label for mutual friends count"))
                        .foregroundColor(.gray)
                        .font(.subheadline)
                }
                
                Spacer()
                
                Button(action: {
                    if isRequestSent {
                        cancelFriendRequest()  // Call cancelFriendRequest if a request has been sent
                    } else {
                        sendFriendRequest()  // Call sendFriendRequest if no request has been sent
                    }
                }) {
                    Text(isRequestSent ? NSLocalizedString("Demande Envoyée", comment: "Label for request sent button") :
                            NSLocalizedString("Ajouter", comment: "Label for add friend button"))
                        .padding()
                        .foregroundColor(.white)
                        .background(Color(red: 0.07, green: 0.04, blue: 1))
                        .cornerRadius(10)
                }
                .alert(isPresented: $showAlert) {
                    Alert(title: Text("Friend Request Status"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
                }
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
    

    
    struct FriendRecommendation: Identifiable, Decodable {
        let id: String
        let mutualCount: Int
        let username: String
        let profileImageUrl: String?
    }
    
    

    func fetchContacts() {
        DispatchQueue.global(qos: .userInitiated).async {
            let store = CNContactStore()
            store.requestAccess(for: .contacts) { granted, error in
                if granted {
                    let keys = [CNContactGivenNameKey, CNContactFamilyNameKey, CNContactPhoneNumbersKey, CNContactImageDataKey]
                    let request = CNContactFetchRequest(keysToFetch: keys as [CNKeyDescriptor])
                    var fetchedContacts: [String: [Contact]] = [:]
                    var nonAlphabeticalContacts: [Contact] = []
                    var totalContacts = 0  // Variable to hold the total number of contacts
                    
                    do {
                        try store.enumerateContacts(with: request) { (contact, stop) in
                            let name = "\(contact.givenName) \(contact.familyName)"
                            let number = contact.phoneNumbers.first?.value.stringValue ?? ""
                            let image = contact.imageData != nil ? UIImage(data: contact.imageData!) : nil
                            let contactItem = Contact(id: UUID(), name: name, number: number, image: image)
                            let firstLetter = String(name.prefix(1)).uppercased()

                            if firstLetter == "A" {
                                fetchedContacts[firstLetter, default: []].append(contactItem)
                            } else if firstLetter.range(of: "[A-Za-z]", options: .regularExpression) != nil {
                                fetchedContacts[firstLetter, default: []].append(contactItem)
                            } else {
                                nonAlphabeticalContacts.append(contactItem)
                            }
                            
                            totalContacts += 1  // Increment the total number of contacts
                        }
                    } catch {
                        print("Failed to fetch contacts:", error)
                    }
                    
                    // Log the total number of contacts
                    Analytics.logEvent("total_contacts_fetched", parameters: [
                        "total_count": totalContacts
                    ])

                    // Sort the contacts within each group
                    for (key, value) in fetchedContacts {
                        fetchedContacts[key] = value.sorted(by: { $0.name < $1.name })
                    }

                    // Add non-alphabetical contacts at the end
                    fetchedContacts["#"] = nonAlphabeticalContacts.sorted(by: { $0.name < $1.name })

                    DispatchQueue.main.async {
                        self.contacts = fetchedContacts
                    }
                }
            }
        }
    }
}
