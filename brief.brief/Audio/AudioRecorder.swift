//
//  AudioRecorder.swift
//  brief.brief
//
//  Created by Philippe Tchinda on 20/10/2023.
//

import Foundation
import AVFoundation
import Combine

class AudioRecorder: NSObject, ObservableObject {
    var audioRecorder: AVAudioRecorder?
    
    @Published var isRecording = false
    @Published var recordingURL: URL?
    
    // Start Recording
    func startRecording() {
        let recordingSession = AVAudioSession.sharedInstance()
        
        do {
            try recordingSession.setCategory(.playAndRecord, mode: .default)
            try recordingSession.setActive(true)
        } catch {
            print("Failed to set up recording session")
        }
        
        let tempDirectory = FileManager.default.temporaryDirectory
        let recordingFileURL = tempDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("m4a")
        recordingURL = recordingFileURL
        
        let settings = [AVFormatIDKey: Int(kAudioFormatMPEG4AAC), AVSampleRateKey: 12000, AVNumberOfChannelsKey: 1, AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue]
        
        do {
            audioRecorder = try AVAudioRecorder(url: recordingFileURL, settings: settings)
            audioRecorder?.record()
            isRecording = true
        } catch {
            print("Could not start recording")
        }
    }
    
    func deleteRecording(at url: URL) {
           do {
               try FileManager.default.removeItem(at: url)
               print("Successfully deleted the recording.")
           } catch {
               print("Could not delete the recording: \(error)")
           }
       }
   
    
    // Stop Recording
    func stopRecording() {
        audioRecorder?.stop()
        isRecording = false
    }
}
