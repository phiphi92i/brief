//
//  Post.swift
//  brief.brief
//
//  Created by Philippe Tchinda on 05/06/2023.
//

import Firebase
import FirebaseFirestoreSwift
import Foundation
import FirebaseStorage

struct UserPost: Identifiable, Codable {
    @DocumentID var id: String?
    var content: String
    var timestamp: Date
    var expiresAt: Date
    var userID: String
    var username: String
    var profileImageUrl: String
    var distributionCircles: [String]
    var images: [String]
    var likes: [String] // Likes property
    var reaction: String? // Reaction property
    var audioURL: URL?
    var location: UserLocation? // Added to store location data
    var isGlobalPost: Bool // Added to differentiate between global and friend-specific posts
    var hasSecondaryImage: Bool // Add this line
//    var secondImageUrl: String?

    

    enum CodingKeys: String, CodingKey {
        case id
        case content
        case timestamp
        case expiresAt
        case userID
        case username
        case profileImageUrl
        case distributionCircles
        case images
        case likes
        case reaction
        case audioURL
        case location
        case isGlobalPost
        case hasSecondaryImage
//        case secondImageUrl
    }
    
    struct UserLocation: Codable {
        var latitude: Double
        var longitude: Double
        var address: String
    }

    // Convert the struct to a dictionary including the new location field
    var asDictionary: [String: Any] {
        do {
            let data = try JSONEncoder().encode(self)
            let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
            if let json = jsonObject as? [String: Any] {
                return json
            }
        } catch {
            print("Error converting UserPost to dictionary: \(error)")
        }
        return [:]
    }
}

extension UserPost {
    func dictionary() throws -> [String: Any] {
        let data = try JSONEncoder().encode(self)
        let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
        guard let json = jsonObject as? [String: Any] else {
            throw NSError()
        }
        return json
    }
}
