//
//  WritePostView.swift
//  brief.brief
//
//  Created by Philippe Tchinda on 04/06/2023.
//

import SwiftUI
import Combine
import SDWebImageSwiftUI
import FirebaseAnalytics
import MapKit


struct WritePostView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject var viewModel = WritePostViewModel() 
    private let maxCharacters = 350
    @EnvironmentObject var friendsData: FriendsData
    @State private var cancellables = Set<AnyCancellable>()
    @StateObject private var audioRecorder = AudioRecorder()
    @State private var showRecorderBar = false
    @StateObject var audioPlayer = AudioPlayer()
    var onVoiceRecordComplete: (URL?) -> Void
    @State private var showingRecorderBar = false // State to control the presentation of the RecorderBar
    @State private var showingLocationSheet = false
    @State private var showingLocationDeniedAlert = false
//    @State private var selectedTrack: SpotifyTrack? = nil // New state variable for selected track
//    @State private var showingSpotifySearchView = false

    
    
    
    var body: some View {
        ZStack {
            Color(.white)
                .edgesIgnoringSafeArea(.all)
            
            VStack {
                
                HStack {
                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
                        Text(NSLocalizedString("Annuler", comment: "S"))
                            .foregroundColor(.black)
                            .padding([.top, .leading])
                    }
                    
                    Spacer()
                    
                    Text("\(viewModel.postContent.count)/\(maxCharacters)")
                        .foregroundColor(viewModel.postContent.count > maxCharacters ? .red : .black)
                        .padding([.top, .trailing])
                }
                
                Divider().background(Color.gray)
                
                VStack {
                    
                    HStack {
                        if let imageUrl = URL(string: viewModel.profileImageUrl), viewModel.profileImageUrl != "" {
                            WebImage(url: imageUrl)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 35, height: 35)
                                .clipShape(Circle())
                                .padding(.leading)
                        } else {
                            Text(String(viewModel.username.prefix(1)).uppercased())
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .frame(width: 35, height: 35)
                                .background(Color.gray)
                                .clipShape(Circle())
                                .foregroundColor(.white)
                                .padding(.leading)
                        }

                        Text(viewModel.username)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.black)

                        Spacer() // This pushes everything to the left and right accordingly

                        // Moved the location button here, next to the username but aligned to the trailing edge.
                        Button(action: {
                            self.viewModel.toggleLocationEnabled()
                            LocationManager.shared.onAuthorizationChange = { authorized in
                                DispatchQueue.main.async {
                                    if !authorized {
                                        self.showingLocationDeniedAlert = true
                                    }
                                }
                            }
                            LocationManager.shared.onLocationFetch = { location in
                                DispatchQueue.main.async {
                                    self.viewModel.setLocation(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
                                }
                            }
                            LocationManager.shared.requestAuthorization()
                        }) {
                            HStack {
                                Image(systemName: viewModel.isLocationEnabled ? "location.fill" : "location.slash.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 15, height: 15)
                                if !viewModel.locationString.isEmpty && viewModel.isLocationEnabled {
                                    Text(viewModel.locationString)
                                        .foregroundColor(.black)
                                        .font(.footnote)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                }
                            }
                            .frame(height: 30)
                            .padding(.horizontal, viewModel.locationString.isEmpty ? 10 : 5)
                            .background(.ultraThickMaterial)
                            .foregroundColor(.black)
                            .clipShape(RoundedRectangle(cornerRadius: 15))
                        }
                        .padding(.trailing)
                    }
                    .padding(.top)
                    
                    

                    

                    ZStack(alignment: .topLeading) {
                        
                        
                        TextEditor(text: $viewModel.postContent)
                            .foregroundColor(viewModel.postContent.isEmpty ? .gray : .black)
                            .font(.custom("AvenirNext-Medium", size: 15))
                            .padding(4)
                            .onAppear {
                                // Set the TextEditor's placeholder text color to gray
                                UITextView.appearance().tintColor = .gray
                            }
                            .onChange(of: viewModel.postContent) { newValue in
                                if newValue.count > maxCharacters {
                                    viewModel.postContent = String(newValue.prefix(maxCharacters))
                                }
                            }
                    

                        
                        
                        
                        if let audioURL = viewModel.audioURL {
                            VStack {
                                Spacer()
                                
                                HStack {
                                    Spacer()
                                    
                                    AudioVisualization(audioURL: audioURL)
                                    Button(action: {
                                        // Delete the audio
                                        self.viewModel.audioURL = nil
                                        self.audioPlayer.stopPlayback()
                                    }) {
                                        Image(systemName: "trash")
                                            .resizable()
                                            .frame(width: 20, height: 20)
                                            .foregroundColor(.red)
                                    }
                                }
                                .padding()
                            }
                        }
                    }
                    
                    .frame(maxHeight: .infinity)
                    
       
                    
                    
                    HStack {
                        Picker(selection: $viewModel.selectedCircle, label: Text("")) {
                            ForEach(viewModel.distributionCircles, id: \.self) { circle in
                                Text(circle == "All My Friends" ? NSLocalizedString("All My Friends", comment: "All My Friends") : circle)
                                    .tag(circle)
                                    .padding()
                                    .background(Color.gray)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .foregroundColor(.white)
                        .padding(.leading)
                        
                        

                        
                        Spacer()
                        

                        
                        // Microphone Button next to the Picker
                        Button(action: {
                            showingRecorderBar = true // Show the recorder bar or start recording
                        }) {
                            Image(systemName: "mic.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 20, height: 20)
                                .padding(10)
                                .background(.ultraThickMaterial)
                                .foregroundColor(.black)
                                .clipShape(Circle())
                        }
                        .padding(.leading)
//                        .offset(x: -140, y: -60)
                        .sheet(isPresented: $showingRecorderBar) {
                            RecorderBar(audioRecorder: AudioRecorder(), audioPlayer: audioPlayer, onRecordingComplete: { url in
                                showingRecorderBar = false
                                onVoiceRecordComplete(url)
                                self.viewModel.audioURL = url
                            })
                        }
                    
//                        
//                        Button(action: {
//                            // Toggle the state to show SpotifySearchView
//                            showingSpotifySearchView = true
//                        }) {
//                            Image(systemName: "music.note.list")
//                                .resizable()
//                                .scaledToFit()
//                                .frame(width: 20, height: 20)
//                                .padding(10)
//                                .background(.ultraThickMaterial)
//                                .foregroundColor(.black)
//                                .clipShape(Circle())
//                        }
//                        .padding(.leading)
//                        
//                        .sheet(isPresented: $showingSpotifySearchView) {
//                            SpotifySearchView()
//                        }
//
//
//                        
                        Button(action: sendPostAction) {
                            Image(systemName: "paperplane.fill")
                                .resizable()
                                .foregroundColor(.white)
                                .frame(width: 20, height: 20)
                                .padding()
                                .background(Color(red: 0.07, green: 0.04, blue: 1))
                                .clipShape(Circle())
                        }
                        .padding(.trailing)
                    }
                    
                    
                }
            }
        }
        .alert(isPresented: $showingLocationDeniedAlert) {
            Alert(
                title: Text("Location Permission Denied"),
                message: Text("Please enable location services in settings."),
                dismissButton: .default(Text("Open Settings")) {
                    // Open the settings app
                    if let url = URL(string: UIApplication.openSettingsURLString), UIApplication.shared.canOpenURL(url) {
                        UIApplication.shared.open(url)
                    }
                }
            )
        }
        .onAppear {
            viewModel.fetchProfileImageAndUsername()
            viewModel.fetchDistributionCircles()
            viewModel.fetchDistributionCircles()
            LocationManager.shared.requestLocation()
                        LocationManager.shared.onLocationFetch = { location in
                            DispatchQueue.main.async {
                                viewModel.setLocation(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
                            }
                        }
        }
        .preferredColorScheme(.light)
    }
    
    
    private func sendPostAction() {
        viewModel.sendPost(
            selectedCircle: viewModel.selectedCircle,
            username: viewModel.username,
            profileImageUrl: viewModel.profileImageUrl,
            postContent: viewModel.postContent,
            audioRecordingURL: viewModel.audioURL
        )
        .sink(
            receiveCompletion: { completion in
                switch completion {
                case .finished:
                    print("Post uploaded successfully.")
                case .failure(let error):
                    print("Failed to upload post: \(error)")
                }
            },
            receiveValue: {}
        )
        .store(in: &cancellables)
        
        presentationMode.wrappedValue.dismiss()
    }
}

struct LocationSelectionSheet: View {
    @Binding var isPresented: Bool
    @ObservedObject var viewModel: WritePostViewModel // Change to ObservedObject if you need to listen for changes

    var body: some View {
        VStack {
            if let locationData = viewModel.locationData {
                Text("Current Location: \(locationData.latitude), \(locationData.longitude)")
                // Optionally, display the reverse geocoded location string
                if !viewModel.locationString.isEmpty {
                    Text("Location: \(viewModel.locationString)")
                }
            } else {
                Text("Fetching location...")
            }

            Button("Confirm Location") {
                // Confirm and use the selected location
                viewModel.toggleLocationEnabled() // This would update the UI and possibly other parts of your data model
                isPresented = false
            }
            .padding()
        }
    }
}


/*struct WritePostView_Previews: PreviewProvider {
 static var previews: some View {
 WritePostView()
 }
 }
 */


