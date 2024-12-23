//
//  VerificationView.swift
//  brief.brief
//
//  Created by Philippe Tchinda on 31/05/2023.
//

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
                Color(red: 0.106, green: 0.063, blue: 0.227, opacity: 1.0)
                    .edgesIgnoringSafeArea(.all)

                VStack(spacing: 20) {
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(10)
                    
                    SecureField("Mot de passe", text: $password)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(10)

                    Button(action: loginUser) {
                        Text("Connexion")
                            .font(Font.custom("Avenir Next Medium", size: 20))
                            .padding()
                            .background(Color(red: 0.22, green: 0.87, blue: 0.87))
                            .cornerRadius(10)
                            .foregroundColor(Color.white)
                    }

                    NavigationLink(destination: PasswordResetView()) {
                        Text("Mot de passe oublié ?")
                            .foregroundColor(Color.white)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal)
            }
        }
        .alert(isPresented: $showingAlert) {
            Alert(title: Text(alertTitle), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
    }

    func loginUser() {
        Auth.auth().signIn(withEmail: email, password: password) { authResult, error in
            if let error = error as NSError? {
                let errorCode = AuthErrorCode.Code(rawValue: error.code)
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
            } else if let user = authResult?.user {
                // Fetch FCM token
                Messaging.messaging().token { token, error in
                    if let error = error {
                        print("Error fetching FCM token: \(error)")
                    } else if let token = token {
                        // Update FCM token in Firestore if user has fcmToken field
                        let db = Firestore.firestore()
                        let userDoc = db.collection("users").document(user.uid)
                        
                        userDoc.getDocument { document, error in
                            if let error = error {
                                print("Error fetching user document: \(error)")
                            } else if let document = document, document.exists {
                                if document.data()?["fcmToken"] != nil {
                                    updateFCMToken(userID: user.uid, token: token)
                                }
                            }
                        }
                    }
                }
                self.loginState.isUserAuthenticated = .signedIn
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
