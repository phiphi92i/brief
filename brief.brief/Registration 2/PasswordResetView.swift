//
//  PasswordResetView.swift
//  brief.brief
//
//  Created by Philippe Tchinda on 01/06/2023.
//

import SwiftUI
import FirebaseAuth

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
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(10)
                    
                    Button(action: resetPassword) {
                        Text("Réinitialiser le mot de passe")
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
        .alert(isPresented: $showingAlert) {
            Alert(title: Text(alertTitle), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
    }

    func resetPassword() {
        Auth.auth().sendPasswordReset(withEmail: self.email) { (error) in
            if let error = error {
                alertTitle = "Error"
                alertMessage = "Échec de l'envoi du mot de passe de réinitialisation: \(error.localizedDescription)"
                showingAlert = true
            } else {
                alertTitle = "Success"
                alertMessage = "Email de réinitialisation du mot de passe envoyé à  \(email)."
                showingAlert = true
            }
        }
    }
}
