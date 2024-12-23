//
//  LoginState.swift
//  brief.brief
//
//  Created by Philippe Tchinda on 24/04/2023.
//

import Combine
import FirebaseAuth

class AppState: ObservableObject {
    @Published var isUserAuthenticated: UserAuthentication = .undefined
    @Published var verificationID: String? = nil
    @Published var phoneNumber: String = ""
    @Published var firstName: String = ""
    @Published var lastName: String = ""
    @Published var username: String = ""
    @Published var birthDate: Date = Date()

    enum UserAuthentication {
        case undefined, signedOut, signedIn
    }

    var handle: AuthStateDidChangeListenerHandle?

    init() {
        handle = Auth.auth().addStateDidChangeListener { (auth, user) in
            if let user = user {
                print("User is signed in: \(user)")
                self.isUserAuthenticated = .signedIn
            } else {
                print("User is signed out")
                self.isUserAuthenticated = .signedOut
            }
        }
        print("AppState initialized")
    }

    deinit {
        if let handle = handle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
        print("AppState deinitialized")
    }
}
