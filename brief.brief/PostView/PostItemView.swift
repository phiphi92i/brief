//PostItemView.swift
//  brief.brief
//
//  Created by Philippe Tchinda on 19/06/2023.
//

import SwiftUI
import Firebase
import FirebaseStorage
import FirebaseAuth
import SDWebImageSwiftUI
import FirebaseFirestore
import UserNotifications
import Foundation
import FirebaseAnalytics
import Nuke
import SwipeActions
import ImageViewer
import Combine
import UIKit
//import LNExtensionExecutor


struct ImageModifier: ViewModifier {
    private var contentSize: CGSize
    private var min: CGFloat = 1.0
    private var max: CGFloat = 3.0
    @Binding var currentScale: CGFloat

    init(contentSize: CGSize, scale: Binding<CGFloat>) {
        self.contentSize = contentSize
        self._currentScale = scale
    }

    func body(content: Content) -> some View {
        content
            .frame(width: contentSize.width * currentScale, height: contentSize.height * currentScale, alignment: .center)
            .modifier(PinchToZoom(minScale: min, maxScale: max, scale: $currentScale))
            .animation(.easeInOut, value: currentScale)
    }
}

class PinchZoomView: UIView {
    let minScale: CGFloat
    let maxScale: CGFloat
    var isPinching: Bool = false
    var scale: CGFloat = 1.0
    let scaleChange: (CGFloat) -> Void
    
    init(minScale: CGFloat,
           maxScale: CGFloat,
         currentScale: CGFloat,
         scaleChange: @escaping (CGFloat) -> Void) {
        self.minScale = minScale
        self.maxScale = maxScale
        self.scale = currentScale
        self.scaleChange = scaleChange
        super.init(frame: .zero)
        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(pinch(gesture:)))
        pinchGesture.cancelsTouchesInView = false
        addGestureRecognizer(pinchGesture)
    }
    
    required init?(coder: NSCoder) {
        fatalError()
    }
    
    @objc private func pinch(gesture: UIPinchGestureRecognizer) {
        switch gesture.state {
        case .began:
            isPinching = true
            
        case .changed, .ended:
            if gesture.scale <= minScale {
                scale = minScale
            } else if gesture.scale >= maxScale {
                scale = maxScale
            } else {
                scale = gesture.scale
            }
            scaleChange(scale)
        case .cancelled, .failed:
            isPinching = false
            scale = 1.0
        default:
            break
        }
    }
}

struct PinchZoom: UIViewRepresentable {
    let minScale: CGFloat
    let maxScale: CGFloat
    @Binding var scale: CGFloat
    @Binding var isPinching: Bool
    
    func makeUIView(context: Context) -> PinchZoomView {
        let pinchZoomView = PinchZoomView(minScale: minScale, maxScale: maxScale, currentScale: scale, scaleChange: { scale = $0 })
        return pinchZoomView
    }
    
    func updateUIView(_ pageControl: PinchZoomView, context: Context) { }
}

struct PinchToZoom: ViewModifier {
    let minScale: CGFloat
    let maxScale: CGFloat
    @Binding var scale: CGFloat
    @State var anchor: UnitPoint = .center
    @State var isPinching: Bool = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(scale, anchor: anchor)
            .animation(.spring(), value: isPinching)
            .overlay(PinchZoom(minScale: minScale, maxScale: maxScale, scale: $scale, isPinching: $isPinching))
    }
}


struct ImageOverlayInfo {
    var profileImageUrl: String
    var username: String
    var timestamp: Date
    // Add other properties as needed
}



struct ImageView: View {
    var imageUrls: [String]
    var locationText: String?
    @State public var firstUIImage: UIImage? = nil
    @State public var secondUIImage: UIImage? = nil
    @State private var isLoading = true
    @State private var loadFailed = false
    @State private var showLocationText = true
    @ObservedObject var cameraViewModel: CameraViewModel
    var onImageTap: () -> Void
    @State private var secondUIImagePosition: CGSize = .zero
    @State private var showSecondUIImage = true
    @State private var zoomScale: CGFloat = 1.0


    var body: some View {
          GeometryReader { geometry in
              ZStack(alignment: .bottom) {
                  if isLoading {
                      ProgressView()
                          .progressViewStyle(LinearProgressViewStyle())
                          .frame(width: geometry.size.width, height: geometry.size.width * 1.75) // Slightly reduced height
                  } else if let firstUIImage = firstUIImage {
                      Image(uiImage: firstUIImage)
                          .resizable()
                          .scaledToFill()
                          .frame(width: geometry.size.width, height: geometry.size.width * 1.75) // Slightly reduced height
                          .clipped()
                          .modifier(ImageModifier(contentSize: CGSize(width: geometry.size.width, height: geometry.size.width * 1.75), scale: $zoomScale)) // Slightly reduced height
                          .overlay(
                              Group {
                                  if showLocationText, let locationText = locationText {
                                      HStack {
                                          Text(locationText)
                                              .font(.headline)
                                              .foregroundColor(.black)
                                              .padding(.horizontal, 10)
                                              .padding(.vertical, 5)
                                              .background(Color.white)
                                              .padding(15)
                                          Spacer()
                                      }
                                      .frame(height: 40)
                                      .padding(.top, 20)
                                  }
                              },
                              alignment: .top
                          )
                          .overlay(
                              Group {
                                  if showSecondUIImage, let secondUIImage = secondUIImage {
                                      Image(uiImage: secondUIImage ?? UIImage())
                                          .resizable()
                                          .scaledToFill()
                                          .frame(width: geometry.size.width / 2.2, height: geometry.size.height / 2.5)
                                          .cornerRadius(15)
                                          .overlay(
                                              RoundedRectangle(cornerRadius: 15)
                                                  .stroke(Color.white, lineWidth: 2)
                                          )
                                          .padding(4)
                                          .position(x: geometry.size.width - geometry.size.width / 4 - 15 + secondUIImagePosition.width,
                                                    y: geometry.size.height / 6 + 30 + secondUIImagePosition.height)
                                          .gesture(
                                              DragGesture(minimumDistance: 0, coordinateSpace: .local)
                                                  .onChanged { value in
                                                      self.secondUIImagePosition = value.translation
                                                  }
                                                  .onEnded { _ in
                                                      self.secondUIImagePosition = .zero
                                                  }
                                                  .simultaneously(with: TapGesture()
                                                      .onEnded { _ in
                                                          let temp = self.firstUIImage
                                                          self.firstUIImage = self.secondUIImage
                                                          self.secondUIImage = temp
                                                          Haptics.shared.play(.light)
                                                      }
                                                  )
                                          )
                                          .gesture(
                                              LongPressGesture().onEnded { _ in
                                                  withAnimation {
                                                      showLocationText.toggle()
                                                      showSecondUIImage.toggle()
                                                      Haptics.shared.play(.light)
                                                  }
                                              }
                                          )
                                  }
                              },
                              alignment: .top
                          )
                  } else if loadFailed {
                      Button(action: {
                          isLoading = true
                          loadFailed = false
                          loadImages()
                      }) {
                          Image(systemName: "arrow.clockwise")
                              .frame(width: geometry.size.width, height: geometry.size.width * 1.75) // Slightly reduced height
                      }
                  }
              }
              .cornerRadius(22) // Slightly reduced corner radius
          }
          .onAppear(perform: loadImages)
          .frame(height: UIScreen.main.bounds.width * 1.47) // Slightly reduced height
          .clipped()
      }


    
    
    private func loadImages() {
        if imageUrls.count >= 1 {
            loadImage(for: imageUrls[0]) { image in
                self.firstUIImage = image
            }
        }
        
        if imageUrls.count >= 2 {
            loadImage(for: imageUrls[1]) { image in
                self.secondUIImage = image
            }
        }
    }
    
    func snapshot() -> UIImage {
        let controller = UIHostingController(rootView: self)
        let view = controller.view
        
        let targetSize = controller.view.intrinsicContentSize
        view?.bounds = CGRect(origin: .zero, size: targetSize)
        view?.backgroundColor = .clear
        
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            view?.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
        }
    }
    
    func shareImage() {
        let image = snapshot()
        let activityViewController = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        UIApplication.shared.windows.first?.rootViewController?.present(activityViewController, animated: true, completion: nil)
    }
    
    
    
    
    func shareScreenshot() {
        guard let screenshot = captureScreenshot() else {
            print("Failed to capture screenshot.")
            return
        }
        
        let activityViewController = UIActivityViewController(activityItems: [screenshot], applicationActivities: nil)
        UIApplication.shared.windows.first?.rootViewController?.present(activityViewController, animated: true, completion: nil)
    }
    
    
    func captureScreenshot() -> UIImage? {
        let vc = UIHostingController(rootView: self)
        vc.view.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
        
        let renderer = UIGraphicsImageRenderer(size: vc.view.frame.size)
        let image = renderer.image { context in
            vc.view.drawHierarchy(in: vc.view.frame, afterScreenUpdates: true)
        }
        
        return image
    }
    
    func resizeImage(image: UIImage, newSize: CGSize) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(newSize, false, image.scale)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return resizedImage ?? image
    }
    
    
    func loadThumbnail(completion: @escaping (UIImage?) -> Void) {
        if let firstImageUrl = imageUrls.first {
            let request = ImageRequest(url: URL(string: firstImageUrl)!)
            ImagePipeline.shared.loadImage(with: request) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let response):
                        let thumbnailSize = CGSize(width: 100, height: 100)
                        let thumbnailImage = self.resizeImage(image: response.image, newSize: thumbnailSize)
                        completion(thumbnailImage)
                    case .failure:
                        completion(nil)
                    }
                }
            }
        } else {
            completion(nil)
        }
    }
    
    
    
    
    
    
    private func loadImage(for urlString: String, completion: @escaping (UIImage?) -> Void) {
        guard let url = URL(string: urlString) else {
            isLoading = false
            loadFailed = true
            return
        }
        
        let request = ImageRequest(url: url)
        ImagePipeline.shared.loadImage(with: request) { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(let response):
                    completion(response.image) // Call the completion handler with the image
                case .failure:
                    loadFailed = true
                }
            }
        }
    }
    
    class Haptics {
        static let shared = Haptics()
        
        private init() { }
        
        func play(_ feedbackStyle: UIImpactFeedbackGenerator.FeedbackStyle) {
            UIImpactFeedbackGenerator(style: feedbackStyle).impactOccurred()
        }
        
        func notify(_ feedbackType: UINotificationFeedbackGenerator.FeedbackType) {
            UINotificationFeedbackGenerator().notificationOccurred(feedbackType)
        }
    }
}







struct PostItemView: View {
    @StateObject private var viewModel = FeedViewModel()
    @StateObject var profileViewModel: ProfileViewModel
    @ObservedObject var cameraViewModel: CameraViewModel

    let post: UserPost

    var isLiked: Bool {
        likes.contains(Auth.auth().currentUser?.uid ?? "")
    }
    
    var isReacted: Bool {
        reactions.keys.contains(Auth.auth().currentUser?.uid ?? "")
    }


    @State private var showCommentView = false
    @State private var showActionSheet = false
    @State private var commentCount: Int = 0
    @State private var likesCount: Int = 0
    @State private var likes: [String] = []
    @State private var temporaryScale: CGFloat = 1.0
    @State private var zoomed: Bool = false
    @State private var scale: CGFloat = 1.0
    @State private var tempScale: CGFloat = 1.0
    @State private var initialScale: CGFloat = 1.0
    @State private var gestureScale: CGFloat = 1.0
//    @State private var reactionsList = false
    @State private var activeSheet: ActiveSheet? = nil
    @State private var timer = Timer.publish(every: 1, on: .main, in:
    .common).autoconnect()
    @State private var timeLeft: CGFloat = 1.0
    @ObservedObject var timerManager: TimerManager
    @State private var showViewersList = false
    @State private var viewsCount: Int = 0
    @State private var views: [String] = []
//    @State private var hasCurrentUserPostedRecently = false
    @ObservedObject var postItemViewModel = PostItemViewModel()
    var postId: String
    @ObservedObject var CommentcameraService: CommentCameraService
    @State private var currentUsername: String = ""
    @State private var viewsListenerRegistration: ListenerRegistration?
    @State private var likesListenerRegistration: ListenerRegistration?
    @State private var commentsListenerRegistration: ListenerRegistration?
    @State private var showImageViewer = false
    @State private var selectedImageUrl: String? = nil
    @State private var hasCurrentUserPostedRecently = false
    @State private var navigateToPost = false
    @State private var imageView: ImageView? = nil
    @State private var areImagesLoaded = false
    @State private var reactionsListenerRegistration: ListenerRegistration?
    @State private var showReactionView = false
    @State private var reactions: [String: Int] = [:]
    @State private var showReactionsList = false
    @State private var showReactionOverlay = false
    @State private var hasReacted: Bool = false
    @State private var selectedTab = 1


//    @State private var lnExecutorShareItem: LNExtensionExecutorShareItem? = nil

    var imageViews: [Image] {
        var views = [Image]()
        if let firstUIImage = imageView?.firstUIImage {
            views.append(Image(uiImage: firstUIImage))
        }
        if let secondUIImage = imageView?.secondUIImage {
            views.append(Image(uiImage: secondUIImage))
        }
        return views
    }


    
    var actionSheetButtons: [ActionSheet.Button] {
        var buttons = [ActionSheet.Button]()
        // Add the delete button only if the user is the author of the post
        if post.userID == Auth.auth().currentUser?.uid {
            buttons.append(.destructive(Text(NSLocalizedString("Supprimer", comment: "Delete button title")), action: {
                deletePost()
            }))
        }
        // Add the report button for all users
        buttons.append(.default(Text(NSLocalizedString("Signaler", comment: "Report button title")), action: {
            reportPost()
        }))
        // Add the share button for all users
        buttons.append(.default(Text(NSLocalizedString("Partager", comment: "Share button title")), action: {
                    shareImage()
//                    self.lnExecutorShareItem = LNExtensionExecutorShareItem(url: URL(string: "https://www.example.com")!, extensionBundleIdentifier: "com.burbn.instagram.shareextension")
////                    Haptics.shared.play(.light)
////                    Mixpanel.mainInstance().track(event: "Social invite pressed", properties: ["type": "ig_dm"])
                }))

                buttons.append(.cancel())
                return buttons
            }


    
    enum ActiveSheet: Identifiable {
        case commentView, reactionsList, viewersList

        var id: Int {
            switch self {
            case .commentView:
                return 1
            case .reactionsList:
                return 2
            case .viewersList:
                return 3
                
            }
        }
    }


    
    

    init(post: UserPost, cameraViewModel: CameraViewModel, commentCameraService: CommentCameraService) {
//        _viewModel = StateObject(wrappedValue: FeedViewModel())
            self.post = post
            self.cameraViewModel = cameraViewModel
            self._profileViewModel = StateObject(wrappedValue: ProfileViewModel(userID: post.userID))
            self.timerManager = TimerManager(postTimestamp: post.timestamp)
            self.postId = post.id ?? ""
            self.CommentcameraService = commentCameraService

        
        }
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                // Profile image on the left
                NavigationLink(destination: ProfileView(userID: post.userID, viewModel: profileViewModel)) {
                    if let imageUrl = URL(string: post.profileImageUrl) {
                        WebImage(url: imageUrl)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 35, height: 35)
                            .clipShape(Circle())
                    } else {
                        Text(String(viewModel.userFirstNameInitial))
                            .font(.system(size: 25, weight: .bold))
                            .frame(width: 35, height: 35)
                            .background(Color.green)
                            .clipShape(Circle())
                    }
                }
                
                // Username and Location vertically aligned on the right of the profile image
                VStack(alignment: .leading, spacing: 4) {
                    NavigationLink(destination: ProfileView(userID: post.userID, viewModel: profileViewModel)) {
                        Text(post.username)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.black)
                    }
                    if let location = post.location {
                        Text(location.address)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                
                
                
                Spacer()
                
                Text(timeAgo(date: post.timestamp))
                    .font(.caption)
                    .foregroundColor(.gray)
                
                // Vertical Stack to include ellipsis and sensory circle
                VStack(spacing: 3) {
                    Button(action: {
                        showActionSheet = true
                    }) {
                        Image(systemName: "ellipsis")
                            .foregroundColor(.gray)
                    }
                    .actionSheet(isPresented: $showActionSheet) {
                        ActionSheet(
                            title: Text(NSLocalizedString("Options", comment: "Options for post actions")),
                            buttons: actionSheetButtons
                        )
                    }
                    
                    // Sensory circle timer under the ellipsis
                    Circle()
                        .trim(from: 0, to: timeLeft)
                        .stroke(Color(red: 0.07, green: 0.04, blue: 1), lineWidth: 4)
                        .frame(width: 20, height: 20)
                        .rotationEffect(.degrees(-90))
                }
            }
            
            
            
            
            VStack(alignment: .leading) {
                
                
               
                // Text content
                Text(post.content)
                    .foregroundColor(.black)
                    .padding(.bottom, 5)
                    .blur(radius: hasCurrentUserPostedRecently ? 0 : 10)
                
                
                if cameraViewModel.isUploadingPost {
                                ProgressView("Uploading post...")
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(1.5)
                } else {
                    
                    // Image content
                    if !post.images.isEmpty {
                        let imageUrls = Array(post.images.prefix(2)) // Get the first two image URLs
                        
                        ImageView(
                            imageUrls: imageUrls, // Pass the array containing the image URLs
                            locationText: post.location?.address,
                            cameraViewModel: cameraViewModel
                        ) {
                            self.selectedImageUrl = imageUrls.first ?? ""
                            self.showImageViewer = true
                        }
                        .blur(radius: hasCurrentUserPostedRecently ? 0 : 25)
                        
                        .onAppear {
                            if !post.images.isEmpty {
                                let imageUrls = Array(post.images.prefix(2)) // Get the first two image URLs
                                self.imageView = ImageView(
                                    imageUrls: imageUrls,
                                    locationText: post.location?.address,
                                    cameraViewModel: cameraViewModel
                                ) {
                                    self.selectedImageUrl = imageUrls.first ?? ""
                                    self.showImageViewer = true
                                }
                            }
                        }
                    }
                }
                
                
                
                
                
                
                // Audio content
                Group {
                    if let audioURL = post.audioURL {
                        AudioVisualization(audioURL: audioURL)
                            .padding(.bottom,5)
                            .blur(radius: hasCurrentUserPostedRecently ? 0 : 10)
                    } else {
                        EmptyView()
                    }
                }
                .onAppear {
                    if let audioURL = post.audioURL {
                        print("Audio URL for post \(post.id ?? "unknown"): \(audioURL)")
                    }
                }
            }
            
            
            
            
            
            .overlay(
                Group {
                    if !hasCurrentUserPostedRecently {
                        Button(action: {
                            
                        }) {
                            Label(NSLocalizedString("Poster pour voir le brief de votre ami", comment: "Prompt to post for seeing a friend's brief"), systemImage: "eye.slash.fill")
                                .foregroundColor(.black)
                                .font(.subheadline)
                                .padding(determineContentPadding(text: post.content, images: post.images, audioURL: post.audioURL))
                                .background(Color.white)
                                .cornerRadius(10)
                            
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    
                }
            )
            
            
            
            
            
            if post.id == "temp" {
                ZStack {
                    RoundedRectangle(cornerRadius: 15.33333)
                        .fill(Color.black.opacity(0.8))
                        .frame(height: 700 - 100)
                        .overlay(
                            ProgressView(value: cameraViewModel.uploadProgress, total: 1.0)
                                .progressViewStyle(LinearProgressViewStyle(tint: .white))
                                .scaleEffect(1.5, anchor: .center)
                                .padding()
                        )
                }
            }
            
            
            
            
            HStack(spacing: 10) {
                Button(action: {
                    showReactionOverlay.toggle()
                    hasReacted.toggle() // Toggle the reaction state when the button is pressed
                }) {
                    Image(systemName: hasReacted ? "face.smiling.fill" : "face.smiling") // Conditional icon
                        .foregroundColor(hasReacted ? .black : .gray) // Change color when reacted
                }

                
                

                            Button(action: {
                                activeSheet = .reactionsList
                            }) {
                                Text(reactionsCountString)
                                    .font(.subheadline)
                                    .foregroundColor(.black)
                                    .background(Color.secondary.opacity(0.2))
                                    .cornerRadius(10)
                            }

                            Button(action: {
                                activeSheet = .commentView
                            }) {
                                Image(systemName: "message")
                                    .foregroundColor(.black)
                            }

                            Text("\(commentCount)")
                                .font(.subheadline)
                                .foregroundColor(.black)

                            Button(action: {
                                activeSheet = .viewersList
                            }) {
                                Image(systemName: "eyes")
                                    .foregroundColor(.black)
                            }
                            Text("\(viewsCount)")
                                .font(.subheadline)
                                .foregroundColor(.black)

                            Spacer()

                            if post.userID == Auth.auth().currentUser?.uid {
                                if post.distributionCircles.contains("all_friends") {
                                    Text(NSLocalizedString("Partagé avec: Tout mes amis", comment: "Shared with all friends"))
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                } else {
                                    Text(NSLocalizedString("Partagé avec:", comment: "Shared with") + " \(post.distributionCircles.joined(separator: ", "))")
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                }
                            }
                

                
                        }
                        .font(.title3)
                        .buttonStyle(PlainButtonStyle())
            if showReactionOverlay {
                            ReactionOverlay(isPresented: $showReactionOverlay,postId: postId, reactions: $reactions, onReact: {
                                showReactionOverlay = false
                            })
                        }
                    }
        
        .background(
            NavigationLink(destination: SinglePostView(/*viewModel: viewModel,*/ postId: postId, cameraViewModel: cameraViewModel ,commentCameraService: CommentcameraService), isActive: $navigateToPost) {
                EmptyView()
            }
                .hidden()
            
        )
        
//        .background(
//                    LNExtensionExecutorPresenterView(shareItem: $lnExecutorShareItem) { (completed, returnedItems, error) in
//                        // Handle the result
//                        self.lnExecutorShareItem = nil // Dismiss the sheet after sharing
//                    }
//                )
//        
        
        .onTapGesture {
            navigateToPost = true
        }
        .padding()
        .background(Color(white: 1, opacity: 0.8))
        .cornerRadius(15)
        .shadow(color: Color.black.opacity(0.4), radius: 10, x: 2, y: 2)
        .padding(.horizontal)
        .onAppear {
            viewModel.isProcessingLike = false
            fetchCommentCount()
            setupReactionsListener()

//            fetchLikesCount()
            timerManager.resumeTimer()
            fetchViews()
            postItemViewModel.checkIfCurrentUserPostedRecently { hasPostedRecently in
                self.hasCurrentUserPostedRecently = hasPostedRecently
            }
            
            if let postId = post.id, let userId = Auth.auth().currentUser?.uid {
                recordView(postId: postId, userId: userId)
            }
        }
        //
        .onDisappear {
            removeViewsListener()
//            removeLikesListener()
            removeCommentsListener()
            removeReactionsListener()

            timerManager.pauseTimer()
            
        }
        .onReceive(timerManager.$timeLeft) { updatedTimeLeft in
            self.timeLeft = updatedTimeLeft
        }
        
        
        
        .fullScreenCover(isPresented: $showImageViewer) {
            if let imageUrl = selectedImageUrl, let url = URL(string: imageUrl) {
                // Here, replace this with your custom ImageViewer view if you have one
                // For demonstration, we're using a simple SwiftUI Image view loaded from a URL
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .edgesIgnoringSafeArea(.all)
                } placeholder: {
                    ProgressView()
                }
                .onTapGesture {
                    // Dismiss the viewer when the image is tapped again
                    self.showImageViewer = false
                }
            }
        }
        

                

            
        
        .sheet(item: $activeSheet) { item in
            switch item {
            case .commentView:
                NavigationView {
                    CommentView(
                        post: post,
                        username: post.username,
                        viewModel: CommentCameraViewModel(
                            commentCameraService: CommentcameraService,
                            currentUsername: currentUsername,
                            post: post
                        ),
                        postId: postId, CommentcameraService: CommentcameraService
                    )
                }
            case .reactionsList:
                NavigationView {
                    ReactionsListView(postId: postId)
                }
            case .viewersList:
                NavigationView {
                    ViewersListView(postId: post.id ?? "")
                }
            }
        }
    }

    
    
    // Helper function to determine padding based on content types present
    func determineContentPadding(text: String, images: [String], audioURL: URL?) -> EdgeInsets {
        // Initialize padding values
        let defaultPadding: CGFloat = 10
        let mixedContentPadding: CGFloat = 5
        let textOnlyPadding: CGFloat = 5
        let imageOrAudioPadding: CGFloat = 10

        // Determine presence of content types
        let hasText = !text.isEmpty
        let hasImages = !images.isEmpty
        let hasAudio = audioURL != nil

        // Determine padding based on content combination
        if hasText && !hasImages && !hasAudio {
            // Apply smaller padding for text-only content
            return EdgeInsets(top: textOnlyPadding, leading: textOnlyPadding, bottom: textOnlyPadding, trailing: textOnlyPadding)
        } else if hasText && (hasImages || hasAudio) {
            // Apply mixed content padding if text is combined with images or audio
            return EdgeInsets(top: mixedContentPadding, leading: mixedContentPadding, bottom: mixedContentPadding, trailing: mixedContentPadding)
        } else if hasImages || hasAudio {
            // Apply default padding for image or audio content without text
            return EdgeInsets(top: imageOrAudioPadding, leading: imageOrAudioPadding, bottom: imageOrAudioPadding, trailing: imageOrAudioPadding)
        } else {
            // Fallback to default padding
            return EdgeInsets(top: defaultPadding, leading: defaultPadding, bottom: defaultPadding, trailing: defaultPadding)
        }
    }



    func snapshot() -> UIImage {
        let controller = UIHostingController(rootView: self)
        let view = controller.view

        let targetSize = controller.view.intrinsicContentSize
        view?.bounds = CGRect(origin: .zero, size: targetSize)
        view?.backgroundColor = .clear

        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            view?.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
        }
    }
    
    func shareImage() {
            // Create a UIHostingController
            let hostingController = UIHostingController(rootView: self)
            guard let window = UIApplication.shared.windows.first(where: { $0.isKeyWindow }) else { return }

            // Add as a child view controller and setup its view
            window.rootViewController?.addChild(hostingController)
            hostingController.view.frame = CGRect(origin: CGPoint.zero, size: UIScreen.main.bounds.size)
            window.rootViewController?.view.insertSubview(hostingController.view, at: 0)

            // Take a snapshot after a short delay to ensure the view is rendered
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                let size = hostingController.view.bounds.size
                // Here, use UIScreen.main.scale to ensure the snapshot is taken with the current screen scale
                UIGraphicsBeginImageContextWithOptions(size, false, UIScreen.main.scale)
                if let context = UIGraphicsGetCurrentContext() {
                    hostingController.view.layer.render(in: context)
                    let image = UIGraphicsGetImageFromCurrentImageContext()
                    UIGraphicsEndImageContext()

                    // Clean up the hosting controller and its view
                    hostingController.view.removeFromSuperview()
                    hostingController.removeFromParent()

                    // Continue to share if we got an image
                    if let image = image {
                        // Add watermark or perform any additional operations
                        let watermarkedImage = addWatermark(to: image) // Assume addWatermark function is defined elsewhere
                        let activityViewController = UIActivityViewController(activityItems: [watermarkedImage], applicationActivities: nil)
                        UIApplication.shared.windows.first?.rootViewController?.present(activityViewController, animated: true, completion: nil)
                    }
                }
            }
        }
    
    


    private func addWatermark(to image: UIImage) -> UIImage {
        let watermarkText = "brief"
        let fontSize: CGFloat = 24 // Adjust font size as needed
        let watermarkAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont(name: "NanumPen", size: fontSize) ?? UIFont.systemFont(ofSize: fontSize),
            .foregroundColor: UIColor.black.withAlphaComponent(0.5) // Adjust alpha for transparency
        ]

        // Position the watermark in the top-left corner
        let textSize = (watermarkText as NSString).size(withAttributes: watermarkAttributes)
        let watermarkX: CGFloat = 10 // Adjusted position
        let watermarkY: CGFloat = 10 // Adjusted position

        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
        image.draw(in: CGRect(origin: CGPoint.zero, size: image.size))

        // Draw the text as watermark
        let textRect = CGRect(x: watermarkX, y: watermarkY, width: textSize.width, height: textSize.height)
        watermarkText.draw(in: textRect, withAttributes: watermarkAttributes)

        let watermarkedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return watermarkedImage ?? image
    }
//
//    // Helper function to resize an image
//    private func resizeImage(image: UIImage, targetSize: CGSize) -> UIImage {
//        let size = image.size
//
//        let widthRatio  = targetSize.width  / size.width
//        let heightRatio = targetSize.height / size.height
//
//        // Figure out what our orientation is, and use that to form the rectangle
//        var newSize: CGSize
//        if(widthRatio > heightRatio) {
//            newSize = CGSize(width: size.width * heightRatio, height: size.height * heightRatio)
//        } else {
//            newSize = CGSize(width: size.width * widthRatio,  height: size.height * widthRatio)
//        }
//
//        // This is the rect that we've calculated out and this is what is actually used below
//        let rect = CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height)
//
//        // Actually do the resizing to the rect using the ImageContext stuff
//        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
//        image.draw(in: rect)
//        let newImage = UIGraphicsGetImageFromCurrentImageContext()
//        UIGraphicsEndImageContext()
//
//        return newImage ?? image
//    }

    private var reactionsCountString: String {
        var countString = ""
        let sortedReactions = reactions.sorted { $0.value > $1.value }

        if !sortedReactions.isEmpty {
            let topReactions = Array(sortedReactions.prefix(3))
            for (reaction, count) in topReactions {
                countString += "\(reaction)"
            }
        }

        let totalReactions = reactions.values.reduce(0, +)
        if !countString.isEmpty {
            countString += "\(totalReactions)"
        }

        return countString
    }

    
    func setupReactionsListener() {
        reactionsListenerRegistration?.remove() // Remove existing listener if any
        guard let postId = post.id else { return } // Ensure postId is not nil
        reactionsListenerRegistration = Firestore.firestore().collection("posts").document(postId)
            .collection("reactions")
            .addSnapshotListener { (snapshot, error) in
                guard let snapshot = snapshot else {
                    print("Error fetching reactions: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                var newReactions: [String: Int] = [:]
                for document in snapshot.documents {
                    guard let reaction = document.data()["reaction"] as? String else {
                        continue
                    }
                    newReactions[reaction, default: 0] += 1
                }
                self.reactions = newReactions
            }
    }

    func removeReactionsListener() {
        reactionsListenerRegistration?.remove()
    }
        
        
    // Define the fetchViews function
    private func fetchViews() {
        Firestore.firestore()
            .collection("posts")
            .document(post.id ?? "")
            .collection("views")
            .addSnapshotListener { snapshot, error in
                guard let documents = snapshot?.documents else {
                    print("Error fetching views: \(error?.localizedDescription ?? "")")
                    return
                }
                self.views = documents.map { $0.documentID }
                self.viewsCount = documents.count
            }
    }

    
    func recordView(postId: String, userId: String) {
        // Check cache first
        if ViewCache.shared.hasRecordedView(postId: postId, userId: userId) {
            print("View already recorded for this user (cached).")
            return
        }
        
        let db = Firestore.firestore()
        let viewRef = db.collection("posts").document(postId).collection("views").document(userId)

        // Attempt to fetch an existing view document for the current user
        viewRef.getDocument { (document, error) in
            if let document = document, document.exists {
                print("View already recorded for this user (Firestore).")
                // Add to cache to avoid future network calls
                ViewCache.shared.addRecordedView(postId: postId, userId: userId)
            } else {
                // The view doesn't exist, record a new view
                let viewTimestamp = Timestamp(date: Date())
                viewRef.setData(["viewedAt": viewTimestamp]) { error in
                    if let error = error {
                        print("Error recording view: \(error.localizedDescription)")
                    } else {
                        print("New view recorded successfully.")
                        // Add this view to the cache
                        ViewCache.shared.addRecordedView(postId: postId, userId: userId)
                    }
                }
            }
        }
    }




    func fetchViewCount(postId: String, completion: @escaping (Int) -> Void) {
        let db = Firestore.firestore()
        db.collection("posts").document(postId).collection("views").getDocuments { snapshot, error in
            if let error = error {
                print("Error getting views: \(error.localizedDescription)")
                completion(0)
            } else {
                let viewCount = snapshot?.documents.count ?? 0
                completion(viewCount)
            }
        }
    }

    func fetchViewDetails(postId: String, completion: @escaping ([String]) -> Void) {
        let db = Firestore.firestore()
        db.collection("posts").document(postId).collection("views").getDocuments { snapshot, error in
            if let error = error {
                print("Error getting view details: \(error.localizedDescription)")
                completion([])
            } else {
                let viewers = snapshot?.documents.map { $0.documentID } ?? []
                completion(viewers)
            }
        }
    }

    

    private func fetchCommentCount() {
        Firestore.firestore()
            .collection("posts")
            .document(post.id ?? "")
            .collection("comments")
            .addSnapshotListener { snapshot, error in
                guard let documents = snapshot?.documents else {
                    print("Error fetching comments: \(error?.localizedDescription ?? "")")
                    return
                }
                
                commentCount = documents.count
            }
    }
    
    private func fetchLikesCount() {
        Firestore.firestore()
            .collection("posts")
            .document(post.id ?? "")
            .collection("likes")
            .addSnapshotListener { snapshot, error in
                guard let documents = snapshot?.documents else {
                    print("Error fetching likes count: \(error?.localizedDescription ?? "")")
                    return
                }
                
                var newLikes: [String] = []  // Use a temporary array
                for document in documents {
                    newLikes.append(document.documentID)
                }
                
                self.likes = Array(Set(newLikes))
                likesCount = likes.count
            }
    }


    func setupViewsListener() {
        // Remove any existing listener
        viewsListenerRegistration?.remove()
        // Set up the new listener
        viewsListenerRegistration = Firestore.firestore().collection("posts").document(postId).collection("views")
            .addSnapshotListener { querySnapshot, error in
                // Handle snapshot updates
                guard let snapshot = querySnapshot else {
                    print("Error fetching snapshot updates: \(error?.localizedDescription ?? "No error")")
                    return
                }
                // Process the snapshot data...
                let viewCount = snapshot.documents.count
                print("There are \(viewCount) views on this post.")
            }
    }

    func removeViewsListener() {
        viewsListenerRegistration?.remove()
    }
    
    func setupLikesListener() {
        likesListenerRegistration?.remove() // Remove existing listener if any
        guard let postId = post.id else { return } // Safely unwrap post.id
        likesListenerRegistration = Firestore.firestore().collection("posts").document(postId)
            .collection("likes")
            .addSnapshotListener { (snapshot, error) in
                guard let snapshot = snapshot else {
                    print("Error fetching likes: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                // Directly mutate the state since 'self' is not used or needed
                self.likes = snapshot.documents.map { $0.documentID }
            }
    }
    
    func removeLikesListener() {
        likesListenerRegistration?.remove()
    }

    func setupCommentsListener() {
        commentsListenerRegistration?.remove() // Remove existing listener if any
        guard let postId = post.id else { return } // Ensure postId is not nil
        commentsListenerRegistration = Firestore.firestore().collection("posts").document(postId)
            .collection("comments")
            .addSnapshotListener { (snapshot, error) in
                guard let snapshot = snapshot else {
                    print("Error fetching comments: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                // Update comment count directly
                self.commentCount = snapshot.documents.count
            }
    }

    func removeCommentsListener() {
        commentsListenerRegistration?.remove()
    }

    

    private func likeAction() {
        guard let currentUserID = Auth.auth().currentUser?.uid else {
            print("User is not logged in. Cannot perform like/unlike action.")
            return
        }
        
        let likesRef = Firestore.firestore().collection("posts").document(post.id ?? "").collection("likes")
        
        if isLiked {
            // Unlike operation
            likesRef.document(currentUserID).delete { error in
                if let error = error {
                    print("Error unliking post: \(error)")
                } else {
                    print("Post unliked successfully.")
                    likes.removeAll { $0 == currentUserID }
                }
            }
        } else {
            // Like operation
            likesRef.document(currentUserID).setData([:]) { error in
                if let error = error {
                    print("Error liking post: \(error)")
                } else {
                    print("Post liked successfully.")
                    if !likes.contains(currentUserID) {  // Only add if not already in the array
                        likes.append(currentUserID)
                    }
                }
            }
        }
    }


    class TimerManager: ObservableObject {
        @Published var timeLeft: CGFloat = 1.0
        var timer: Timer?
        var postTimestamp: Date?
        
        init(postTimestamp: Date?) {
            self.postTimestamp = postTimestamp
            startTimer()  // Initialize and start the timer
        }

        // Start the timer
        private func startTimer() {
            self.timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                self?.updateTimeLeft()
            }

        }
        
        // Pause the timer
        func pauseTimer() {
            self.timer?.invalidate()
        }
        
        // Resume the timer
        func resumeTimer() {
            startTimer()
        }
        
        private func updateTimeLeft() {
            guard let postTimestamp = postTimestamp else { return }
            
            let calendar = Calendar.current
            let now = Date()
            let components = calendar.dateComponents([.second], from: postTimestamp, to: now)
            
            if let elapsedSeconds = components.second {
                let totalSecondsInDay: CGFloat = 24 * 60 * 60
                let remainingSeconds = totalSecondsInDay - CGFloat(elapsedSeconds)
                timeLeft = remainingSeconds / totalSecondsInDay
            }
        }
    }
    
    
    func getActionSheet() -> ActionSheet {
        let currentUserId = Auth.auth().currentUser?.uid ?? ""
        
        if post.userID == currentUserId {
            return ActionSheet(
                title: Text(NSLocalizedString("Options", comment: "Options for post actions")),
                buttons: [
                    .destructive(Text("Supprimer")) {
                        deletePost()
                    },
                    .destructive(Text("Signaler")) {
                        reportPost()
                    },
                    .cancel()
                ]
            )
        } else {
            return ActionSheet(
                title: Text(NSLocalizedString("Options", comment: "Options for post actions")),
                buttons: [
                    .destructive(Text("Signaler")) {
                        reportPost()
                    },
                    .cancel()
                ]
            )
        }
    }

    
    func reportPost() {
        guard let postId = post.id else {
            print("Error: Post ID is nil")
            return
        }

        let db = Firestore.firestore()
        let flaggedPostsCollection = db.collection("flaggedPosts")
        let currentUserId = Auth.auth().currentUser?.uid ?? ""

        // Add the post ID to the flaggedPosts collection
        flaggedPostsCollection.document(postId).setData([
            "flags": FieldValue.arrayUnion([currentUserId]),
        ], merge: true)
    }




    private func deletePost() {
        guard let currentUserID = Auth.auth().currentUser?.uid,
              currentUserID == post.userID else {
            print("Error: User is not authorized to delete this post.")
            return
        }
        
        // Log "Delete Post" action in Firebase Analytics
        Analytics.logEvent("post_deleted", parameters: [
            "post_id": post.id ?? "",
            "user_id": currentUserID
        ])

        let postRef = Firestore.firestore().collection("posts").document(post.id ?? "")

        postRef.delete { error in
            if let error = error {
                print(NSLocalizedString("Error removing document:", comment: "") + " \(error)")
            } else {
                print(NSLocalizedString("Document successfully removed!", comment: ""))
                viewModel.posts.removeAll { $0.id == post.id }
            }
        }
    }

    private func timeAgo(date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.second, .minute, .hour], from: date, to: now)

        if let hour = components.hour, hour >= 1 {
            if hour >= 24 {
                return NSLocalizedString("il y a 24 heures", comment: "Time ago in 24 hours")
            } else {
                return NSLocalizedString("il y a \(hour) heures", comment: "Time ago in hours")            }
        } else if let minute = components.minute, minute >= 1 {
            return String(format: NSLocalizedString("il y a %d minutes", comment: "Time ago in minutes"), minute)
        } else if let second = components.second {
            return String(format: NSLocalizedString("il y a %d secondes", comment: "Time ago in seconds"), second)
        } else {
            return NSLocalizedString("à l'instant", comment: "Just now")
        }
    }
}



struct LikersListView: View {
    @StateObject var viewModel: LikersListViewModel

    init(likes: [String]) {
        _viewModel = StateObject(wrappedValue: LikersListViewModel(likes: likes))
    }
    
    var body: some View {
        List(viewModel.likers, id: \.id) { liker in
            // Added NavigationLink to navigate to the user's profile
            NavigationLink(destination: ProfileView(userID: liker.id, viewModel: ProfileViewModel(userID: liker.id))) {
                HStack {
                    if let imageUrl = URL(string: liker.profileImageUrl) {
                        WebImage(url: imageUrl)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())
                    }
                    
                    Text(liker.username)
                        .foregroundColor(Color.primary)  // Adapts to color scheme
                }
            }
        }
        .preferredColorScheme(.light)
        .navigationTitle(NSLocalizedString("J'aime", comment: "Likes"))
//        .navigationBarTitleColor(.black) // Use the custom modifier here
        .foregroundColor(.black)
//        .toolbarColorScheme(.dark)
        .onAppear {
            viewModel.fetchLikersInfo()
        }
    }
}




class LikersListViewModel: ObservableObject {
    @Published var likers: [Liker] = []
    var likes: [String]
    
    init(likes: [String]) {
        self.likes = likes
    }
    
    struct Liker: Identifiable {
        var id: String
        var username: String
        var profileImageUrl: String
    }
    
    func fetchLikersInfo() {
        let db = Firestore.firestore()
        
        let uniqueLikes = Array(Set(likes))
        var newLikers = [Liker]()
        let group = DispatchGroup()
        
        for userId in uniqueLikes {
            group.enter()
            db.collection("users").document(userId).getDocument { document, error in
                defer { group.leave() }
                if let document = document, document.exists, let data = document.data() {
                    let username = data["username"] as? String ?? ""
                    let profileImageUrl = data["profileImageUrl"] as? String ?? ""
                    
                    let liker = Liker(id: userId, username: username, profileImageUrl: profileImageUrl)
                    newLikers.append(liker)
                }
            }
        }
        
        group.notify(queue: .main) {
            self.likers = newLikers
        }
    }
}

struct ViewersListView: View {
    @StateObject var viewModel: ViewersListViewModel
    var postId: String

    init(postId: String) {
        self.postId = postId
        _viewModel = StateObject(wrappedValue: ViewersListViewModel(postId: postId))
    }


    
    var body: some View {
        List(viewModel.viewers, id: \.id) { viewer in
            NavigationLink(destination: ProfileView(userID: viewer.id, viewModel:  ProfileViewModel (userID: viewer.id))) {
                
                HStack {
                    if let imageUrl = URL(string: viewer.profileImageUrl) {
                        WebImage(url: imageUrl)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())
                    }
                    Text(viewer.username)
                }
            }
        }
        .navigationTitle(NSLocalizedString("Vues", comment: "Views"))
//        .navigationBarTitleColor(.black) // Use the custom modifier here
//        .toolbarColorScheme(.dark)
        .foregroundColor(.black)
        .onAppear {
            viewModel.fetchViewersInfo()
        }
    }
}

class ViewersListViewModel: ObservableObject {
    @Published var viewers: [Viewer] = []
    var postId: String

    init(postId: String) {
        self.postId = postId
    }

    struct Viewer: Identifiable {
        var id: String
        var username: String
        var profileImageUrl: String
    }

    func fetchViewersInfo() {
        let db = Firestore.firestore()
        db.collection("posts").document(postId).collection("views").getDocuments { snapshot, error in
            guard let documents = snapshot?.documents else {
                print("Error fetching viewers: \(error?.localizedDescription ?? "")")
                return
            }

            let viewerIds = documents.map { $0.documentID }
            self.fetchUserDetails(userIds: viewerIds)
        }
    }

    private func fetchUserDetails(userIds: [String]) {
        let db = Firestore.firestore()
        var newViewers = [Viewer]()

        let group = DispatchGroup()

        for userId in userIds {
            group.enter()
            db.collection("users").document(userId).getDocument { document, error in
                defer { group.leave() }
                if let document = document, document.exists, let data = document.data() {
                    let username = data["username"] as? String ?? ""
                    let profileImageUrl = data["profileImageUrl"] as? String ?? ""
                    let viewer = Viewer(id: userId, username: username, profileImageUrl: profileImageUrl)
                    newViewers.append(viewer)
                }
            }
        }

        group.notify(queue: .main) {
            self.viewers = newViewers
        }
    }
}

struct ReactionOverlay: View {
    @Binding var isPresented: Bool
    var postId: String
    @Binding var reactions: [String: Int]
    var onReact: () -> Void

    var body: some View {
        ZStack(alignment: .leading) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) { // Reduce the spacing here
                    ForEach(ReactionType.allCases, id: \.self) { reactionType in
                        Button(action: {
                            reactToPost(reactionType: reactionType)
                            onReact()
                            isPresented = false // Dismiss the popover when a reaction is selected
                        }) {
                            Text(reactionType.rawValue)
                                .font(.title)
//                                .padding()
                        }
                        .background(Color.secondary.opacity(0.2))
                        .clipShape(Circle())
                    }
                }
                .padding(.vertical,10)
                .padding(.horizontal,5) // Reduce the horizontal padding here
                .background(Color.secondary.opacity(0.2).clipShape(Capsule()))
                .shadow(color: Color.black.opacity(0.15), radius: 5, x: -5, y: 5)
            }
        }
    }





    private func reactToPost(reactionType: ReactionType) {
        let db = Firestore.firestore()
        let reactionsRef = db.collection("posts").document(postId).collection("reactions")
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            return
        }

        reactionsRef.document(currentUserId).setData([
            "reaction": reactionType.rawValue
        ], merge: true) { error in
            if let error = error {
                print("Error reacting to post: \(error)")
            } else {
                print("Successfully reacted to post with \(reactionType.rawValue)")
            }
        }
    }

    enum ReactionType: String, CaseIterable {
        case laugh = "😂"
        case love = "❤️"
        case thumbs = "👍"
        case haha = "😭"
        case wow = "🤯"
        case angry = "😠"
    }
}

struct ReactionsListView: View {
    @StateObject var viewModel: ReactionsListViewModel
    var postId: String

    init(postId: String) {
        self.postId = postId
        _viewModel = StateObject(wrappedValue: ReactionsListViewModel(postId: postId))
    }
 
    var body: some View {
        List(viewModel.reactions, id: \.id) { reaction in
            NavigationLink(destination: ProfileView(userID: reaction.userID, viewModel: ProfileViewModel(userID: reaction.userID))) {
                HStack {
                    if let imageUrl = URL(string: reaction.profileImageUrl) {
                        WebImage(url: imageUrl)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())
                    }
                    Text(reaction.username)
                    Spacer()
//                    Text("\(reaction.count)")
                    Text(reaction.reaction)
                }
            }
            .buttonStyle(PlainButtonStyle())
        }
        .navigationTitle(NSLocalizedString("Réactions", comment: "reactions"))
        .onAppear {
            viewModel.fetchReactionsInfo()
        }
    }
}

class ReactionsListViewModel: ObservableObject {
    @Published var reactions: [ReactionUser] = []
    var postId: String

    init(postId: String) {
        self.postId = postId
    }

    struct ReactionUser: Identifiable {
        var id: String
        var userID: String
        var username: String
        var profileImageUrl: String
        var reaction: String
        var count: Int
    }

    func fetchReactionsInfo() {
        let db = Firestore.firestore()
        db.collection("posts").document(postId).collection("reactions").getDocuments { snapshot, error in
            guard let documents = snapshot?.documents else {
                print("Error fetching reactions: \(error?.localizedDescription ?? "")")
                return
            }

            let reactionData = documents.compactMap { document -> (String, String)? in
                guard let reaction = document.data()["reaction"] as? String else { return nil }
                return (document.documentID, reaction)
            }


            self.fetchUserDetailsAndCounts(reactionData: reactionData)
        }
    }

    private func fetchUserDetailsAndCounts(reactionData: [(String, String)]) {
        let db = Firestore.firestore()
        var newReactions = [ReactionUser]()

        let group = DispatchGroup()

        for (userID, reaction) in reactionData {
            group.enter()
            db.collection("users").document(userID).getDocument { document, error in
                defer { group.leave() }
                if let document = document, document.exists, let data = document.data() {
                    let username = data["username"] as? String ?? ""
                    let profileImageUrl = data["profileImageUrl"] as? String ?? ""
                    let newReaction = ReactionUser(id: userID, userID: userID, username: username, profileImageUrl: profileImageUrl, reaction: reaction, count: 1)
                    newReactions.append(newReaction)
                }
            }
        }

        group.notify(queue: .main) {
            self.groupReactionsByType(reactions: &newReactions)
        }
    }

    private func groupReactionsByType(reactions: inout [ReactionUser]) {
        var groupedReactions: [String: ReactionUser] = [:]

        for reaction in reactions {
            if var existingReaction = groupedReactions[reaction.reaction] {
                existingReaction.count += 1
                groupedReactions[reaction.reaction] = existingReaction
            } else {
                groupedReactions[reaction.reaction] = reaction
            }
        }

        self.reactions = Array(groupedReactions.values).sorted { $0.count > $1.count }
    }
}


class PostItemViewModel: ObservableObject {
//     @State private var hasCurrentUserPostedRecently = false

    
    public func checkIfCurrentUserPostedRecently(completion: @escaping (Bool) -> Void) {
        guard let currentUserID = Auth.auth().currentUser?.uid else {
            print("User not logged in")
            completion(false)
            return
        }
        
        let postsRef = Firestore.firestore().collection("posts").whereField("userID", isEqualTo: currentUserID)
        postsRef.order(by: "timestamp", descending: true).limit(to: 1).getDocuments { (querySnapshot, error) in
            if let error = error {
                print("Error getting documents: \(error)")
                completion(false)
            } else if let documents = querySnapshot?.documents, let mostRecentPost = documents.first {
                if let timestamp = mostRecentPost.get("timestamp") as? Timestamp {
                    let postDate = timestamp.dateValue()
                    let currentDate = Date()
                    let timeInterval = currentDate.timeIntervalSince(postDate)
                    completion(timeInterval <= (24 * 60 * 60))
                } else {
                    completion(false)
                }
            } else {
                completion(false)
            }
        }
    }
}

class ViewCache {
    static let shared = ViewCache()
    private init() {} // Singleton
    
    private var recordedViews: Set<String> = []
    
    func hasRecordedView(postId: String, userId: String) -> Bool {
        return recordedViews.contains("\(postId)_\(userId)")
    }
    
    func addRecordedView(postId: String, userId: String) {
        recordedViews.insert("\(postId)_\(userId)")
    }
}


class InstagramStoriesShare {
    // Identifiant de votre application Facebook
    let appID = "1234567890"
    
    func shareToInstagramStories(backgroundImage: UIImage?, stickerImage: UIImage?, backgroundTopColor: String?, backgroundBottomColor: String?) {
        guard let urlScheme = URL(string: "instagram-stories://share?source_application=\(appID)") else { return }
        
        if UIApplication.shared.canOpenURL(urlScheme) {
            var pasteboardItems: [String: Any] = [:]
            
            if let backgroundImage = backgroundImage, let imageData = backgroundImage.pngData() {
                pasteboardItems["com.instagram.sharedSticker.backgroundImage"] = imageData
            }
            
            if let stickerImage = stickerImage, let stickerImageData = stickerImage.pngData() {
                pasteboardItems["com.instagram.sharedSticker.stickerImage"] = stickerImageData
            }
            
            if let backgroundTopColor = backgroundTopColor {
                pasteboardItems["com.instagram.sharedSticker.backgroundTopColor"] = backgroundTopColor
            }
            
            if let backgroundBottomColor = backgroundBottomColor {
                pasteboardItems["com.instagram.sharedSticker.backgroundBottomColor"] = backgroundBottomColor
            }
            
            let pasteboardOptions = [UIPasteboard.OptionsKey.expirationDate: Date().addingTimeInterval(60 * 5)]
            UIPasteboard.general.setItems([pasteboardItems], options: pasteboardOptions)
            
            UIApplication.shared.open(urlScheme, options: [:], completionHandler: nil)
        } else {
            // Gérer le cas où Instagram n'est pas installé
            print("Instagram is not installed")
        }
    }
}

//struct LNExtensionExecutorShareItem {
//    let id = UUID()
//    let url: URL
//    let extensionBundleIdentifier: String
//}
//
//class LNExtensionExecutorViewController: UIViewController {
//    typealias Callback = (_ completed: Bool, _ returnedItems: [Any]?, _ error: Error?) -> Void
//
//    var extensionBundleIdentifier: String?
//    var activityItems: [Any]?
//    var callback: Callback?
//
//    var isPresented: Binding<Bool>? {
//        didSet {
//            if isPresented?.wrappedValue == true {
//                presentShareSheet()
//            }
//        }
//    }
//
//    func presentShareSheet() {
//        guard let identifier = extensionBundleIdentifier, let items = activityItems else {
//            return
//        }
//
//        Task {
//            do {
//                let executor = try LNExtensionExecutor(extensionBundleIdentifier: identifier)
//                let (completed, returnItems) = try await executor.execute(withActivityItems: items, on: self)
//
//                DispatchQueue.main.async {
//                    self.callback?(completed, returnItems, nil)
//                    self.isPresented?.wrappedValue = false
//                }
//            } catch(let error) {
//                DispatchQueue.main.async {
//                    self.callback?(false, nil, error)
//                    self.isPresented?.wrappedValue = false
//
//                    let specificError = error as NSError
//                    if specificError.code == 6001 {
//                        let alert = UIAlertController(title: nil, message: "Make sure the app you're sharing to is installed and have been opened recently.", preferredStyle: .alert)
//                        alert.addAction(UIAlertAction(title: "OK", style: .default))
//                        self.present(alert, animated: true)
//                    }
//                }
//            }
//        }
//    }
//}
//
//struct LNExtensionExecutorPresenterView: UIViewControllerRepresentable {
//    @Binding var shareItem: LNExtensionExecutorShareItem?
//    var callback: LNExtensionExecutorViewController.Callback?
//
//    func makeUIViewController(context: UIViewControllerRepresentableContext<LNExtensionExecutorPresenterView>) -> LNExtensionExecutorViewController {
//        let viewController = LNExtensionExecutorViewController()
//        update(viewController: viewController)
//        return viewController
//    }
//
//    func updateUIViewController(_ uiViewController: LNExtensionExecutorViewController, context: UIViewControllerRepresentableContext<LNExtensionExecutorPresenterView>) {
//        update(viewController: uiViewController)
//    }
//
//    func update(viewController: LNExtensionExecutorViewController) {
//        viewController.extensionBundleIdentifier = shareItem?.extensionBundleIdentifier
//        viewController.activityItems = [shareItem?.url].compactMap { $0 }
//        viewController.callback = callback
//        viewController.isPresented = shareItem != nil ? .constant(true) : .constant(false)
//    }
//}
