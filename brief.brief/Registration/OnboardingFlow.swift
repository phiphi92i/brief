//
//  OnboardingFlow.swift
//  brief.brief
//
//  Created by Philippe Tchinda on 29/04/2024.
//

import SwiftUI


struct OnboardingFlow: View {
    @State private var currentStep: Int = 0
    
    var body: some View {
        NavigationView {
            switch currentStep {
            case 0:
                InviteContactView(viewModel: InviteContactViewModel())
                    .navigationBarItems(trailing: Button(action: {
                        currentStep += 1
                    }) {
                        Text(NSLocalizedString("Next", comment: ""))
                    })
            case 1:
                WelcomeSheet()
                    .navigationBarItems(trailing: Button(action: {
                        currentStep += 1
                    }) {
                        Text(NSLocalizedString("Next", comment: ""))
                    })
            case 2:
                FeedView()
            default:
                EmptyView()
            }
        }
    }
}
