//
//  SettingsView.swift
//  brief.brief
//
//  Created by Philippe Tchinda on 20/02/2024.
//

import Foundation
import SwiftUI
import Firebase
import FirebaseAnalytics
import UIKit
import SDWebImageSwiftUI
import MessageUI
import FirebaseFirestore
import FirebaseStorage



struct SettingsView: View {
    @State private var showingAlert = false
    @Binding var isShowingQRScanner: Bool
    @State private var isShowingQRCodeView: Bool = false 
    @StateObject var inviteContactViewModel = InviteContactViewModel()
    @StateObject var viewModel: SettingsViewModel
    
    
    init(isShowingQRScanner: Binding<Bool>) {
        self._isShowingQRScanner = isShowingQRScanner
        let userID = Auth.auth().currentUser?.uid ?? ""
        self._viewModel = StateObject(wrappedValue: SettingsViewModel(userID: userID))
        
    }
    
    private let db = Firestore.firestore()
    
    
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.945, green: 0.945, blue: 0.961, opacity: 1)
                VStack {
                    List {
                        Section(header: Text(NSLocalizedString("Mon compte", comment: "My account")).foregroundColor(.black)) {
                            HStack {
                                // Existing profile image and username link
                                if let imageUrl = URL(string: viewModel.userProfileImageUrl ?? "") {
                                    WebImage(url: imageUrl)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 70, height: 70)
                                        .clipShape(Circle())
                                } else {
                                    Text(viewModel.userFirstNameInitial)
                                        .font(.largeTitle)
                                        .frame(width: 70, height: 70)
                                        .background(Color.gray)
                                        .clipShape(Circle())
                                        .foregroundColor(.black)
                                }
                                
                                NavigationLink(destination: EditProfileView(userID: Auth.auth().currentUser?.uid ?? "")) {
                                    Text(viewModel.username)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                }

                                .buttonStyle(PlainButtonStyle())
                                
                                Spacer()
                                
                                Button(action: {
                                    self.isShowingQRCodeView = true
                                }) {
                                    ZStack {
                                        Circle()
                                            .foregroundColor(Color(red: 0.9, green: 0.9, blue: 0.9))
                                            .frame(width: 44, height: 44)
                                        Image(systemName: "qrcode")
                                            .foregroundColor(.blue)
                                            .font(.title2)
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                                .sheet(isPresented: $isShowingQRCodeView) {
                                    QRCodeView(isShowingQRScanner: $isShowingQRScanner, userID: Auth.auth().currentUser?.uid ?? "")

                                }
                            }
                        }

                        
                        
                        Section(header: Text(NSLocalizedString("", comment: "About")).foregroundColor(.black)) {
                            
                            NavigationLink(destination: FriendsView()) {
                                Text(NSLocalizedString("👫 Mes amis", comment: "Guide"))
                            }
                            
                            NavigationLink(destination: DistributionCirclesView()) {
                                Text(NSLocalizedString("📣 Mes listes de diffusion", comment: "Guide"))
                            }
                            
                            NavigationLink(destination: InviteContactView(viewModel: inviteContactViewModel)) {
                                Text(NSLocalizedString("💌 Inviter des amis", comment: "Invite friends"))
                            }
                        }
                        
                        
                        Section(header: Text(NSLocalizedString("À propos", comment: "About")).foregroundColor(.black)) {
                            
                            NavigationLink(destination: WelcomeSheet()) {
                                Text(NSLocalizedString("📖 Guide", comment: "Guide"))
                            }
                            NavigationLink(destination: CGUView()) {
                                Text(NSLocalizedString("⚖️ CGU, confidentialité, mentions légales", comment: "Terms, privacy, legal notices"))
                            }
                            
                            NavigationLink(destination: ContactUsView()) {
                                Text(NSLocalizedString("📥 Nous contacter", comment: "Contact Us"))
                            }
                            
                            NavigationLink(destination: PlusView(viewModel: viewModel)) {
                                Text(NSLocalizedString("🛠 Plus", comment: "More"))
                            }
                        }
                        
                        
                        
                        
                        Section {
                            Button(action: {
                                do {
                                    try Auth.auth().signOut()
                                    Analytics.logEvent("user_signed_out", parameters: nil)  // Log sign out event
                                } catch {
                                    print("Failed to sign out")
                                    Analytics.logEvent("user_signout_failed", parameters: nil)  // Log sign out failure event
                                }
                            }) {
                                HStack {
                                    Spacer()
                                    Text(NSLocalizedString("Déconnexion", comment: "Log out"))
                                        .foregroundColor(.red)
                                    Spacer()
                                }
                            }
                        }
                    }
                    // Memento Mori section
                    HStack {
                        Spacer()
                        Text("Memento mori ☠️")
                            .foregroundColor(.gray)
                            .font(.caption) // Smaller font
                        Spacer()
                    }.padding()
                }
            }
            .preferredColorScheme(.light)
            .navigationTitle(NSLocalizedString("Réglages", comment: "Settings"))
//            .navigationBarTitleColor(.black) // Use the custom modifier here
//            .toolbarColorScheme(.dark)
            .foregroundColor(.black)
            .navigationBarTitleDisplayMode(.inline)
        }
          .onAppear {
//         viewModel.fetchUserProfileImage()
//         viewModel.fetchUserFirstName()
//              viewModel.fetchUserInfo()
//         viewModel.fetchBannerImageUrl()        }
         }
         
        
    }
}
    
    

    






struct MailView: UIViewControllerRepresentable {
    @Binding var isShowing: Bool
    var email: String

    func makeUIViewController(context: UIViewControllerRepresentableContext<MailView>) -> MFMailComposeViewController {
        let viewController = MFMailComposeViewController()
        viewController.setToRecipients([email])
        viewController.mailComposeDelegate = context.coordinator
        return viewController
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: UIViewControllerRepresentableContext<MailView>) {

    }

    func makeCoordinator() -> Coordinator {
        return Coordinator(isShowing: $isShowing)
    }

    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        @Binding var isShowing: Bool

        init(isShowing: Binding<Bool>) {
            _isShowing = isShowing
        }

        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            isShowing = false
        }
    }
}





struct GuideView: View {
    let websiteURL = "https://wealthy-patient-6ce.notion.site/brief-usage-guide-49cefedc5a9e4dfd8e33b764f35e2273?pvs=4"

    var body: some View {
        NavigationView {
            VStack {
                // Your content here

                Button(action: {
                    if let url = URL(string: websiteURL) {
                        UIApplication.shared.open(url)
                    }
                }) {
                    Text(NSLocalizedString("📖 Guide", comment: "Guide"))
                        .padding(.horizontal, 16) // Horizontal padding
                        .padding(.vertical, 8) // Vertical padding
                }
                .foregroundColor(.blue) // Text color
                .background(Color.gray)
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(Color.blue, lineWidth: 1)
                )
            }
        }
    }
}




struct CGUView: View {
    let websiteURL = "https://wealthy-patient-6ce.notion.site/brief-terms-and-conditions-of-use-5b1f23337ed84428aab71057e0996686"

    var body: some View {
        NavigationView {
            VStack {
                // Your content here

                Button(action: {
                    if let url = URL(string: websiteURL) {
                        UIApplication.shared.open(url)
                    }
                }) {
                    Text(NSLocalizedString("⚖️ CGU, confidentialité, mentions légales", comment: "Terms, privacy, legal notices"))
                        .padding(.horizontal, 16) // Horizontal padding
                        .padding(.vertical, 8) // Vertical padding
                }
                .foregroundColor(.blue) // Text color
                .background(Color.gray)
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(Color.blue, lineWidth: 1)
                )
            }
        }
    }
}





struct ContactUsView: View {
    let websiteURL = "https://www.instagram.com/brief_app"

    var body: some View {
        NavigationView {
            VStack {
                // Your content here

                Button(action: {
                    if let url = URL(string: websiteURL) {
                        UIApplication.shared.open(url)
                    }
                }) {
                    Text(NSLocalizedString("Contatct", comment: "Terms, privacy, legal notices"))
                        .padding(.horizontal, 16) // Horizontal padding
                        .padding(.vertical, 8) // Vertical padding
                }
                .foregroundColor(.blue) // Text color
                .background(Color.gray)
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(Color.blue, lineWidth: 1)
                )
            }
        }
    }
}




//struct ContactUsView: View {
//    @State private var isMailViewShowing: Bool = false
//    
//    var body: some View {
//        VStack {
//            Button(action: {
//                self.isMailViewShowing.toggle()
//                Analytics.logEvent("contact_us_email_button_clicked", parameters: nil)  // Log event
//            }) {
//                Text(NSLocalizedString("Envoyer nous un mail", comment: ""))
//                    .padding(.horizontal, 16) // Horizontal padding
//                    .padding(.vertical, 8)   // Vertical padding
//            }
//            .foregroundColor(.blue) // Text color
//            .overlay(
//                RoundedRectangle(cornerRadius: 5)
//                    .stroke(Color.blue, lineWidth: 1)
//            )
//            .sheet(isPresented: $isMailViewShowing) {
//                MailView(isShowing: self.$isMailViewShowing, email: "Briefapp2023@gmail.com")
//            }
//        }
//        .onAppear {
//            Analytics.logEvent("contact_us_view_appeared", parameters: nil)  // Log when the contact us view appears
//        }
//    }
//}


struct PlusView: View {
    @ObservedObject var viewModel = SettingsViewModel(userID: "")
    @State private var showingAlert = false // To show an alert before deleting an account
    
    var body: some View {
        VStack {
            Button(action: {
                // Show alert to confirm deletion
                self.showingAlert = true
                Analytics.logEvent("delete_account_alert_shown", parameters: nil)  // Log event
            }) {
                HStack {
                    Spacer()
                    Text(NSLocalizedString("Supprimer mon compte", comment: "Delete my account"))
                        .foregroundColor(.red)
                    Spacer()
                }
            }
            .alert(isPresented: $showingAlert) {
                Alert(title: Text(NSLocalizedString("Supprimer le compte", comment: "Delete account")),
                    message: Text(NSLocalizedString("Êtes-vous sûr de vouloir supprimer votre compte? Cette action est irréversible.", comment: "Are you sure you want to delete your account? This action is irreversible.")),
                primaryButton: .destructive(Text(NSLocalizedString("Supprimer", comment: "Delete"))) {
                    Analytics.logEvent("account_deleted", parameters: nil)  // Log event
                        viewModel.deleteUserAccount { success, error in
                            if success {
                                print("Successfully deleted user account.")
                                // TODO: Navigate the user to login/welcome page
                            } else {
                                print("Failed to delete user account: \(error?.localizedDescription ?? "Unknown error")")
                            }
                        }
                      },
                      secondaryButton: .cancel())
            }
        }
        .navigationBarTitle(NSLocalizedString("Plus", comment: "More"), displayMode: .inline)
    }
}





struct EditProfileView: View {
    @StateObject var viewModel: SettingsViewModel
    @State private var selectedImage: UIImage = UIImage()
    @State private var showingImagePicker = false
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    let userID: String

    init(userID: String) {
        self._viewModel = StateObject(wrappedValue: SettingsViewModel(userID: userID))
        self.userID = userID
    }
    

    var body: some View {
        VStack {
            // toolbar
            VStack {
                Divider()
            }

            // edit profile pic
            VStack {
                Button(action: { self.showingImagePicker = true
                }) {
                    if let imageUrl = viewModel.userProfileImageUrl {
                        WebImage(url: URL(string: imageUrl))
                            .resizable()
                            .scaledToFill()
                            .frame(width: 120, height: 120)
                            .clipShape(Circle())
                    } else {
                        Text(viewModel.userFirstNameInitial)
                            .font(.largeTitle)
                            .frame(width: 120, height: 120)
                            .background(Color.gray)
                            .clipShape(Circle())
                            .foregroundColor(.white)
                    }
                }
                .sheet(isPresented: $showingImagePicker) {
                    ImagePicker(selectedImage: self.$selectedImage)
                }
                Text(NSLocalizedString("Modifier la photo de profil", comment: "Edit profile picture"))
                    .font(.footnote)
                    .fontWeight(.semibold)
            }
            .padding(.vertical, 8)
            .padding(.bottom, 4) // Reduced bottom padding
            Divider()

            // edit profile info
            VStack {
                EditProfileRowView(title: NSLocalizedString("Bio", comment: "Bio"), placeholder: NSLocalizedString("Modifier votre bio", comment: "Edit your bio"), text: $viewModel.bio)
                Divider().padding(.top, 4) //
                
            }
            Spacer()
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(NSLocalizedString("Modifier mon profil", comment: "Edit my profile"))
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    if selectedImage != UIImage(), let imageData = selectedImage.jpegData(compressionQuality: 0.5) {
                        viewModel.uploadProfilePicture(imageData: imageData) { url in
                            guard let url = url else { return }
                            viewModel.userProfileImageUrl = url
                            viewModel.updateProfileImageUrlInFirestore(url: url)
                        }
                        Analytics.logEvent("editProfile_newImage_uploaded", parameters: nil)  // Log event
                    }
                    viewModel.updateBio(newBio: viewModel.bio)
                    Analytics.logEvent("editProfile_changes_saved", parameters: nil)  // Log event
                    self.presentationMode.wrappedValue.dismiss()
                }) {
                    Text(NSLocalizedString("Enregistrer", comment: "Save"))
                        .font(.subheadline)
//                        .fontWeight(.bold)
                        .foregroundColor(.black)
                }
            }
        }
        .onAppear {
                   Analytics.logEvent("editProfile_view_appeared", parameters: nil)  // Log when the Edit Profile view appears
               }
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct EditProfileRowView: View {
    let title: String
    let placeholder: String

    @Binding var text: String

    var body: some View {
        HStack {
            Text(title)
                .padding(.leading, 8)
                .frame(width: 100, alignment: .leading)
            TextField(placeholder, text: $text)
        }
        .font(.subheadline)
        .frame(height: 36)
    }
}

