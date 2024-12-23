//
//  SettingsViewModel.swift
//  brief.brief
//
//  Created by Philippe Tchinda on 23/12/2024.
//

import Foundation
import SwiftUI
import Firebase
import FirebaseAnalytics
import UIKit
import SDWebImageSwiftUI
import MessageUI
import FirebaseFirestore
import FirebaseStorage




class SettingsViewModel: ObservableObject {
    @Published var userProfileImageUrl: String?
    @Published var userFirstNameInitial: String = ""
    @Published var firstName: String = ""
    @Published var lastName: String = ""

    @Published var bio: String = ""
    @Published var username: String = ""
    
    private let storage = Storage.storage()
    private let userID: String
    private let db = Firestore.firestore()

    init(userID: String) {
        self.userID = userID
//        self.isShowingQRScanner = false
        fetchUserProfileImage()
        fetchUserInfo()
        
        
    }
    
    func fetchUserInfo() {
        let db = Firestore.firestore()
        db.collection("users").document(self.userID).getDocument { [weak self] document, error in
            guard let self = self else { return }
            if let document = document, document.exists {
                if let data = document.data() {
                    self.username = data["username"] as? String ?? ""
                    self.bio = data["bio"] as? String ?? ""
                    self.firstName = data["firstName"] as? String ?? ""
                    self.lastName = data["lastName"] as? String ?? ""


                }
            }
        }
    }
    

  
    
    func fetchUserProfileImage() {
        let storageRef = storage.reference().child("profileImages/\(self.userID).jpg")
        storageRef.downloadURL { url, error in
            if let error = error {
                print("Error fetching profile image URL: \(error)")
            } else {
                self.userProfileImageUrl = url?.absoluteString
            }
        }
    }
    

    
    func updateBio(newBio: String) {
        guard let currentUser = Auth.auth().currentUser else {
            return
        }
        
        let db = Firestore.firestore()
        db.collection("users").document(currentUser.uid).updateData([
            "bio": newBio
        ]) { error in
            if let error = error {
                print("Error updating bio: \(error)")
            } else {
                self.bio = newBio
                print("Bio successfully updated")
            }
        }
    }
    
    func uploadProfilePicture(imageData: Data, completion: @escaping (String?) -> Void) {
        guard let currentUser = Auth.auth().currentUser else {
            completion(nil)
            return
        }
        
        let storageRef = storage.reference().child("profileImages/\(currentUser.uid).jpg")
        
        storageRef.putData(imageData, metadata: nil) { _, error in
            if let error = error {
                print("Error uploading image: \(error)")
                completion(nil)
            } else {
                storageRef.downloadURL { url, error in
                    if let error = error {
                        print("Error fetching download URL: \(error)")
                        completion(nil)
                    } else {
                        completion(url?.absoluteString)
                    }
                }
            }
        }
    }
    
    
    func updateProfileImageUrlInFirestore(url: String) {
        guard let currentUser = Auth.auth().currentUser else {
            return
        }
        
        let db = Firestore.firestore()
        db.collection("users").document(currentUser.uid).updateData([
            "profileImageUrl": url
        ]) { error in
            if let error = error {
                print("Error updating profile image URL: \(error)")
            } else {
                print("Profile image URL successfully updated")
            }
        }
    }
    
    private func deleteUserFromFirestore(completion: @escaping (Bool, Error?) -> Void) {
        guard let userID = Auth.auth().currentUser?.uid else {
            completion(false, nil)
            return
        }
        
        // Remove user data from Firestore
        db.collection("users").document(userID).delete { (error) in
            if let error = error {
                completion(false, error)
            } else {
                completion(true, nil)
            }
        }
    }
    
    func deleteUserAccount(completion: @escaping (Bool, Error?) -> Void) {
        guard let user = Auth.auth().currentUser else {
            completion(false, nil)
            return
        }
        
        // Delete user-related data from Firestore first
        deleteUserFromFirestore { (success, error) in
            if success {
                // Then proceed to delete the user account
                user.delete { error in
                    if let error = error {
                        completion(false, error)
                    } else {
                        completion(true, nil)
                    }
                }
            } else {
                if let error = error {
                    completion(false, error)
                } else {
                    completion(false, nil)
                }
            }
        }
    }
}

    
