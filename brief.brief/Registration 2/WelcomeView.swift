//
//  PhoneNumberView.swift
//  brief.brief
//
//  Created by Philippe Tchinda on 31/05/2023.
//

import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        if appState.isUserAuthenticated == .undefined {
            Text("Loading...")
        } else if appState.isUserAuthenticated == .signedOut {
            NavigationView {
                VStack {
                    Spacer()
                    
                    Text("Brief")
                      .font(
                        Font.custom("Avenir Next", size: 64)
                          .weight(.bold)
                      )
                      .foregroundColor(.white)
                      .frame(maxWidth: .infinity)
                    
                    Spacer()

                    NavigationLink(destination: RegistrationView().environmentObject(appState)) {
                        Rectangle()
                          .foregroundColor(.clear)
                          .frame(width: 328, height: 58)
                          .background(Color(red: 0.22, green: 0.87, blue: 0.87))
                          .cornerRadius(50)
                          .overlay(
                            Text("Inscription")
                              .font(Font.custom("Avenir Next Medium", size: 20))
                              .foregroundColor(.white)
                          )
                    }
                    .padding(.bottom, 20)
                    
                    NavigationLink(destination: LoginView().environmentObject(appState)) {
                        Rectangle()
                          .foregroundColor(.clear)
                          .frame(width: 328, height: 58)
                          .background(.white)
                          .cornerRadius(50)
                          .overlay(
                            Text("Connexion")
                              .font(Font.custom("Avenir Next Medium", size: 20))
                              .foregroundColor(Color(red: 0.106, green: 0.063, blue: 0.227, opacity: 1.0))
                          )
                    }
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(red: 0.106, green: 0.063, blue: 0.227, opacity: 1.0))
                .edgesIgnoringSafeArea(.all)
            }
        } else {
            FeedView()
                .environmentObject(appState)
        }
    }
}
