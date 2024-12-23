






import SwiftUI
import FirebaseAuth
import FirebaseMessaging
import FirebaseFirestore
import Firebase

struct LoginView: View {
    @EnvironmentObject var loginState: AppState
    
    @State private var email = ""
    @State private var password = ""
    @State private var showingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color(red: 0.94, green: 0.93, blue: 0.91).opacity(0.98)
                    .edgesIgnoringSafeArea(.all)
                
                

                VStack(spacing: 20) {
                    
                    Text("brief")
                      .font(
                        Font.custom("Nanum Pen", size: 75)
                          .weight(.bold)
                      )
                      .foregroundColor(.black)
                      .frame(maxWidth: .infinity)
                    
                    
                    TextField(NSLocalizedString("Email", comment: ""), text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .padding()
                        .background(Color.white)
                        .foregroundColor(Color.black) // Use primary color for text
                        .cornerRadius(10)

                    SecureField(NSLocalizedString("Mot de passe", comment: ""), text: $password)
                        .padding()
                        .background(Color.white)
                        .foregroundColor(Color.black) // Use primary color for text
                        .cornerRadius(10)

                    Button(action: loginUser) {
                        Text(NSLocalizedString("Connexion", comment: ""))
                            .font(Font.custom("Avenir Next Medium", size: 20))
                            .padding()
                            .background(Color(red: 0.07, green: 0.04, blue: 1))
                            .cornerRadius(10)
                            .foregroundColor(Color.white)
                        
                            
                    }

                    NavigationLink(destination: PasswordResetView()) {
                        Text(NSLocalizedString("Mot de passe oublié ?", comment: ""))
                            .foregroundColor(Color.black)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal)
            }
        }
        .preferredColorScheme(.light) // Set the preferred color scheme to light
        .alert(isPresented: $showingAlert) {
            Alert(
                title: Text(NSLocalizedString(alertTitle, comment: "")),
                message: Text(NSLocalizedString(alertMessage, comment: "")),
                dismissButton: .default(Text(NSLocalizedString("OK", comment: "")))
            )
        }
    }


    func loginUser() {
        print("Attempting to login...")  // Debug log
        Auth.auth().signIn(withEmail: email, password: password) { authResult, error in
            print("Inside login callback...")  // Debug log
            DispatchQueue.main.async {
                if let error = error as NSError? {
                    print("Login failed with error: \(error.localizedDescription)")  // Debug log
                    if let errorCode = AuthErrorCode.Code(rawValue: error.code) {
                        switch errorCode {
                        case .wrongPassword:
                            self.alertTitle = "Mot de passe incorrect"
                            self.alertMessage = "Le mot de passe que vous avez entré est incorrect."
                            self.showingAlert = true
                        case .tooManyRequests:
                            self.alertTitle = "Trop de tentatives"
                            self.alertMessage = "Vous avez réalisé trop de tentatives, réessayez plus tard."
                            self.showingAlert = true
                        default:
                            self.alertTitle = "Erreur"
                            self.alertMessage = error.localizedDescription
                            self.showingAlert = true
                        }
                    }
                } else if let user = authResult?.user {
                    print("Login successful for user: \(user.uid)")  // Debug log
                    
                    // Fetch FCM token
                    Messaging.messaging().token { token, error in
                        if let error = error {
                            print("Error fetching FCM token: \(error)")  // Debug log
                        } else if let token = token {
                            print("Successfully fetched FCM token: \(token)")  // Debug log
                            
                            // Update FCM token in Firestore if user has fcmToken field
                            let db = Firestore.firestore()
                            let userDoc = db.collection("users").document(user.uid)
                            
                            userDoc.getDocument { document, error in
                                if let error = error {
                                    print("Error fetching user document: \(error)")  // Debug log
                                } else if let document = document, document.exists {
                                    if document.data()?["fcmToken"] != nil {
                                        self.updateFCMToken(userID: user.uid, token: token)
                                    }
                                }
                            }
                        }
                    }
                    self.loginState.isUserAuthenticated = .signedIn
                    print("User is now authenticated.")  // Debug log
                    
                    
                    // Update the user's locale in Firestore
                    self.updateUserLocale()
                }
            }
        }
    }



    
    func updateUserLocale() {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }
        
        let currentLocale = Locale.current.identifier
        let userRef = Firestore.firestore().collection("users").document(currentUserID)
        
        userRef.updateData([
            "locale": currentLocale
        ]) { err in
            if let err = err {
                print("Error updating document: \(err)")
            } else {
                print("Document successfully updated")
            }
        }
    }

    // Function to update FCM token in Firestore
    func updateFCMToken(userID: String, token: String) {
        let db = Firestore.firestore()
        
        let tokenDocRef = db.collection("fcmToken").document(userID)
        tokenDocRef.updateData(["fcmToken": token])
    }
}



struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
            .environmentObject(AppState())
            .previewDevice("iPhone 12") // You can set different devices here
    }
}
