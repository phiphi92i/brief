//
//  PasswordResetView.swift
//  brief.brief
//
//  Created by Philippe Tchinda on 01/06/2023.
//

import SwiftUI
import FirebaseAuth
import FirebaseAnalytics

struct PasswordResetView: View {
    @State private var email = ""
    @State private var showingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color(red: 0.106, green: 0.063, blue: 0.227, opacity: 1.0)
                    .edgesIgnoringSafeArea(.all)

                VStack(spacing: 20) {
                    TextField(NSLocalizedString("Email", comment: ""), text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .padding()
                        .background(Color.white)
                        .foregroundColor(Color.primary) // Use primary color for text
                        .cornerRadius(10)

                    Button(action: resetPassword) {
                        Text(NSLocalizedString("Réinitialiser le mot de passe", comment: ""))
                            .font(Font.custom("Avenir Next Medium", size: 20))
                            .padding()
                            .background(Color(red: 0.22, green: 0.87, blue: 0.87))
                            .cornerRadius(10)
                            .foregroundColor(Color.white)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal)
            }
        }
        .preferredColorScheme(.light) // Set the preferred color scheme to light
        .alert(isPresented: $showingAlert) {
            Alert(title: Text(NSLocalizedString(alertTitle, comment: "")),
                  message: Text(NSLocalizedString(alertMessage, comment: "")),
                  dismissButton: .default(Text(NSLocalizedString("OK", comment: ""))))
        }
    }

    func resetPassword() {
        // Log the event before attempting to reset the password
                Analytics.logEvent("password_reset_attempt", parameters: [
                    "email": email as NSObject
                ])
        Auth.auth().sendPasswordReset(withEmail: self.email) { (error) in
            if let error = error {
                alertTitle = NSLocalizedString("Error", comment: "")
                alertMessage = NSLocalizedString("Échec de l'envoi du mot de passe de réinitialisation:", comment: "") + " \(error.localizedDescription)"
                showingAlert = true
            } else {
                alertTitle = NSLocalizedString("Success", comment: "")
                alertMessage = NSLocalizedString("Email de réinitialisation du mot de passe envoyé à", comment: "") + " \(email)."
                showingAlert = true
            }
        }
    }
}
