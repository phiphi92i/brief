//
//  PlayerBar.swift
//  brief.brief
//
//  Created by Philippe Tchinda on 01/11/2023.
//

import SwiftUI

struct VoiceRecordButton: View {
    @EnvironmentObject var audioRecorder: AudioRecorder
    @StateObject var audioPlayer = AudioPlayer()
    @State private var showRecorderBar = false

    var onVoiceRecordComplete: ((URL?) -> Void)? // Add this optional closure

    var body: some View {
        Button(action: {
            showRecorderBar = true
        }) {
            Image(systemName: "mic.fill")
                .foregroundColor(.black)
                .padding(10)
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showRecorderBar) {
            RecorderBar(audioRecorder: audioRecorder, audioPlayer: audioPlayer, onRecordingComplete: { url in
                showRecorderBar = false
                onVoiceRecordComplete?(url)  // Call the completion handler
            })
        }
    }
}
