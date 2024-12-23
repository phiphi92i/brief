
//
//  CommentCameraView.swift
//  brief.brief
//
//  Created by Philippe Tchinda on 25/01/2024.
//

import SwiftUI
import UIKit
import Firebase
import SDWebImageSwiftUI
import FirebaseFirestore
import FirebaseStorage
import Combine
import FirebaseAnalytics




struct CommentCameraView: View {
    @StateObject var viewModel: CommentCameraViewModel // Use @StateObject for lifecycle management
    @State private var showSendButton = false
    
    @State private var zoomScale: CGFloat = 1.0
    @Binding var isShown: Bool
    @Environment(\.presentationMode) var presentationMode
    @State private var showTextField = false
    @FocusState private var isTextFieldFocused: Bool
    @State private var isFlashOn: Bool = false
    @State private var shouldUseFlash = false
    @State private var isButtonClicked: Bool = false // New state variable
    @State private var showDeleteButton: Bool = false
    @State private var postCaption: String = ""
    @State private var isCaptionFieldActive: Bool = false
    @State private var cancellables = Set<AnyCancellable>()
    @ObservedObject var cameraService: CommentCameraService
    @State private var capturedPhoto: UIImage? = nil  // <-- New state variable
    @State private var keyboardHeight: CGFloat = 0 // Add this line
    private var keyboardHeightPublisher: AnyPublisher<CGFloat, Never> {
        Publishers.Merge(
            NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
                .compactMap { ($0.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect)?.height },
            NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
                .map { _ in CGFloat(0) }
        )
        .eraseToAnyPublisher()
    }
    @State private var dynamicHeight: CGFloat = 0
    
    let width = UIScreen.main.bounds.width
    let height = UIScreen.main.bounds.height
    
//    @StateObject var snapModel = SnapViewModel()  // SnapViewModel for managing text overlay
    @State private var isTextEditingMode: Bool = false  // State to toggle text editing mode
    @State private var showTextEditor: Bool = false  // State to toggle text editing mode
    
    
    
    // Your CommentCameraView init should match the ViewModel's expected parameters:
    init(isShown: Binding<Bool>, commentCameraService: CommentCameraService, post: UserPost, currentUsername: String) {
        _isShown = isShown
        self.cameraService = commentCameraService
        _viewModel = StateObject(wrappedValue: CommentCameraViewModel(commentCameraService: commentCameraService, currentUsername: currentUsername, post: post))
        // Now, the viewModel fetches the username only once due to its lifecycle being tied to the view's lifecycle
    }
    
    
    private func observeKeyboardHeight() {
        keyboardHeightPublisher
            .sink { height in
                self.keyboardHeight = height
            }
            .store(in: &cancellables)
    }
    
    
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            VStack {
                
                ZStack {
                    
                    RoundedRectangle(cornerRadius: UIScreen.main.bounds.width * 0.04)
                        .fill(Color.black)
                        .frame(width: UIScreen.main.bounds.width * 1, height: UIScreen.main.bounds.height * 0.84)
                    ZStack {
                        if let capturedImage = self.viewModel.capturedPhoto {
                            Image(uiImage: capturedImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: UIScreen.main.bounds.width * 1, height: UIScreen.main.bounds.height * 0.84)
                                .clipped()
                        } else if !isCaptionFieldActive {
                            CommentCameraPreview(session: cameraService.session)
                        } else {
                            Color.black.edgesIgnoringSafeArea(.all)
                        }
                    }
                    
                    .cornerRadius(15.33333)
                    .clipped()
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                if !isCaptionFieldActive && !showSendButton {
                                    viewModel.updateZoomLevel(to: value)
                                    
                                    // Log event for zoom level change
                                    Analytics.logEvent("zoom_level_changed", parameters: [
                                        "zoom_level": value
                                    ])
                                }
                            }
                    )
                    
                    .overlay(
                        Group {
                            Button(action: {
                                // Log event for arrow left button
                                Analytics.logEvent("clicked_arrow_left", parameters: nil)
                                if showSendButton {
                                    viewModel.resetCamera() // Clear the photo and reset the camera
                                    showSendButton = false
                                } else {
                                    self.isShown = false // Use false to dismiss the view correctly
                                }
                            }) {
                                Image(systemName: "xmark")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: UIScreen.main.bounds.width * 0.05, height: UIScreen.main.bounds.width * 0.05)
                                    .foregroundColor(.white)
                                    .padding(20)
                            }
                            .alignmentGuide(.bottom) { $0[.bottom] }
                            .alignmentGuide(.trailing) { $0[.trailing] }
                        },
                        alignment: .topLeading
                    )

                    
                    // Text Editing Icon
                    /*.overlay(
                        // Text Editing Icon in the top right corner of the rectangle
                        Button(action: {
                            showTextEditor.toggle()
                        }) {
                            Image(systemName: "character.cursor.ibeam")
                                .font(.subheadline)
                                .padding()
                                .background(Circle().fill(Color.black.opacity(0.7)))
                                .foregroundColor(.white)
                        },
                        alignment: .topTrailing
                    )*/
                    
                    .overlay(
                        Group {
                            if !showSendButton {
                                Button(action: {
                                    // Log event for flash button
                                    Analytics.logEvent("clicked_flash", parameters: ["is_flash_on": shouldUseFlash])
                                    shouldUseFlash.toggle()
                                    cameraService.setFlashMode(shouldUseFlash ? .on : .off)
                                }) {
                                    Image(systemName: shouldUseFlash ? "bolt.fill" : "bolt.slash.fill")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 35, height: 35)
                                        .foregroundColor(.white)
                                        .padding(20)
                                }
                                .alignmentGuide(.bottom) { $0[.bottom] }
                                .alignmentGuide(.trailing) { $0[.trailing] }
                            } else {
                                
                                EmptyView()
                            }
                        },
                        alignment: .bottomLeading
                    )
                    
                    
                    
                    .overlay(
                        Group {
                            if !showSendButton {
                                Button(action: {
                                    // Log event for change camera button
                                    Analytics.logEvent("clicked_change_camera", parameters: nil)
                                    
                                    let generator = UIImpactFeedbackGenerator(style: .medium)
                                    generator.impactOccurred()
                                    cameraService.changeCamera()
                                }) {
                                    Image(systemName: "arrow.triangle.2.circlepath.camera")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 40, height: 30)
                                        .padding()
                                        .foregroundColor(.white)
                                }
                                .alignmentGuide(.bottom) { $0[.bottom] }
                                .alignmentGuide(.trailing) { $0[.trailing] }
                            } else {
                                // Include an empty view or the alternative view you want to show when 'showSendButton' is true
                                EmptyView()
                            }
                        },
                        alignment: .bottomTrailing
                    )
                    
                    
                    
                    
                    
                    
                    .overlay(
                        Group {
                            if !showSendButton {
                                Button(action: {
                                    
                                    // Log event for capture button
                                    Analytics.logEvent("clicked_capture", parameters: nil)
                                    
                                    // Take picture
                                    viewModel.capturePhoto()
                                    
                                    // Store the captured photo
                                    if let data = cameraService.photo?.originalData, let uiImage = UIImage(data: data) {
                                        capturedPhoto = uiImage  // <-- Store the captured image
                                    }
                                    
                                    // Update UI state to show the send button
                                    showSendButton = true
                                    
                                }) {
                                    Circle()
                                        .frame(width: 60, height: 60)
                                        .foregroundColor(.clear)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.white, lineWidth: UIScreen.main.bounds.width * 0.015)
                                        )
                                }
                                .alignmentGuide(.bottom) { $0[.bottom] }
                                .alignmentGuide(.trailing) { $0[.trailing] }
                                .offset(y: -15)
                            } else {
                                
                                EmptyView()
                            }
                        },
                        alignment: .bottom
                    )
                    
                    
                    
                    
                    
                    
                    
                    ZStack {
                        VStack {
                            Spacer ()
                            if showSendButton {
                                // AutoSizingTF replaces ResizableTextField
                                AutoSizingTF(
                                    hint: NSLocalizedString("Écrire une légende...", comment: "Hint for writing a caption"),
                                    text: $viewModel.commentText,
                                    containerHeight: $dynamicHeight,
                                    onEnd: {
                                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                                    }
                                )
                                .padding(.horizontal)
                                .frame(height: dynamicHeight <= 120 ? dynamicHeight : 120)
                                .background(Color.black)
                                .cornerRadius(10)
                                .foregroundColor(.white)
                                .offset(y: -55)
                                .padding(.bottom, keyboardHeight)
                            }
                        }
                        
                        
                        
                        
                        if showSendButton {
                            HStack {
                                Spacer ()
                                VStack {
                                    Spacer ()
                                    Spacer ()
                                    Button(action: {
                                        Analytics.logEvent("clicked_send", parameters: nil)
                                        if !isButtonClicked {
                                            if let capturedImage = viewModel.capturedPhoto,
                                               let imageData = capturedImage.jpegData(compressionQuality: 0.7) {
                                                
                                                let userID = Auth.auth().currentUser?.uid ?? ""
                                                
                                                // Assuming uploadPhotoAndPostComment() does not return a Combine publisher
                                                viewModel.uploadPhotoAndPostComment()
                                                
                                                // Remove the unnecessary sink call
                                                // .sink { completion in ... }
                                                // .store(in: &cancellables)
                                            }
                                            
                                            self.presentationMode.wrappedValue.dismiss()
                                        }
                                    }) {
                                        Image(systemName: "arrow.right.circle.fill")
                                            .resizable()
                                            .frame(width: 50, height: 50)
                                            .padding()
                                            .foregroundColor(.white)
                                    }
                                    .padding(.trailing, 20)
                                    .offset(y: -5)
                                    .disabled(isButtonClicked)
                                }
                                .offset(y: -keyboardHeight)
                                .padding(.top, keyboardHeight)
                            }
                            
                        }
                    }
                }
            }
                    .frame(height: 100)
                    .onTapGesture {
                        if isCaptionFieldActive {
                            // Log event for caption field
                            Analytics.logEvent("caption_field_active", parameters: nil)
                            isCaptionFieldActive = false
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        }
                    }
                    .offset(y: -10)
                }
                
                
                .onAppear {
                    viewModel.startCamera()
                    cameraService.configure()
                    //observeKeyboardHeight()
                    self.observeKeyboardHeight()
                    viewModel.clearCapturedPhoto() // Clear any existing photo
                }
                
                .onDisappear {
                    viewModel.stopCamera()
                    viewModel.clearCapturedPhoto() // Clear the photo when view disappears

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
            .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
            .padding(.bottom, 60)

        }

    }




/*

#if DEBUG
import SwiftUI

struct CommentCameraView_Previews: PreviewProvider {
    static var previews: some View {
        CameraView(isShown: .constant(true), cameraService: CameraService())
    }
}
#endif
*/
