//

//




import SwiftUI
import UIKit
import Firebase
import SDWebImageSwiftUI
import FirebaseFirestore
import FirebaseStorage
import Combine
import FirebaseAnalytics



struct AutoSizingTF: UIViewRepresentable {
    
    
    
    var hint: String
    @Binding var text: String
    @Binding var containerHeight: CGFloat
    var onEnd : ()->()
    
    func makeCoordinator() -> Coordinator {
        return AutoSizingTF.Coordinator(parent: self)
    }
    
    func makeUIView(context: Context) -> UITextView {
        
        let textView = UITextView()
        // Displaying text as hint...
        textView.text = hint
        textView.textColor = .gray
        textView.backgroundColor = .clear
        textView.font = .systemFont(ofSize: 16)
        
        // setting delegate...
        textView.delegate = context.coordinator
        
        // Input Accessory View....
        // Your own custom size....
        let toolBar = UIToolbar(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 50))
        toolBar.barStyle = .default
        
        // since we need done at right...
        // so using another item as spacer...
        let spacer = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let doneButton = UIBarButtonItem(barButtonSystemItem: .done, target: context.coordinator, action: #selector(context.coordinator.closeKeyBoard))
        
        toolBar.items = [spacer,doneButton]
        toolBar.sizeToFit()
        
        textView.inputAccessoryView = toolBar
        
        // Apply rounded corners and border
        textView.layer.cornerRadius = 15
        textView.layer.borderColor = UIColor.gray.cgColor
        textView.layer.borderWidth = 1
        textView.clipsToBounds = true
        
        return textView
    }
    
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        
        // Starting Text Field Height...
        DispatchQueue.main.async {
            if containerHeight == 0{
                containerHeight = uiView.contentSize.height
            }
        }
    }
    
    class Coordinator: NSObject,UITextViewDelegate{
        
        // To read all parent properties...
        var parent: AutoSizingTF
        
        init(parent: AutoSizingTF) {
            self.parent = parent
        }
        
        // keyBoard Close @objc Function...
        @objc func closeKeyBoard(){
            
            parent.onEnd()
        }
        
        func textViewDidBeginEditing(_ textView: UITextView) {
            
            // checking if text box is empty...
            // is so then clearing the hint...
            if textView.text == parent.hint{
                textView.text = ""
                textView.textColor = UIColor(Color.primary)
                textView.textColor = .white
                
            }
        }
        
        // updating text in SwiftUI View...
        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
            parent.containerHeight = textView.contentSize.height
        }
        
        // On End checking if textbox is empty
        // if so then put hint..
        func textViewDidEndEditing(_ textView: UITextView) {
            if textView.text == ""{
                textView.text = parent.hint
                textView.textColor = .gray
            } else {
                textView.textColor = .white
            }
        }
    }
}



// Preference key to read the dynamic height
struct ViewHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}


struct CameraView: View {
    @ObservedObject var viewModel: CameraViewModel
    @State private var showSendButton = false
//    @State private var useUltraWideAngle: Bool = false
    
    @State private var zoomScale: CGFloat = 1.0
    @Binding var isShown: Bool
    @Environment(\.presentationMode) var presentationMode
    @State private var showTextField = false
    @FocusState private var isTextFieldFocused: Bool
    @State private var isFlashOn: Bool = false
    @State private var shouldUseFlash = false
    @State private var isButtonClicked: Bool = false
    @State private var showDeleteButton: Bool = false
    @State private var postCaption: String = ""
    @State private var isCaptionFieldActive: Bool = false
    @State private var cancellables = Set<AnyCancellable>()
    @ObservedObject var cameraService: CameraService
    @State private var capturedPhoto: UIImage? = nil
    
    @State private var secondCapturedPhoto: UIImage? = nil
    
    @State private var keyboardHeight: CGFloat = 0
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
    
    //    @StateObject var snapModel = SnapViewModel()
//    @State private var isTextEditingMode: Bool = false
//    @State private var showTextEditor: Bool = false
    @Binding var selectedTab: Int
    
    @State var lastFocusPressLocation: CGPoint?
    @State var isAnimatingFocus: Bool = false
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @Environment(\.scenePhase) var scenePhase
    @State private var showCheeseText = false
    @State private var countdown = 3
    @State private var showCountdown = false
    @State private var showFirstImage = true
    @State private var showSecondImageInLargerFrame = false
    @State private var showFirstImageInSmallFrame = true
    @State private var text: String = ""
    @State private var smallerFramePosition = CGSize.zero


    
    // Add selectedTab as a parameter to the initializer
    init(isShown: Binding<Bool>, cameraService: CameraService, selectedTab: Binding<Int>) {
            _isShown = isShown
            self.cameraService = cameraService
            _selectedTab = selectedTab // Correctly initialize the @Binding property
            self.viewModel = CameraViewModel(cameraService: cameraService)
        
        // Your existing code to listen for keyboard events and initialize viewModel
            self.keyboardHeightPublisher
            .assign(to: \.keyboardHeight, on: self)
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
                        if viewModel.capturedPhoto != nil {
                            if !isCaptionFieldActive {
                                ImagePreview(viewModel: self.viewModel)
//                                    .overlay(
//                                        TappableView { location in
//                                            cameraService.focus(at: CGPoint(x: location.y/UIScreen.main.bounds.height, y: location.x/UIScreen.main.bounds.width))
//                                            withAnimation {
//                                                //                                lastFocusPressLocation = location
//                                            }
//                                            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
//                                                lastFocusPressLocation = nil
//                                            }
//                                        } doubleTapCallback: { gesture in
//                                            cameraService.toggleFrontCamera()
//                                        }
//                                        pinchCallback: { gesture in
//                                            cameraService.onPinch(recognizer: gesture)
//                                        } longPressCallback: { gesture in
//                                            //do nothing
//                                        })
                            }
                        } else {
                            CameraPreview(cameraService: cameraService)
                                .overlay(
                                    TappableView { location in
                                        cameraService.focus(at: CGPoint(x: location.y/UIScreen.main.bounds.height, y: location.x/UIScreen.main.bounds.width))
                                        withAnimation {
                                            //                                lastFocusPressLocation = location
                                        }
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                            lastFocusPressLocation = nil
                                        }
                                    } doubleTapCallback: { gesture in
                                        cameraService.toggleFrontCamera()
                                    }
                                    pinchCallback: { gesture in
                                        cameraService.onPinch(recognizer: gesture)
                                    } longPressCallback: { gesture in
                                        //do nothing
                                    })
                        }
                    }
                    .cornerRadius(15.33333)
                    .clipped()

//                    CameraControlsContainer(viewModel: viewModel, isShown: $isShown, selectedTab: $selectedTab, cameraService: cameraService)
                    
                    
                    
                    VStack {
                        // Xmark Button at top leading
                        if viewModel.capturedPhoto != nil {
                            Button(action: {
                                // Log event for arrow left button
                                Analytics.logEvent("clicked_arrow_left", parameters: nil)
                                Haptics.shared.play(.light)

                                if showSendButton {
                                    
                                    
                                    
//                                    self.capturedPhoto = nil
//                                        self.secondCapturedPhoto = nil
//                                    viewModel.resetTakenImage()  // Reset CameraService and PhotoCaptureProcessor
//                                    self.capturedPhoto = nil
//                                    self.secondCapturedPhoto = nil
//                                    cameraService.stopSessionRunning()
                                    viewModel.onReset()
                                    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.1) {
                                        cameraService.resetCameraSession()
                                    }
                                    
//                                    viewModel.reset()
                                    
                                    showSendButton = false
                                } else {
                                    self.isShown = true
                                }
                            }) {
                                Image(systemName: "xmark")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: UIScreen.main.bounds.width * 0.05, height: UIScreen.main.bounds.width * 0.05)
                                    .foregroundColor(.white)
                                    .padding(20)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Spacer()

                        // HStack for Change Camera and Flash Buttons at bottom
                        HStack {
                            if !showSendButton {
                                // Change Camera Button at bottom leading
                                
                                
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
                                
                               
                                .frame(maxWidth: .infinity, alignment: .leading)

                                Spacer()

                                // Flash Button at bottom trailing
                                Button(action: {
                                    // Log event for flash button
                                    Analytics.logEvent("clicked_change_camera", parameters: nil)

                                    cameraService.toggleFrontCamera()
                                }) {
                                    Image(systemName: "arrow.triangle.2.circlepath.camera")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 40, height: 30)
                                        .padding()
                                        .foregroundColor(.white)
                                }
                                .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                        }
                        .padding()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    // Text Editing Icon

                    // Location Overlay View
                    .overlay(
                        LocationOverlayView(viewModel: viewModel),
                        alignment: .topTrailing
                    )
                    
                    

                    
                    

                    
                   
                    .overlay(
                        Group {
                            if showCountdown {
                                VStack {
                                    Text("\(countdown > 0 ? "\(countdown), " : "")ouistitiiiiiiiii 🙈 📸")
                                        .foregroundColor(.white)
                                    
//                                        .background(Color.black)
                                        .font(.headline)

//                                        .minimumScaleFactor(2)
                    //                    .lineLimit(1)  // Remove for multiline text
                                        .multilineTextAlignment(.center)
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle())
                                        .tint(.white)
                                }
                            }
                        }
                    )

     
                    
//                    VStack {
//                        Spacer()
                    
//                    if !showSendButton {
//                        Text(String(cameraService.zoomFactor == 1 ? 0.5 : cameraService.zoomFactor - 1).replacingOccurrences(of: ".0", with: ""))
//                                                  .foregroundColor(.white)
//                                                  .font(Font.system(size: 21, weight: .bold))
//                                                  .padding(.leading, 2.5)
//                  
//                                              Image(systemName:"xmark")
//                                                  .resizable()
//                                                  .frame(width: 8, height: 8)
//                                                  .padding(.leading, -4)
//                                          }
////                            .contentShape(Rectangle()).frame(width: 70, height: 30)
//                                      }
//                                  
//                              

                    
                
                    
                    
                    
                    VStack {
                        Spacer()
                        if !showSendButton {
                            Button(action: {
                                                               // Log event for capture button
                                                               Analytics.logEvent("clicked_capture", parameters: nil)
                                                               Haptics.shared.play(.light)

                                                               // Take the first picture
                                                               cameraService.capturePhoto()
                                                               self.showCheeseText = true

//                                                               // Store the captured photo
//                                                               if let data = cameraService.photo?.originalData, let uiImage = UIImage(data: data) {
//                                                                   capturedPhoto = uiImage  // <-- Store the captured image
//
//                                                               }

                                                               // After a delay of 4 seconds, take the second picture
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                                    cameraService.toggleFrontCamera()
                                    self.showCountdown = true
                                    
                                    Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
                                        if self.countdown > 0 {
                                            self.countdown -= 1
                                        } else {
                                            timer.invalidate()
                                            self.countdown = 2
                                            self.showCountdown = false
                                            cameraService.doublecapturePhoto()
                                            Haptics.shared.play(.light)
                                            
//                                            if let data = cameraService.photo?.originalData, let uiImage = UIImage(data: data) {
//                                                secondCapturedPhoto = uiImage
                                                showSendButton = true
//                                            }
                                            
                                        }
                                    }
                                }
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
                    }
                .alignmentGuide(.bottom) { $0[.bottom] }
                                       

                    
                    
                    ZStack {
                        if showSendButton {
                            
                            CaptionInputView(hint: "Écrire une légende...", text: $postCaption, dynamicHeight: $dynamicHeight, keyboardHeight: keyboardHeight)

                            
                        }
                    
                        
                        if showSendButton {
                            HStack {
                                
                                VStack {
                                    Spacer ()
                                    
                                    CirclePicker(viewModel: viewModel)
//                                    Haptics.shared.play(.light)
                                    
                                }
                                
                                Spacer()
                                
                                HStack {
                                    VStack {
                                        Spacer ()
                                        
                                        
                                        
                                        SendButton(selectedTab: $selectedTab, viewModel: viewModel, postCaption: $postCaption)
//

                                        
                                    }
                                    .offset(y: -keyboardHeight)
                                    .padding(.bottom, keyboardHeight)
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
            }
            

            
            .onAppear {
                cameraService.configure()
                self.observeKeyboardNotifications()

                

            }
            .onDisappear {
//                cameraService.stopSessionRunning()
                
                if showSendButton {
                    showSendButton = false
                } else {
                self.isShown = true
            }
                
                viewModel.onReset()
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.1) {
                    cameraService.resetCameraSession()
                }//                cameraService.configureInBackground()
//                self.stopTimer()
            }
            
            .onChange(of: viewModel.capturedImage, perform: { newImage in
                if newImage != nil /*&& greenScreenActive*/ {
    //                runVisionRequest()
                }
            })
            .onChange(of: viewModel.secondCapturedPhoto, perform: { newImage in
                if newImage != nil /*&& greenScreenActive*/ {
    //                runVisionRequest()
                }
            })
            .onChange(of: scenePhase, perform: { newPhase in
                if newPhase == .active {
                    cameraService.configureInBackground()
                }
            })
    //        .on


     
            .navigationBarBackButtonHidden(true)

        }
        
        .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
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


extension CameraView {
    
    func observeKeyboardNotifications() {
        NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { notif in
            if let value = notif.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue {
                let height = value.cgRectValue.height
                self.keyboardHeight = height
            }
        }
        NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { _ in
            self.keyboardHeight = 0
        }
    }
}


struct LocationButtonView: View {
    @Binding var isLocationEnabled: Bool
    var locationString: String
    var action: () -> Void  // Accept an action closure
    
    var body: some View {
        Button(action: action) { // Use the action closure here
            HStack {
                Image(systemName: isLocationEnabled ? "location.fill" : "location.slash.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 15, height: 15)
                if !locationString.isEmpty && isLocationEnabled {
                    Text(locationString)
                        .foregroundColor(.white)
                        .font(.footnote)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .frame(height: 30)
            .padding(.horizontal, locationString.isEmpty ? 10 : 5)
            .background(Color.black.opacity(0.7))
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 15))
        }
    }
}



struct CaptionInputView: View {
    var hint: String
    @Binding var text: String
    @Binding var dynamicHeight: CGFloat
    var keyboardHeight: CGFloat
    
    var body: some View {
        VStack {
            
            Spacer()
            
            AutoSizingTF(
                hint: NSLocalizedString("Écrire une légende...", comment: "Hint for writing a caption"),
                text: $text,
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
}

struct CirclePicker: View {
    @ObservedObject var viewModel: CameraViewModel

    var body: some View {


            Picker(selection: $viewModel.selectedCircle, label: Text("")) {
                ForEach(viewModel.distributionCircles, id: \.self) { circle in
                    Text(NSLocalizedString(circle, comment: circle))
                        .tag(circle)
                }
            }
            .onChange(of: viewModel.selectedCircle) { newValue in
                Analytics.logEvent("clicked_circle_picker", parameters: [
                    "selected_circle": newValue
                ])
            }
            .pickerStyle(MenuPickerStyle())
            .foregroundColor(.white)
            .padding(.leading)
            .offset(y: -15)
        }
    }

struct SendButton: View {
    @State private var isButtonClicked = false
    @Binding var selectedTab: Int
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var viewModel: CameraViewModel
    @Binding var postCaption: String // Add this line
    @State private var cancellables = Set<AnyCancellable>()

    var body: some View {
        Button(action: {
            Analytics.logEvent("clicked_send", parameters: nil)

            if !isButtonClicked {
                // Immediately redirect to FeedView and dismiss CameraView
                self.selectedTab = 0  // Assuming FeedView is at index 0
                self.presentationMode.wrappedValue.dismiss()


                if let uiImage = viewModel.capturedPhoto, let imageData = uiImage.jpegData(compressionQuality: 0.7) {
                    if let UiImage = viewModel.secondCapturedPhoto, let secondImageData = UiImage.jpegData(compressionQuality: 0.7) {
                        

                        viewModel.sendPost(imageData: imageData, secondImageData: secondImageData, postCaption: postCaption, selectedCircle: viewModel.selectedCircle)
                            .sink(receiveCompletion: { completion in
                                switch completion {
                                case .finished:
                                    print("Post uploaded successfully.")
                                case .failure(let error):
                                    print("Failed to upload post: \(error)")
                                }
                            }, receiveValue: {})
                            .store(in: &cancellables)
                    } else {
                        viewModel.sendPost(imageData: imageData, secondImageData: nil, postCaption: postCaption, selectedCircle: viewModel.selectedCircle)
                            .sink(receiveCompletion: { completion in
                                switch completion {
                                case .finished:
                                    
//                                    viewModel.onReset()
//                                    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.1) {
//                                        viewModel.cameraService.resetCameraSession()
//                                    }

                                    print("Post uploaded successfully.")
                                case .failure(let error):
                                    print("Failed to upload post: \(error)")
                                }
                            }, receiveValue: {})
                            .store(in: &cancellables)
                    }
                }
                
            }
        }) {
            Image(systemName: "arrow.right.circle.fill")
                .resizable()
                .frame(width: 45, height: 45)
                .padding()
                .foregroundColor(.white)
        }
        .padding(.trailing, 20)
        .offset(y: +8)
        .disabled(isButtonClicked)
    }
}


//struct CaptureButton: View {
//    @ObservedObject var cameraService: CameraService
//    @State private var showCheeseText = false
//    @State private var countdown = 2
//    @State private var showCountdown = false
//    @State private var capturedPhoto: UIImage?
//    @State private var secondCapturedPhoto: UIImage?
//    @State private var showSendButton = false
//
//    var body: some View {
//        Button(action: {
//            // Log event for capture button
//            Analytics.logEvent("clicked_capture", parameters: nil)
//            Haptics.shared.play(.light)
//
//            // Take the first picture
//            cameraService.capturePhoto()
//            self.showCheeseText = true
//
//            // Store the captured photo
//            if let data = cameraService.photo?.originalData, let uiImage = UIImage(data: data) {
//                capturedPhoto = uiImage  // <-- Store the captured image
//            }
//
//            // After a delay of 4 seconds, take the second picture
//            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
//                self.showCountdown = true
//
//                Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
//                    if self.countdown > 0 {
//                        self.countdown -= 1
//                    } else {
//                        timer.invalidate()
//                        self.countdown = 2
//                        self.showCountdown = false
////                                                cameraService.toggleFrontCamera()
//                        cameraService.doublecapturePhoto()
//                        Haptics.shared.play(.light)
//
//                        if let data = cameraService.photo?.originalData, let uiImage = UIImage(data: data) {
//                            secondCapturedPhoto = uiImage
//                            showSendButton = true
//                        }
//                    }
//                }
//            }
//        }) {
//            Circle()
//                .frame(width: 60, height: 60)
//                .foregroundColor(.clear)
//                .overlay(
//                    Circle()
//                        .stroke(Color.white, lineWidth: UIScreen.main.bounds.width * 0.015)
//                )
//        }
//        .alignmentGuide(.bottom) { $0[.bottom] }
//        .alignmentGuide(.trailing) { $0[.trailing] }
//        .offset(y: -15)
//    }
//
//    class Haptics {
//        static let shared = Haptics()
//
//        private init() { }
//
//        func play(_ feedbackStyle: UIImpactFeedbackGenerator.FeedbackStyle) {
//            UIImpactFeedbackGenerator(style: feedbackStyle).impactOccurred()
//        }
//
//        func notify(_ feedbackType: UINotificationFeedbackGenerator.FeedbackType) {
//            UINotificationFeedbackGenerator().notificationOccurred(feedbackType)
//        }
//    }
//
//}




struct LocationOverlayView: View {
    @ObservedObject var viewModel: CameraViewModel
    
    var body: some View {
        Group {
            if viewModel.capturedPhoto != nil {
                LocationButtonView(
                isLocationEnabled: $viewModel.isLocationEnabled,
                locationString: viewModel.locationString,
                action: {
                    // This closure is executed when the location button is tapped.
                    viewModel.toggleLocationEnabled()
                    
                    if viewModel.isLocationEnabled {
                        LocationManager.shared.requestAuthorization()
                        LocationManager.shared.onAuthorizationChange = { authorized in
                            DispatchQueue.main.async {
                                if authorized {
                                    LocationManager.shared.startFetchingLocation()
                                } else {
                                    // Handle the scenario when location access is denied.
                                    viewModel.isLocationEnabled = false
                                    // Potentially show an alert or guide the user to enable location services through settings.
                                }
                            }
                        }
                        
                        LocationManager.shared.onLocationFetch = { location in
                            DispatchQueue.main.async {
                                viewModel.setLocation(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
                            }
                        }
                    } else {
                        // If the location is disabled, clear any existing location data.
                        viewModel.locationString = ""
                        viewModel.locationData = nil
                    }
                }
                
                )
            } else {
                EmptyView()
            }
        }
    }
}


struct ImagePreview: View {
    @ObservedObject var viewModel: CameraViewModel
    @State private var showSecondImageInLargerFrame = false
    @State private var showFirstImageInSmallFrame = true
    @State private var smallerFrameOffset = CGSize.zero
    var image: UIImage?
        var secondImage: UIImage?
    
    mutating func resetImages() {
            image = nil
            secondImage = nil
        }

    var body: some View {
        ZStack {
            if let capturedImage = self.viewModel.capturedPhoto {
                Image(uiImage: capturedImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: UIScreen.main.bounds.width * 1, height: UIScreen.main.bounds.height * 0.84)
                    .clipped()

                if let secondCapturedPhoto = self.viewModel.secondCapturedPhoto {
                    Image(uiImage: secondCapturedPhoto)
                        .resizable()
                        .scaledToFill()
                        .frame(width: UIScreen.main.bounds.width / 2, height: UIScreen.main.bounds.height / 3)
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.white, lineWidth: 2))
                        .padding(5)
                        .position(x: UIScreen.main.bounds.width - (UIScreen.main.bounds.width / 4) - 20 + smallerFrameOffset.width, y: UIScreen.main.bounds.height / 6 + smallerFrameOffset.height)

                }
            }
        }
    }
}

//}
//}




//struct CameraControlsContainer: View {
//    @ObservedObject var viewModel: CameraViewModel
//    @Binding var isShown: Bool
//    @Binding var selectedTab: Int
//    @State private var showSendButton = false
//    @State private var shouldUseFlash = false
//    @ObservedObject var cameraService: CameraService
//
//    var body: some View {
//        VStack {
//            // Xmark Button at top leading
//            if viewModel.capturedPhoto != nil {
//                Button(action: {
//                    // Log event for arrow left button
//                    Analytics.logEvent("clicked_arrow_left", parameters: nil)
//                    Haptics.shared.play(.light)
//
//                    if showSendButton {
//                        viewModel.resetTakenImage()  // Reset CameraService and PhotoCaptureProcessor
//                        showSendButton = false
//                    } else {
//                        self.isShown = true
//                    }
//                }) {
//                    Image(systemName: "xmark")
//                        .resizable()
//                        .aspectRatio(contentMode: .fit)
//                        .frame(width: UIScreen.main.bounds.width * 0.05, height: UIScreen.main.bounds.width * 0.05)
//                        .foregroundColor(.white)
//                        .padding(20)
//                }
//                .frame(maxWidth: .infinity, alignment: .leading)
//            }
//
//            Spacer()
//
//            // HStack for Change Camera and Flash Buttons at bottom
//            HStack {
//                if !showSendButton {
//                    // Change Camera Button at bottom leading
//
//
//                    Button(action: {
//                        // Flash Button at bottom trailing
//                        Analytics.logEvent("clicked_flash", parameters: ["is_flash_on": shouldUseFlash])
//                        cameraService.setFlashMode(shouldUseFlash ? .on : .off)
//                        Haptics.shared.play(.light)
//                    }) {
//                        Image(systemName: shouldUseFlash ? "bolt.fill" : "bolt.slash.fill")
//                            .resizable()
//                            .aspectRatio(contentMode: .fit)
//                            .frame(width: 35, height: 35)
//                            .foregroundColor(.white)
//                            .padding(20)
//                    }
//
//                    .frame(maxWidth: .infinity, alignment: .leading)
//
//                    Spacer()
//
//                    // Flash Button at bottom trailing
//                    Button(action: {
//                        // Log event for flash button
//                        Analytics.logEvent("clicked_change_camera", parameters: nil)
//
//                        cameraService.toggleFrontCamera()
//                    }) {
//                        Image(systemName: "arrow.triangle.2.circlepath.camera")
//                            .resizable()
//                            .aspectRatio(contentMode: .fit)
//                            .frame(width: 40, height: 30)
//                            .padding()
//                            .foregroundColor(.white)
//                    }
//                    .frame(maxWidth: .infinity, alignment: .trailing)
//                }
//            }
//            .padding()
//        }
//        .frame(maxWidth: .infinity, maxHeight: .infinity)
//        .ignoresSafeArea()
//    }
//
//
//
//        class Haptics {
//            static let shared = Haptics()
//
//            private init() { }
//
//            func play(_ feedbackStyle: UIImpactFeedbackGenerator.FeedbackStyle) {
//                UIImpactFeedbackGenerator(style: feedbackStyle).impactOccurred()
//            }
//
//            func notify(_ feedbackType: UINotificationFeedbackGenerator.FeedbackType) {
//                UINotificationFeedbackGenerator().notificationOccurred(feedbackType)
//            }
//        }
//
//}


//}
//}



struct KeyboardResponsiveModifier: ViewModifier {
    @State private var offset: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .padding(.bottom, offset)
            .onAppear {
                NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { notification in
                    let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect)?.height ?? 0
                    // Adjust the offset here depending on the rest of your UI
                    offset = keyboardSize
                }

                NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { _ in
                    offset = 0
                }
            }
    }
}


struct TappableView: UIViewRepresentable
{
    var tapCallback: (CGPoint) -> Void
    var doubleTapCallback: (UITapGestureRecognizer) -> Void
    var pinchCallback: (UIPinchGestureRecognizer) -> Void
    var longPressCallback: (UILongPressGestureRecognizer) -> Void

    typealias UIViewType = UIView

    func makeCoordinator() -> TappableView.Coordinator
    {
        Coordinator(tapCallback: self.tapCallback, doubleTapCallback: self.doubleTapCallback, pinchCallback: self.pinchCallback, longPressCallback: self.longPressCallback)
    }

    func makeUIView(context: UIViewRepresentableContext<TappableView>) -> UIView
    {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height))

        let pinchGesture = UIPinchGestureRecognizer(target: context.coordinator, action:
                                                        #selector(Coordinator.handlePinch(gesture:)))

        view.addGestureRecognizer(pinchGesture)

        let doubleTapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDoubleTap(gesture:)))
        doubleTapGesture.numberOfTapsRequired = 2
        doubleTapGesture.require(toFail: pinchGesture)

        let longPressGesture = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleLongPress(gesture:)))

        longPressGesture.minimumPressDuration = 0.2
        view.addGestureRecognizer(longPressGesture)

        let singleTapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(gesture:)))
        singleTapGesture.numberOfTapsRequired = 1
        singleTapGesture.require(toFail: longPressGesture)
        view.addGestureRecognizer(singleTapGesture)

        view.addGestureRecognizer(doubleTapGesture)

        return view
    }

    func updateUIView(_ uiView: UIView, context: UIViewRepresentableContext<TappableView>)
         {
    }

    class Coordinator {
        var tapCallback: (CGPoint) -> Void
        var doubleTapCallback: (UITapGestureRecognizer) -> Void
        var pinchCallback: (UIPinchGestureRecognizer) -> Void
        var longPressCallback: (UILongPressGestureRecognizer) -> Void

        init(tapCallback: @escaping (CGPoint) -> Void, doubleTapCallback: @escaping (UITapGestureRecognizer) -> Void, pinchCallback: @escaping (UIPinchGestureRecognizer) -> Void, longPressCallback: @escaping (UILongPressGestureRecognizer) -> Void) {
            self.tapCallback = tapCallback
            self.doubleTapCallback = doubleTapCallback
            self.pinchCallback = pinchCallback
            self.longPressCallback = longPressCallback
        }

        @objc func handleTap(gesture: UITapGestureRecognizer) {
            let point = gesture.location(in: gesture.view)
            self.tapCallback(point)
        }

        @objc func handlePinch(gesture: UIPinchGestureRecognizer) {
            self.pinchCallback(gesture)
        }

        @objc func handleDoubleTap(gesture: UITapGestureRecognizer) {
            self.doubleTapCallback(gesture)
        }

        @objc func handleLongPress(gesture: UILongPressGestureRecognizer) {
            self.longPressCallback(gesture)
        }
    }
}




/*
#if DEBUG
import SwiftUI

struct CameraView_Previews: PreviewProvider {
    static var previews: some View {
        CameraView(isShown: .constant(true), cameraService: CameraService())
    }
}
#endif
*/
