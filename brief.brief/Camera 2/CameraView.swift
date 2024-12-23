//
//  AddPhotoView.swift
//  brief.brief
//
//  Created by Philippe Tchinda on 04/06/2023.
// CameraView.swift

import SwiftUI
import UIKit
import Firebase
import SDWebImageSwiftUI
import FirebaseFirestore
import FirebaseStorage

struct CameraView: View {
    @ObservedObject var viewModel: CameraViewModel
    @State private var showSendButton = false
    @State private var profileImageUrl = ""
    @State private var username = ""
    @State private var selectedCircle = "Tout mes amis"
    @State private var distributionCircles: [String] = ["Tout mes amis"]
    @State private var zoomScale: CGFloat = 1.0
    @Binding var isShown: Bool
    @Environment(\.presentationMode) var presentationMode
    @State private var overlayText: String = ""
    @State private var showTextField = false
    @FocusState private var isTextFieldFocused: Bool



    
    
    // Fetching the profile image and username
      func fetchProfileImageAndUsername() {
          guard let userID = Auth.auth().currentUser?.uid else { return }
          let db = Firestore.firestore()

          db.collection("users").document(userID).getDocument { (document, error) in
              if let error = error {
                  print("Error getting document: \(error)")
              } else {
                  self.profileImageUrl = document?.data()?["profileImageUrl"] as? String ?? ""
                  self.username = document?.data()?["username"] as? String ?? ""
              }
          }
      }

      // Fetching the distribution circles
      func fetchDistributionCircles() {
          guard let currentUserID = Auth.auth().currentUser?.uid else { return }
          
          Firestore.firestore().collection("distributionCircles")
              .whereField("creator_id", isEqualTo: currentUserID)
              .getDocuments { (querySnapshot, error) in
                  if let error = error {
                      print("Error fetching distribution circles: \(error.localizedDescription)")
                  } else {
                      let circleNames = querySnapshot?.documents.compactMap { document -> String? in
                          (try? document.data(as: DistributionCircle.self))?.name
                      }
                      self.distributionCircles = ["Tout mes amis"] + (circleNames ?? [])
                  }
              }
      }

      // Sending the post
    func sendPost (imageURL: String) {
        guard let userID = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        let expiresAt = Calendar.current.date(byAdding: .day, value: 1, to: Date())!

        var distribution: [String] = []
        if selectedCircle == "Tout mes amis" {
            distribution = ["all_friends"]
        } else {
            distribution = [selectedCircle]
        }

        let data: [String: Any] = [
            "userID": userID,
            "username": username,
            "profileImageUrl": profileImageUrl,
            "content": "",
            "timestamp": Timestamp(date: Date()),
            "expiresAt": Timestamp(date: expiresAt),
            "images": [imageURL],  // Use the URL string here
            "likes": [],
            "distributionCircles": distribution
        ]

        db.collection("posts").addDocument(data: data) { error in
            if let error = error {
                print("Error adding document: \(error)")
            } else {
                self.presentationMode.wrappedValue.dismiss()
            }
        }
    }



    var body: some View {
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)

                VStack {
                    Spacer(minLength: 20)

                    HStack {
                        Button(action: {
                            if showSendButton {
                                viewModel.resetCameraToLiveFeed()
                                showSendButton = false
                            } else {
                                self.isShown = false
                            }
                        }) {
                            Image(systemName: "arrow.left")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 30, height: 30)
                                .foregroundColor(.white)
                                .padding(20)
                        }
                        .padding(.top, 20)

                        Spacer()
                    }

                    Spacer(minLength: 20)

                    Rectangle()
                        .foregroundColor(.clear)
                        .frame(width: 375, height: 706 - 100)
                        .background(
                            ZStack {
                                if let frame = viewModel.frame {
                                    Image(uiImage: UIImage(cgImage: frame))
                                        .resizable()
                                        .scaledToFill()
                                        .edgesIgnoringSafeArea(.all)
                                } else {
                                    Color.black
                                }
                            }
                            .cornerRadius(15.33333)
                            .clipped()
                        )
                        .cornerRadius(15.33333)
                        .clipped()
                        .onTapGesture(count: 2) {
                            let generator = UIImpactFeedbackGenerator(style: .medium)
                            generator.impactOccurred()
                            if !showSendButton && !isTextFieldFocused { // Add check for isTextFieldFocused
                                viewModel.toggleCamera()
                            }
                        }


                    ZStack {
                        if !showSendButton {
                            Button(action: {
                                viewModel.takePic()
                                showSendButton = true
                            }) {
                                Image(systemName: "camera.circle.fill")
                                    .resizable()
                                    .frame(width: 70, height: 70)
                                    .padding()
                            }
                            .padding()
                            .offset(y: -15)

                            HStack {
                                Spacer()

                                Button(action: {
                                    let generator = UIImpactFeedbackGenerator(style: .medium)
                                    generator.impactOccurred()
                                    viewModel.toggleCamera()
                                }) {
                                    Image(systemName: "arrow.triangle.2.circlepath.camera")
                                        .resizable()
                                        .frame(width: 50, height: 40)
                                        .padding()
                                }
                                .padding(.trailing, 20)
                                .offset(y: -15)
                            }
                        }

                        if showSendButton {
                            HStack {
                                Picker(selection: $selectedCircle, label: Text("Circle")) {
                                    ForEach(distributionCircles, id: \.self) { circle in
                                        Text(circle).tag(circle)
                                    }
                                }
                                .pickerStyle(MenuPickerStyle())
                                .foregroundColor(.white)
                                .padding(.leading)
                                .offset(y: -20)

                                Spacer()

                                Button(action: {
                                    if let image = viewModel.takenImage, let imageData = image.jpegData(compressionQuality: 0.6) {
                                        let storageRef = Storage.storage().reference().child("photos/\(UUID().uuidString).jpg")
                                        storageRef.putData(imageData, metadata: nil) { (metadata, error) in
                                            if error != nil {
                                                print(error!.localizedDescription)
                                                return
                                            }
                                            storageRef.downloadURL { (url, error) in
                                                if let downloadURL = url {
                                                    sendPost(imageURL: downloadURL.absoluteString)
                                                    viewModel.resetTakenImage()
                                                    showSendButton = false
                                                }
                                            }
                                        }
                                    }
                                }) {
                                    Image(systemName: "arrow.right.circle.fill")
                                        .resizable()
                                        .frame(width: 60, height: 60)
                                        .padding()
                                }
                                .padding(.trailing, 20)
                                .offset(y: -20)
                            }
                        }
                    }
                    .frame(height: 100)
                }
                .onAppear {
                    viewModel.configureCamera()
                    fetchProfileImageAndUsername()
                    fetchDistributionCircles()
                }
                .navigationBarBackButtonHidden(true)
                .gesture(
                    DragGesture(minimumDistance: 50, coordinateSpace: .local)
                        .onEnded { value in
                            if value.translation.width > 0 && !showSendButton {
                                self.isShown = false
                            }
                        }
                )

                
                
                // Add Text button
                if showSendButton {
                    Button(action: {
                        self.showTextField.toggle()
                    }) {
                        Text("A")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 50, height: 50)
                            .background(Color.black.opacity(0.7))
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: 2)
                            )
                            .shadow(radius: 3)
                    }
                    .padding([.top, .trailing], 20)
                    .position(x: UIScreen.main.bounds.width - 50, y: 50)
                }

                // Text Overlay
                if showTextField {
                    TextField("Enter text", text: $overlayText)
                        .focused($isTextFieldFocused) // Use the @FocusState property
                        .padding()
                        .background(Color.gray.opacity(0.5))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .frame(width: 300) // Adjust the width to your preference
                        .position(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height / 2)
                }

                        }
                    }
    }
