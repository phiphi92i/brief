//
//  InviteContactView.swift
//  brief.brief
//
//  Created by Philippe Tchinda on 10/02/2024.
//

import SwiftUI
import Contacts
import FirebaseAnalytics
import MessageUI
import FirebaseDynamicLinks
import Firebase
import FirebaseAuth
import SDWebImageSwiftUI


struct InviteContactView: View {
    @StateObject var viewModel: InviteContactViewModel
    @State private var isShowingMessageComposer = false
    @State private var selectedContact: Contact?
    @State private var generatedLink: String?
    @State private var isGeneratingLink: Bool?
    @State private var selectedUserId: String?
    @State private var isShowingProfileView = false
    @State public var isShowingQRScanner: Bool = false
    @State private var isShowingQRCodeView: Bool = false
    @State private var selectedUserData: UserData?

    
    var body: some View {
        
           VStack {
               HStack {
                   SearchBar()

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
                       .padding(.horizontal)
                   }
                   .buttonStyle(PlainButtonStyle())
                   .sheet(isPresented: $isShowingQRCodeView) {
                       QRCodeView(isShowingQRScanner: $isShowingQRScanner, userID: Auth.auth().currentUser?.uid ?? "")
                   }
               }

               List {
                   Section(header: Text(NSLocalizedString("Contacts sur l'app", comment: "Suggested for you"))) {
                       ForEach(viewModel.contactsOnApp, id: \.id) { userData in
                           NavigationLink(destination: ProfileView(userID: userData.id, viewModel: viewModel.getProfileViewModel(for: userData.id))) {
                               AppContactRow(userData: userData)
                           }
                       }
                   }


                   Section(header: Text(NSLocalizedString("Contacts", comment: "Suggested for you"))) {
                       ForEach(viewModel.contacts.keys.sorted(by: { (a, b) -> Bool in
                           if a == "#" { return false }
                           if b == "#" { return true }
                           return a < b
                       }), id: \.self) { key in
                           ForEach(viewModel.contacts[key]!, id: \.id) { contact in
                               ContactRow(contact: contact, viewModel: viewModel)
                           }
                       }
                   }
               }
               .listStyle(GroupedListStyle())
               .onAppear {
                   // Your existing onAppear code
               }
           }
       }
   }
    
    func generateDynamicInviteLink(forUserID userID: String, completion: @escaping (String) -> Void) {
        let linkParameter = URL(string: "https://brief-social.com/invite?inviterId=\(userID)")!
        let dynamicLinksDomain = "https://brief-social.com/invite" // Use the correct domain from Firebase configuration
        guard let linkBuilder = DynamicLinkComponents(link: linkParameter, domainURIPrefix: dynamicLinksDomain) else {
            completion("Error creating link")
            return
        }
        
        linkBuilder.iOSParameters = DynamicLinkIOSParameters(bundleID: "com.brief.brief")
        linkBuilder.iOSParameters?.appStoreID = "6466705982"
        
        linkBuilder.shorten { (shortURL, warnings, error) in
            if let error = error {
                print("Error generating dynamic link: \(error.localizedDescription)")
                completion("Error: \(error.localizedDescription)")
                return
            }
            
            guard let shortURL = shortURL else {
                completion("Error generating link")
                return
            }
            
            completion(shortURL.absoluteString)
        }
    }
    

struct AppContactRow: View {
    var userData: UserData
    @StateObject var profileViewModel: ProfileViewModel

    init(userData: UserData) {
        self.userData = userData
        _profileViewModel = StateObject(wrappedValue: ProfileViewModel(userID: userData.id))
    }

    var body: some View {
        HStack {
            if let imageUrl = userData.profileImageUrl, let url = URL(string: imageUrl) {
                WebImage(url: url)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 50, height: 50)
                    .overlay(Text(userData.username.prefix(1)).font(.system(size: 25, weight: .bold)))
            }

            VStack(alignment: .leading) {
                Text(userData.username)
                Text(userData.phoneNumber).font(.subheadline).foregroundColor(.gray)
            }
            
            Spacer()
            
            FriendButton(userID: userData.id, username: userData.username, userProfileImageUrl: userData.profileImageUrl ?? "", viewModel: profileViewModel)
                .buttonStyle(DefaultButtonStyle())
        }
    }
}


struct ContactRow: View {
    var contact: Contact
    @State private var isShowingMessageComposer = false
    var viewModel: InviteContactViewModel // Add this line

    
    var body: some View {
        HStack {
            if let image = contact.image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
                
            } else {
                
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 40, height: 40)
                    .overlay(Text(contact.name.prefix(1)).font(.system(size: 25, weight: .bold)))
                
            }
            
            Text(contact.name)
            
            Spacer()
            
            Button(NSLocalizedString("Inviter", comment: "Invite")) {
                isShowingMessageComposer = true
                
                // Log the event for clicking the "Inviter" button
                Analytics.logEvent("clicked_invite_button", parameters: [
                    "contact_name": contact.name
                ])
            }
            .buttonStyle(DefaultButtonStyle())
            .sheet(isPresented: $isShowingMessageComposer) {
                MessageComposerView(contact: contact, viewModel: viewModel) // Pass viewModel here
            }
        }
    }
}



struct MessageComposerView: UIViewControllerRepresentable {
    var contact: Contact
    @ObservedObject var viewModel: InviteContactViewModel

    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let messageComposeVC = MFMessageComposeViewController()
        viewModel.inviteContact(phoneNumber: contact.number)

        // Include the link to your website in the message body
        let websiteURL = "brief-fe340.web.app" // Replace with the actual URL
        let messageBody = String(format: NSLocalizedString("Salut %@, Utilisons Brief pour se tenir informer de notre quotidien de manière plus privée ! Télécharge l'application : %@", comment: "Invite message"), contact.name, websiteURL)
        
        // Set recipients and message body here
        messageComposeVC.recipients = [contact.number]
        messageComposeVC.body = messageBody // Assign the message body
        messageComposeVC.messageComposeDelegate = context.coordinator

        return messageComposeVC
    }

    func updateUIViewController(_ uiViewController: MFMessageComposeViewController, context: Context) {
        // No need to update anything for now
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
