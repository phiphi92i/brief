//
//  UserDetailsView.swift
//  brief.brief
//
//  Created by Philippe Tchinda on 31/05/2023.
//

import SwiftUI
import UIKit
import Firebase
import FirebaseAuth
import FirebaseFirestore
import FirebaseMessaging
import iPhoneNumberField
import FirebaseAnalytics
import libPhoneNumber
import PhoneNumberKit


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
    @State private var emailAvailable: Bool = true
    @State private var phoneNumber: String = ""
    @State private var keyboardHeight: CGFloat = 0
    @State private var isKeyboardHidden = true // Track whether the keyboard is hidden
    @State private var currentPage = 0
    @State private var keyboardOffset: CGFloat = 0 // State variable to adjust the view when the keyboard appears
    @State private var bottomPadding: CGFloat = 0

    
    
    let phoneNumberKit = PhoneNumberKit()

    
    var body: some View {
        
        
        
        
        ZStack {
            VStack {
                Spacer()
                
                Text("brief")
                    .font(
                        Font.custom("Nanum Pen", size: 64)
                            .weight(.bold)
                    )
                    .foregroundColor(.black)
                
                
                
                VStack {
                    // Fields
                    
                    
                    
                    
                    TextField(NSLocalizedString("Prénom", comment: ""), text: $firstName)
                        .padding(EdgeInsets(top: 10, leading: 15, bottom: 10, trailing: 15))
                        .background(Color.white)
                        .foregroundColor(Color.primary)
                        .cornerRadius(10)
                        .frame(height: 40)
                        .padding(.bottom, 5)
                    
                    // LastName Field
                    TextField(NSLocalizedString("Nom de famille", comment: ""), text: $lastName)
                        .padding(EdgeInsets(top: 10, leading: 15, bottom: 10, trailing: 15))
                        .background(Color.white)
                        .foregroundColor(Color.primary)
                        .cornerRadius(10)
                        .frame(height: 40)
                        .padding(.bottom, 5)
                    
                    
                    // Email Field
                    TextField(NSLocalizedString("Email", comment: ""), text: $email)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress) // Enable email address suggestions
                        .autocapitalization(.words)
                        .padding(EdgeInsets(top: 10, leading: 15, bottom: 10, trailing: 15))
                        .background(Color.white)
                        .foregroundColor(Color.primary)
                        .cornerRadius(10)
                        .frame(height: 40)
                        .padding(.bottom, 5)
                    
                    // Password Field
                    SecureField(NSLocalizedString("Mot de passe", comment: ""), text: $password)
                        .padding(EdgeInsets(top: 10, leading: 15, bottom: 10, trailing: 15))
                        .background(Color.white)
                        .foregroundColor(Color.primary)
                        .cornerRadius(10)
                        .frame(height: 40)
                        .padding(.bottom, 5)
                    
                    
                    
                    // Username Field
                    TextField(NSLocalizedString("Nom d'utilisateur", comment: ""), text: $username)
                        .onChange(of: username) { newValue in
                            checkUsernameExists(username: newValue)
                        }
                        .padding(EdgeInsets(top: 10, leading: 15, bottom: 10, trailing: 15))
                        .background(Color.white)
                        .foregroundColor(Color.primary)
                        .cornerRadius(10)
                        .frame(height: 40)
                        .padding(.bottom, 5)
                    
                    if username.count >= 4 {
                        Text(usernameAvailable ? NSLocalizedString("Nom d'utilisateur disponible", comment: "") : NSLocalizedString("Nom d'utilisateur déjà pris", comment: ""))
                            .foregroundColor(usernameAvailable ? .green : .red)
                    }

                    // PhoneNumber Field
                    iPhoneNumberField(NSLocalizedString("Numéro de téléphone", comment: ""), text: $phoneNumber)
                        .flagHidden(false) // Show country flag
                        .prefixHidden(false) // Show country code prefix
                        .flagSelectable(true) // Allow users to select their country flag
                        .clearButtonMode(.whileEditing) // Show clear button while editing
                        .maximumDigits(15) // Set a maximum digit limit
                        .onEditingEnded { _ in // Include the closure argument
                            print("Editing ended")
                        }
                        .onClear { _ in // Closure with the argument
                            print("Field cleared")
                        }
                        .formatted(true)
                        .font(Font.custom("HelveticaNeue-Thin", size: 30)) // Custom font
                        .padding(EdgeInsets(top: 10, leading: 15, bottom: 10, trailing: 15))
                        . background(Color.white)
                        .foregroundColor(Color.primary)
                        .cornerRadius(10)
                        .frame(height: 40)
                        . padding(.bottom, 5)
                        .accentColor(Color.blue)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onTapGesture(count: 99) {
                               // Intentionally left empty to workaround iOS 17.1 DatePicker bug
                           }
                    
                    
                    
                    // DatePicker Field
                    DatePicker(NSLocalizedString("Date de naissance", comment: ""), selection: $birthDate, displayedComponents: .date)
                    //  .datePickerStyle(WheelDatePickerStyle())
                        .padding(EdgeInsets(top: 10, leading: 15, bottom: 10, trailing: 15))
                        .background(Color.white)
                        .foregroundColor(Color.primary)
                        .cornerRadius(10)
                        .frame(height: 40)
                        .padding(.bottom, 5)
                        .onTapGesture(count: 99) {
                               // Intentionally left empty to workaround iOS 17.1 DatePicker bug
                           }
                    
                    // Inscription Button
                    Button(action: {
                        Analytics.logEvent("user_registration", parameters: nil) // Logging
                        signUpUser()
                    }) {
                        Text(NSLocalizedString("Inscription", comment: ""))
                            .font(.headline)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .cornerRadius(10)
                            .foregroundColor(.white)
                            .padding(.top, 10)
                    }
                    .disabled(!usernameAvailable)
                    .padding(.bottom, 100)
                    
            // Terms and Services Section
                    HStack {
                        Text(NSLocalizedString("By signing up, you agree on", comment: ""))
                            .font(.system(size: 14))
                            .foregroundColor(.black)
                        
                        Link("terms and services", destination: URL(string: "https://wealthy-patient-6ce.notion.site/brief-terms-and-conditions-of-use-privacy-policy-5b1f23337ed84428aab71057e0996686?pvs=4")!)
                            .font(.system(size: 14))
                            .foregroundColor(.blue)
                    }
                    .padding(.bottom, 5)

                    

                    
                }
                .padding()
                .alert(isPresented: $showError) {
                    Alert(title: Text(NSLocalizedString("Error", comment: "")),
                          message: Text(NSLocalizedString(errorMessage, comment: "")),
                          dismissButton: .default(Text(NSLocalizedString("OK", comment: ""))))
                }
                
                Spacer()
            }
            .frame(maxWidth: .infinity)
            
            .background(Color(red: 0.94, green: 0.93, blue: 0.91).opacity(0.98))
            .edgesIgnoringSafeArea(.all)
            .preferredColorScheme(.light)
            .padding(.bottom, keyboardOffset)
            .animation(.easeOut(duration: 0.16), value: keyboardOffset)
            
            .onTapGesture {
                hideKeyboard()
            }
            .onAppear {
                NotificationCenter.default.addObserver(
                    forName: UIResponder.keyboardWillShowNotification,
                    object: nil, queue: .main) { notif in
                        if let value = notif.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                            let height = value.height
                            bottomPadding = height - (UIApplication.shared.windows.first?.safeAreaInsets.bottom ?? 0) + 20 // You can adjust this value
                        }
                }
                NotificationCenter.default.addObserver(
                    forName: UIResponder.keyboardWillHideNotification,
                    object: nil, queue: .main) { _ in
                        bottomPadding = 0
                }

                NotificationCenter.default.addObserver(
                    forName: UIResponder.keyboardWillHideNotification,
                    object: nil, queue: .main) { _ in
                        keyboardOffset = 20
                
            }

            }
        }
    }
    func hideKeyboard() {
        if !isKeyboardHidden {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }



        
        func signUpUser() {
            if email.isEmpty || password.isEmpty || firstName.isEmpty || lastName.isEmpty || username.isEmpty {
                errorMessage = "Remplissez tout les champs."
                showError = true
            } else if !isValidPhoneNumber(phoneNumber) {
                    errorMessage = "Numéro de téléphone invalide."
                    showError = true
            } else if password.count < 8 {
                errorMessage = "Le mot de passe doit avoir au moins 8 charactères"
                showError = true
            } else if username.count < 3 {
                errorMessage = "username must have 3 characters minimum"
                showError = true
            } else if username.range(of: "^[a-zA-Z0-9_]*$", options: .regularExpression) == nil {
                errorMessage = "username can only contains letters, numbers, or certains characters."
                showError = true
            } else {
                let thirteenYearsAgo = Calendar.current.date(byAdding: .year, value: -13, to: Date())
                if let birthDate = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month, .day], from: self.birthDate)),
                   let thirteenYearsAgo = thirteenYearsAgo,
                   birthDate > thirteenYearsAgo {
                    errorMessage = "You must be age of minimum 13 years old to register."
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
        }


    func isValidPhoneNumber(_ number: String) -> Bool {
        // Remove non-numeric characters from the phone number
        let digitsOnly = number.filter { "0"..."9" ~= $0 }
        
        // Check if the count of digits is at least 8
        return digitsOnly.count >= 8
    }


        func checkUsernameExists(username: String) {
            let sanitizedUsername = username.lowercased().replacingOccurrences(of: " ", with: "")
            let db = Firestore.firestore()
            let usersCollection = db.collection("users")
            
            usersCollection.whereField("sanitizedUsername", isEqualTo: sanitizedUsername).getDocuments { (querySnapshot, error) in
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
        let sanitizedUsername = username.lowercased().replacingOccurrences(of: " ", with: "")

        do {
            let phoneNumberObject = try phoneNumberKit.parse(phoneNumber)
            let formattedPhoneNumber = phoneNumberKit.format(phoneNumberObject, toType: .e164)

            let userData: [String: Any] = [
                "id": currentUser.uid,
                "firstName": firstName,
                "lastName": lastName,
                "username": username,
                "sanitizedUsername": sanitizedUsername,
                "phoneNumber": formattedPhoneNumber,
                "birthDate": Timestamp(date: birthDate),
                "fcmToken": ""
            ]

            usersCollection.document(currentUser.uid).setData(userData) { error in
                if let error = error {
                    self.errorMessage = error.localizedDescription
                    self.showError = true
                } else {
                    let phoneNumbersCollection = db.collection("phoneNumbers")
                    phoneNumbersCollection.document(formattedPhoneNumber).setData(["userId": currentUser.uid]) { error in
                        if let error = error {
                            self.errorMessage = error.localizedDescription
                            self.showError = true
                        } else {
                            self.updateFCMToken()
                            self.updateUserLocale()
                            
                            

                            // Present the OnboardingFlow view
                            let onboardingFlow = OnboardingFlow()
                            let hostingController = UIHostingController(rootView: onboardingFlow)
                            let navController = UINavigationController(rootViewController: hostingController)
                            navController.modalPresentationStyle = .fullScreen
                            UIApplication.shared.windows.first?.rootViewController?.present(navController, animated: true)
                        }
                    }
                }
            }
        } catch {
            self.errorMessage = "Failed to parse phone number"
            self.showError = true
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


struct RegistrationView_Previews: PreviewProvider {
    static var previews: some View {
        RegistrationView()
            .environmentObject(AppState())
    }
}
