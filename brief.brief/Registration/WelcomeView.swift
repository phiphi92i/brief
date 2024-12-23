//
//  PhoneNumberView.swift
//  brief.brief
//
//  Created by Philippe Tchinda on 31/05/2023.
//

import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject var appState: AppState
    @State private var shouldNavigateToComments: Bool = false
    @State private var selectedPostId: String? = nil
    
    var body: some View {
        if appState.isUserAuthenticated == .undefined {
            Text(NSLocalizedString("loading", comment: ""))
        } else if appState.isUserAuthenticated == .signedOut {
            NavigationView {
                VStack {
                    Spacer()
                    
                    Text("brief")
                      .font(
                        Font.custom("Nanum Pen", size: 75)
                          .weight(.bold)
                      )
                      .foregroundColor(.black)
                      .frame(maxWidth: .infinity)
                    
                    //Spacer()

                    Text(NSLocalizedString("Partager des statuts de 24h avec vos amis", comment: ""))
                        .foregroundColor(.gray)
                        .font(Font.custom("Nanum Pen", size: 28))

                      //  .font(.headline)

                    Spacer()

                    NavigationLink(destination: RegistrationView().environmentObject(appState)) {
                        Rectangle()
                          .foregroundColor(.clear)
                          .frame(width: 328, height: 58)
                          .background(Color(red: 0.07, green: 0.04, blue: 1))
                          .cornerRadius(50)
                          .overlay(
                            Text(NSLocalizedString("inscription", comment: ""))
                              .font(Font.custom("Avenir Next Medium", size: 20))
                              .foregroundColor(.white)
                          )
                    }
                    .padding(.bottom, 20)
                    
                    NavigationLink(destination: LoginView().environmentObject(appState)) {
                        Rectangle()
                          .foregroundColor(.clear)
                          .frame(width: 328, height: 58)
                          .background(.black)
                          .cornerRadius(50)
                          .overlay(
                            Text(NSLocalizedString("connexion", comment: ""))
                              .font(Font.custom("Avenir Next Medium", size: 20))
                              .foregroundColor(.white)
                          )
                    }
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(red: 0.94, green: 0.93, blue: 0.91).opacity(0.98))
                .edgesIgnoringSafeArea(.all)
            }
        } else {
            FeedView(/*shouldNavigateToComments: $shouldNavigateToComments, selectedPostId: $selectedPostId*/)
                .environmentObject(appState)
        }
    }
}

struct WelcomeView_Previews: PreviewProvider {
    static var previews: some View {
        WelcomeView()
            .environmentObject(AppState())
            .previewDevice("iPhone 12") // You can set different devices here
    }
}
