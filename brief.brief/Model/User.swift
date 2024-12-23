//
//  User.swift
//  brief.brief
//
//  Created by Philippe Tchinda on 27/06/2023.
//

import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore

struct User: Identifiable {
    let email: String
    let birthDate: String
    let id: String
    let username: String
    let firstName: String
    let lastName: String
    let profileImageUrl: String? // Add this property
    var isInvited: Bool = false
}
