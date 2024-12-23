//
//  AudioVisualization.swift
//  brief.brief
//
//  Created by Philippe Tchinda on 22/12/2023.
//

import SwiftUI

// MARK: - Audio Visualization Main View

struct AudioVisualization: View {
    @StateObject private var audioVM: AudioPlayViewModel
    let audioURL: URL
    @State var overlayOpacity: Double = 0.0
    private let sidePadding: CGFloat = 16


    init(audioURL: URL) {
        self.audioURL = audioURL
        // Initialize your audio view model here. Adjust the sample_count based on your needs.
        _audioVM = StateObject(wrappedValue: AudioPlayViewModel(sample_count: Int(UIScreen.main.bounds.width / 30)))

    }
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack(alignment: .center, spacing: 4) {
                playPauseButton
                

                
                // Use a conditional check to either show a progress view or the audio visualization
                if audioVM.soundSamples.isEmpty {
                    ProgressView()
                } else {
                    audioVisualization
                }

            }
            
         /*   VStack(alignment: .leading) {
                Spacer()
                
                Text("\(formatTimeInterval(interval: audioVM.displayedTime))/\(formatTimeInterval(interval: audioVM.player?.duration ?? 0))")
                    .font(.footnote)
                    .foregroundColor(.gray)
            }*/

            .padding(.vertical, 14)
            .padding(.horizontal)
            .background(Color.gray.opacity(0.3).cornerRadius(10))
            .frame(height: 50) // Ensures the VStack has a consistent height
        }
        

        .onAppear {
            audioVM.loadAudio(url: audioURL) // Preload the audio
        }
    }

    private var playPauseButton: some View {
        Button(action: {
            self.handlePlayPauseAction()
        }) {
            Image(systemName: audioVM.isPlaying ? "pause.fill" : "play.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 16, height: 16)
                .foregroundColor(.black)
        }
    }


    private var audioVisualization: some View {
        HStack(alignment: .center, spacing: 2) {
            ForEach(audioVM.soundSamples, id: \.self) { model in
                BarView(value: self.normalizeSoundLevel(level: model.magnitude), color: model.hasPlayed ? .blue : .green.opacity(0.3))
                    .frame(width: 4) // Increase the width of each bar to extend the horizontal span
            }
        }
    }

    private func normalizeSoundLevel(level: Float) -> CGFloat {
        let level = max(0.2, CGFloat(level) + 70) / 2 // between 0.1 and 35
        return CGFloat(level * (40 / 35))
    }


    private func fetchAndPlayAudio(from url: URL) {
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let data = data {
                DispatchQueue.main.async {
                    audioVM.initializePlayer(with: data)
                    Service.shared.buffer(data: data, id: UUID().uuidString, samplesCount: 20) { samples in
                        self.audioVM.soundSamples = samples
                    }
                }
            }
            // Handle errors as necessary
        }.resume()
    }

    // MARK: - Private Helpers

    /// Handles the play/pause action.
    // Modify the play/pause action to pass the URL.
    private func handlePlayPauseAction() {
        if audioVM.isPlaying {
            audioVM.pauseAudio()
        } else {
            audioVM.playAudio()
        }
    }


    /// Modifies the overlay opacity based on the audio's play status.
    private func handleOverlayOpacityChange(_ isPlaying: Bool) {
        if isPlaying {
            // Introduce a delay before starting the fade-in animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.easeOut(duration: 1.0)) {
                    overlayOpacity = 1.0
                }
            }
        } else {
            withAnimation(.easeOut(duration: 0.2)) {
                overlayOpacity = 0.0
            }
        }
    }

    
    /// Content of the player's control button.
    private var playerControlContent: some View {
        ZStack(alignment: .center) {
            HStack {
                Image(systemName: audioVM.isPlaying ? "pause.fill" : "play.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 24, height: 24)
                    .foregroundColor(.pink)


                if audioVM.isPlaying || (!audioVM.isPlaying && (audioVM.player?.currentTime ?? 0) != 0.0) {
                    Spacer()
                }

//                ZStack(alignment: .leading) {
////                    Text(formatTimeInterval(interval: audioVM.displayedTime))
//                        .font(.caption) // Replace with your preferred font size/style
//                        .foregroundColor(Color.white) // Make sure this color is defined in your `Color` extension
//                        .opacity(0.0) // If you want to hide/show the text based on some condition
//                }
//                .frame(width: 48)
//                .padding(.trailing, 16)
            }

            HStack(spacing: 0) {
                           ForEach(audioVM.soundSamples, id: \.self) { model in
                               BarView(value: normalizeSoundLevel(level: model.magnitude),
                                       color: model.hasPlayed ? .blue : .green.opacity(0.3))
                                   .frame(width: barWidth, height: normalizeSoundLevel(level: model.magnitude)) // Use the computed property here
                           }
                       }
                       .frame(maxWidth: .infinity) // Stretch to the full width of the parent
                       .clipped()
                       .offset(x: -16)
                       .opacity(overlayOpacity)
                   }
                   .background(.gray)
                   .clipShape(RoundedRectangle(cornerRadius: 14.0))
               }
    
    private var barWidth: CGFloat {
           let totalBars = CGFloat(audioVM.soundSamples.count)
           let totalSpacing = totalBars - 1 // One less spacing than the number of bars
           let availableWidth = UIScreen.main.bounds.width - (totalSpacing + sidePadding * 2) // Adjust for padding on the sides
           return availableWidth / totalBars
       }



    /// Formats a time interval to mm:ss
//    private func formatTimeInterval(interval: TimeInterval) -> String {
//        let duration: Duration = .seconds(interval)
//        return duration.formatted(.time(pattern: .minuteSecond(padMinuteToLength: 2))) // "02:06"
//    }
}

// MARK: - BarView Component

struct BarView: View {
    let value: CGFloat
    var color: Color = .yellow

    var body: some View {
        Rectangle()
            .fill(color)
            .cornerRadius(10)
            .frame(width: 5, height: value)
            .animation(.easeInOut(duration: 1.0), value: value) // Correct usage
    }
}


 /*   struct AudioVisualization_Previews: PreviewProvider {
    static var previews: some View {
        AudioVisualization(data: Data(), id: "audioID")
            .previewLayout(.sizeThatFits)
    }
}
*/



extension Animation {
    static func bouncy(extraBounce: Double) -> Animation {
        return Animation.interpolatingSpring(stiffness: 100, damping: extraBounce)
    }
}

struct SquishySizelessButton: ButtonStyle {
    var color: Color
    var goalColor: Color
    var cornerRadius: CGFloat
    
    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .padding()
            .background(color)
            .cornerRadius(cornerRadius)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .foregroundColor(goalColor)
            .animation(.spring())
    }
}
