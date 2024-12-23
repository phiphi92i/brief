//
//  RecorderBar.swift
//  brief.brief
//
//  Created by Philippe Tchinda on 23/12/2023.
//

import SwiftUI

struct RecorderBar: View {
    @ObservedObject var audioRecorder = AudioRecorder()
    @ObservedObject var audioPlayer: AudioPlayer
    var onRecordingComplete: (URL?) -> Void  // Add this line

    
    @State var buttonSize: CGFloat = 1
    
    var repeatingAnimation: Animation {
        Animation.linear(duration: 0.5)
        .repeatForever()
    }
    
    // Create a date components formatter
    private var timeFormatter: DateComponentsFormatter {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return formatter
    }
    
    var body: some View {
        VStack {
            
            if let audioRecorder = audioRecorder.audioRecorder, audioRecorder.isRecording {
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    // recording duration
                    Text(timeFormatter.string(from: TimeInterval(audioRecorder.currentTime)) ?? "0:00")
                        .font(.title3)
                        .fontWeight(.semibold)
                }
                .transition(.scale)
            }
            
            recordButton
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .center)
    }
    
    var recordButton: some View {
        Button {
            if audioRecorder.isRecording {
                stopRecording()
            } else {
                startRecording()
            }
        } label: {
            Image(systemName: audioRecorder.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 65, height: 65)
                .clipped()
                .foregroundColor(.red)
                .scaleEffect(buttonSize)
                .onChange(of: audioRecorder.isRecording) { isRecording in
                    if isRecording {
                        withAnimation(repeatingAnimation) { buttonSize = 1.1 }
                    } else {
                        withAnimation { buttonSize = 1 }
                    }
                }
        }
    }
    
    func startRecording() {
        if audioPlayer.audioPlayer?.isPlaying ?? false {
            // stop any playing recordings
            audioPlayer.stopPlayback()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                // Start Recording
                audioRecorder.startRecording()
            }
        } else {
            // Start Recording
            audioRecorder.startRecording()
        }
    }
    
    func stopRecording() {
        // Stop Recording
        audioRecorder.stopRecording()
        onRecordingComplete(audioRecorder.recordingURL)  // Pass the recording URL

    }
    
}

/*struct RecorderBar_Previews: PreviewProvider {
 static var previews: some View {
 RecorderBar(audioPlayer: AudioPlayer())
 }
 }
 */
