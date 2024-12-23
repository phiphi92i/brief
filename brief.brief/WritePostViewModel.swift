//
//  WritePostViewModel.swift
//  brief.brief
//
//  Created by Philippe Tchinda on 28/11/2023.
//

import Combine
import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseStorage
import Foundation
import CoreLocation


class WritePostViewModel: ObservableObject {
    @Published var postContent = ""
    @Published var profileImageUrl = ""
    @Published var username = ""
    // Directly set to "All My Friends" without using NSLocalizedString
    @Published var selectedCircle = "All My Friends"
    // Initialize with English values directly
    @Published var distributionCircles: [String] = ["All My Friends"]
    @Published var isButtonClicked = false
    @Published var newPostPublisher = PassthroughSubject<UserPost, Never>()
    @Published var audioURL: URL?
    @Published var isLocationEnabled = false
    @Published var locationString = ""
    @Published var locationData: (latitude: Double, longitude: Double)? = nil
    @Published var newPost = PassthroughSubject<UserPost, Never>() // Used to publish new posts
    @Published var isGlobal: Bool = false
    @Published var hasSecondaryImage: Bool = false
    
    
    init() {
        fetchProfileImageAndUsername()
        fetchDistributionCircles()
    }
    
    func fetchProfileImageAndUsername() {
        guard let userID = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        
        db.collection("users").document(userID).getDocument { [weak self] (document, error) in
            if let error = error {
                print("Error getting document: \(error)")
            } else {
                self?.profileImageUrl = document?.data()?["profileImageUrl"] as? String ?? ""
                self?.username = document?.data()?["username"] as? String ?? ""
            }
        }
    }
    
    func fetchDistributionCircles() {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }
        
        Firestore.firestore().collection("distributionCircles")
            .whereField("creator_id", isEqualTo: currentUserID)
            .getDocuments { [weak self] (querySnapshot, error) in
                if let error = error {
                    print("Error fetching distribution circles: \(error.localizedDescription)")
                } else {
                    let circleNames = querySnapshot?.documents.compactMap { document -> String? in
                        (try? document.data(as: DistributionCircle.self))?.name
                    }
                    let newCircles = ["All My Friends"] + (circleNames ?? [])
                    if newCircles != self?.distributionCircles {
                        self?.distributionCircles = newCircles
                    }
                }
            }
    }
    
    func toggleLocationEnabled() {
        isLocationEnabled.toggle()
        if isLocationEnabled {
        } else {
            locationString = ""
        }
    }
    
    // Add this to use the locationString from LocationManager
    var currentLocationString: String {
        locationString
    }
    
    func setLocation(latitude: Double, longitude: Double) {
        self.locationData = (latitude, longitude)
        let location = CLLocation(latitude: latitude, longitude: longitude)
        // Start reverse geocoding immediately
        LocationManager.shared.reverseGeocodeLocation(location) { [weak self] address in
            DispatchQueue.main.async {
                self?.locationString = address
            }
        }
    }
    
    
    func sendPost(selectedCircle: String, username: String, profileImageUrl: String, postContent: String, audioRecordingURL: URL?) -> AnyPublisher<Void, Error> {
        guard let userID = Auth.auth().currentUser?.uid else {
            return Fail(error: NSError(domain: "User not logged in", code: 0, userInfo: nil))
                .eraseToAnyPublisher()
        }
        
        let db = Firestore.firestore()
        let storageRef = Storage.storage().reference()
        let expiresAt = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        
        let isAllFriends = selectedCircle == "All My Friends"
        let backendDistribution: [String] = isAllFriends ? ["all_friends"] : [selectedCircle]
        let visibility = isAllFriends ? [userID] : [] 
        
        var data: [String: Any] = [
            "userID": userID,
            "username": username,
            "profileImageUrl": profileImageUrl,
            "content": postContent,
            "timestamp": Timestamp(date: Date()),
            "expiresAt": Timestamp(date: expiresAt),
            "distributionCircles": backendDistribution,
            "visibleTo": visibility.isEmpty ? backendDistribution : visibility + backendDistribution
            // Initially, don't include audio URL
        ]
        
        if isLocationEnabled, let locationData = self.locationData {
            data["location"] = [
                "latitude": locationData.latitude,
                "longitude": locationData.longitude,
                "address": locationString // Include the reverse geocoded address
            ]
        }
        
        return Future<Void, Error> { promise in
            // Check if there's an audio recording to upload
            if let audioURL = audioRecordingURL {
                // Define the path in Firebase Storage
                let audioPath = "audioPosts/\(UUID().uuidString).m4a"
                let audioRef = storageRef.child(audioPath)
                
                // Upload audio file to Firebase Storage
                audioRef.putFile(from: audioURL, metadata: nil) { metadata, error in
                    if let error = error {
                        promise(.failure(error))
                        return
                    }
                    
                    
                    
                    // Retrieve the download URL
                    audioRef.downloadURL { url, error in
                        guard let downloadURL = url else {
                            promise(.failure(error ?? NSError(domain: "Download URL not found", code: 0, userInfo: nil)))
                            return
                        }
                        
                        // Add audio URL to post data
                        data["audioURL"] = downloadURL.absoluteString
                        
                        // Proceed to submit post with audio URL
                        self.submitPostWithData(data: data, promise: promise)
                    }
                }
            } else {
                // Submit post without audio
                self.submitPostWithData(data: data, promise: promise)
            }
            
            
        }
        .eraseToAnyPublisher()
        // Increment the post count
    }
    
    
    private func submitPostWithData(data: [String: Any], promise: @escaping (Result<Void, Error>) -> Void) {
        let db = Firestore.firestore()
        db.collection("posts").addDocument(data: data) { [weak self] error in
            if let error = error {
                print("Error posting: \(error.localizedDescription)")
                promise(.failure(error))
            } else {
                // Extract the document ID from Firestore response
                let documentID = db.collection("posts").document().documentID
                
                // Convert any URLs from String to URL
                var audioURL: URL? = nil
                if let audioURLString = data["audioURL"] as? String {
                    audioURL = URL(string: audioURLString)
                }
                
                // Create the UserPost instance
                let userPost = UserPost(
                    id: documentID, // Firestore generated document ID
                    content: data["content"] as? String ?? "",
                    timestamp: (data["timestamp"] as? Timestamp)?.dateValue() ?? Date(),
                    expiresAt: (data["expiresAt"] as? Timestamp)?.dateValue() ?? Date(),
                    userID: data["userID"] as? String ?? "",
                    username: data["username"] as? String ?? "",
                    profileImageUrl: data["profileImageUrl"] as? String ?? "",
                    distributionCircles: data["distributionCircles"] as? [String] ?? [],
                    images: data["images"] as? [String] ?? [],
                    likes: data["likes"] as? [String] ?? [],
                    audioURL: audioURL,
                    location: data["location"] != nil ? UserPost.UserLocation(
                        latitude: (data["location"] as? [String: Any])?["latitude"] as? Double ?? 0,
                        longitude: (data["location"] as? [String: Any])?["longitude"] as? Double ?? 0,
                        address: (data["location"] as? [String: Any])?["address"] as? String ?? ""
                    ) : nil, isGlobalPost: self?.isGlobal ?? false, hasSecondaryImage: self?.hasSecondaryImage ?? false)
                
                // Use the main thread to update the UI and publish the new post
                DispatchQueue.main.async {
                    self?.newPostPublisher.send(userPost)
                    print("Post added successfully")
                }
                promise(.success(()))
            }
        }
    }

}
    

    




extension AudioPlayer {
    func startPlayback(fromURL url: URL) {
        // Attempt to load data from the URL
        do {
            let data = try Data(contentsOf: url)
            // Create a Recording object with the fetched data
            let recording = Recording()
            // Start playback using the existing method
            startPlayback(recording: recording)
        } catch {
            print("Could not load audio data from URL: \(error)")
        }
    }
}





class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = LocationManager()
    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()
    
    var onLocationFetch: ((CLLocation) -> Void)?
    var onAuthorizationChange: ((Bool) -> Void)?

    override init() {
        super.init()
        locationManager.delegate = self
    }

    func requestAuthorization() {
        locationManager.requestWhenInUseAuthorization()
        // As soon as the app is authorized, start fetching the location
        if CLLocationManager.authorizationStatus() == .authorizedWhenInUse ||
            CLLocationManager.authorizationStatus() == .authorizedAlways {
            startFetchingLocation()
        }
    }

    func requestLocation() {
           locationManager.requestWhenInUseAuthorization()
           locationManager.startUpdatingLocation()
       }
    
    
    func startFetchingLocation() {
        locationManager.startUpdatingLocation()
    }

    func reverseGeocodeLocation(_ location: CLLocation, completion: @escaping (String) -> Void) {
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            if let error = error {
                print("Reverse geocoding failed: \(error)")
                completion("Unknown")
            } else if let firstPlacemark = placemarks?.first {
                // Attempt to include subLocality in the address
                let subLocality = firstPlacemark.subLocality ?? ""
                let name = firstPlacemark.locality ?? firstPlacemark.administrativeArea ?? "Unknown"
                let country = firstPlacemark.country ?? ""
                let detailedLocation = subLocality.isEmpty ? "\(name)" : "\(name), \(subLocality)"
                completion(detailedLocation)
            }
        }                                                        /*\(country)*/
    }
    
//    , \(country)


    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .denied, .restricted, .notDetermined:
            onAuthorizationChange?(false)
        case .authorizedAlways, .authorizedWhenInUse:
            onAuthorizationChange?(true)
            startFetchingLocation()
        @unknown default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else { return }
        locationManager.stopUpdatingLocation()
        onLocationFetch?(location)
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Failed to get location: \(error)")
    }
}
