//
//  UserDetailsView.swift
//  brief.brief
//
//  Created by Philippe Tchinda on 31/05/2023.
//

    import SwiftUI
    import Firebase
    import FirebaseAuth
    import FirebaseFirestore
    import FirebaseMessaging

    struct RegistrationView: View {
        @EnvironmentObject var appState: AppState

        @State private var email: String = ""
        @State private var password: String = ""
        @State private var firstName: String = ""
        @State private var lastName: String = ""
        @State private var username: String = ""
        @State private var birthDate: Date = Date()
        @State private var errorMessage: String = ""
        @State private var showError: Bool = false
        @State private var usernameAvailable: Bool = true

        var body: some View {
            ScrollView {
                VStack {
                    Spacer().frame(height: 100) // Adjust this value as needed
                    VStack {
                        TextField("Email", text: $email)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(10)
                            .padding(.bottom)

                        SecureField("Mot de passe", text: $password)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(10)
                            .padding(.bottom)

                        TextField("Prénom", text: $firstName)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(10)
                            .padding(.bottom)

                        TextField("Nom de famille", text: $lastName)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(10)
                            .padding(.bottom)

                        TextField("Nom d'utilisateur", text: $username)
                            .onChange(of: username) { newValue in
                                checkUsernameExists(username: newValue)
                            }
                            .padding()
                            .background(Color.white)
                            .cornerRadius(10)
                            .padding(.bottom)
                        
                        Text(usernameAvailable ? "Nom d'utilisateur disponible" : "Nom d'utilisateur déja pris")
                            .foregroundColor(usernameAvailable ? .green : .red)
                        
                        DatePicker("Date de naissance", selection: $birthDate, displayedComponents: .date)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(10)
                            .padding(.bottom)

                        Button(action: {
                            signUpUser()
                        }) {
                            Text("Inscription")
                                .font(Font.custom("Avenir Next Medium", size: 20))
                                .padding()
                                .background(Color(red: 0.22, green: 0.87, blue: 0.87))
                                .cornerRadius(10)
                                .foregroundColor(Color.white)
                        }
                        .disabled(!usernameAvailable)
                    }
                    .padding()
                    .alert(isPresented: $showError) {
                        Alert(title: Text("Error"), message: Text(errorMessage), dismissButton: .default(Text("OK")))
                    }
                    Spacer()
                }
            }
            .background(Color(red: 0.106, green: 0.063, blue: 0.227, opacity: 1.0))
            .edgesIgnoringSafeArea(.all)
        }
        
        func signUpUser() {
            if email.isEmpty || password.isEmpty || firstName.isEmpty || lastName.isEmpty || username.isEmpty {
                errorMessage = "Remplissez tout les champs."
                showError = true
            } else if password.count < 6 {
                errorMessage = "Le mot de passe doit avoir au moins 6 charactères"
                showError = true
            } else {
                Auth.auth().createUser(withEmail: email, password: password) { authResult, error in
                    if let error = error {
                        errorMessage = error.localizedDescription
                        showError = true
                    } else {
                        saveUserData()
                    }
                }
            }
        }

        func checkUsernameExists(username: String) {
            let db = Firestore.firestore()
            let usersCollection = db.collection("users")
            usersCollection.whereField("username", isEqualTo: username).getDocuments { (querySnapshot, error) in
                if let error = error {
                    errorMessage = error.localizedDescription
                    showError = true
                } else if let documents = querySnapshot?.documents, !documents.isEmpty {
                    usernameAvailable = false
                } else {
                    usernameAvailable = true
                }
            }
        }
        
        func saveUserData() {
            guard let currentUser = Auth.auth().currentUser else { return }
            let db = Firestore.firestore()
            let usersCollection = db.collection("users")
            let userData: [String: Any] = [
                "id": currentUser.uid,
                "firstName": firstName,
                "lastName": lastName,
                "username": username,
                "birthDate": Timestamp(date: birthDate),
                "fcmToken": "", // Initialize with an empty string
            ]
            usersCollection.document(currentUser.uid).setData(userData) { error in
                if let error = error {
                    errorMessage = error.localizedDescription
                    showError = true
                } else {
                    updateFCMToken() // Call the function to update the FCM token
                }
            }
        }

        func updateFCMToken() {
            Messaging.messaging().token { token, error in
                if let error = error {
                    print("Error getting FCM token: \(error.localizedDescription)")
                } else if let token = token {
                    // Update the FCM token in Firestore
                    let db = Firestore.firestore()
                    let tokenDocRef = db.collection("fcmToken").document(Auth.auth().currentUser?.uid ?? "")
                    tokenDocRef.updateData(["fcmToken": token])
                }
            }
        }
    }
