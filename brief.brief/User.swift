//
//  User.swift
//  brief.brief
//
//  Created by Philippe Tchinda on 28/06/2023.
//

import SwiftUI
import FirebaseAuth
import Firebase
import FirebaseFirestore
import Foundation
import Firebase
import Contacts
import SDWebImageSwiftUI


extension Contact: Hashable {
    static func == (lhs: Contact, rhs: Contact) -> Bool {
        return lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct User: Identifiable, Codable {
    let id: String
    let username: String
    let firstName: String
    let lastName: String
    var isInvited: Bool? = false
    let name: String?
    let friends: [String]?
    var friendRequestsSent: [String]?
    var profileImageUrl: String?
    var fcmToken: String? // Add this field for storing FCM token
    
}


struct Contact: Identifiable {
    let id: UUID
    let name: String
    let number: String
    let image: UIImage?
    var userID: String?

}

