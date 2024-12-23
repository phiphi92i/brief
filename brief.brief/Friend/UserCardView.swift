//
//  UserCardView.swift
//  brief.brief
//
//  Created by Philippe Tchinda on 27/06/2023.
//

import SwiftUI

struct UserCardView: View {
    let user: User
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            // Profile picture or first letter of name
            if let firstLetter = user.firstName.first {
                Text(String(firstLetter))
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
                    .background(Color.blue)
                    .clipShape(Circle())
            }

            Text("\(user.firstName) \(user.lastName)")
                .font(.headline)
                .foregroundColor(.white)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading) // Adjust alignment and width

            if isSelected {
                Button(action: action) {
                    Text("Delete")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.red)
                        .cornerRadius(8)
                }
            } else {
                if user.isInvited {
                    Text("Invitation Sent")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.gray)
                        .cornerRadius(8)
                } else {
                    Button(action: action) {
                        Text("Add")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue)
                            .cornerRadius(8)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10) // Adjust vertical padding
        .background(Color(red: 0.106, green: 0.063, blue: 0.227, opacity: 1.0))
        .cornerRadius(6)
        .padding(.vertical, 4) // Add vertical spacing between cards
        .frame(maxWidth: .infinity) // Set the width of the card to fill the list width
    }
}
