//
//  AudioPlayViewModel.swift
//  brief.brief
//
//  Created by Philippe Tchinda on 22/12/2023.
//

import AVFoundation
import AVKit
import Combine
import Foundation
import SwiftUI

class AudioPlayViewModel: NSObject, ObservableObject, AVAudioPlayerDelegate {
    // MARK: - Published Properties
    @Published var isPlaying: Bool = false
    @Published public var soundSamples = [AudioPreviewModel]()
    @Published var displayedTime: TimeInterval = 0.0
    @Published var player: AVAudioPlayer?
    @Published var session: AVAudioSession!
    
    // MARK: - Private Properties
    private var timer: Timer?
    private var time_interval: TimeInterval = 0.0
    private var index = 0
    private var dataManager: ServiceProtocol
    private var sample_count: Int
    
    // MARK: - Initialization
    init(sample_count: Int = 20, dataManager: ServiceProtocol = Service.shared) {
        self.sample_count = sample_count
        self.dataManager = dataManager
        super.init()
        setupAudioSession()
    }
    
    // MARK: - Audio Setup
    private func setupAudioSession() {
        do {
            session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord)
            try session.overrideOutputAudioPort(.speaker)
        } catch {
            print(error.localizedDescription)
        }
    }
    
    public func initializePlayer(with data: Data) {
        do {
            player = try AVAudioPlayer(data: data)
            player?.delegate = self
            displayedTime = player?.duration ?? 0.0
            visualizeAudio(data: data)
        } catch {
            print(error.localizedDescription)
        }
    }
    
    // MARK: - Timer Functions
    private func startTimer() {
        guard let player = player else { return }
        
        count_duration { duration in
            self.time_interval = (duration / Double(self.sample_count)) - 0.03
            self.timer = Timer.scheduledTimer(withTimeInterval: self.time_interval, repeats: true) { _ in
                self.displayedTime = player.currentTime
                self.updateSoundSamples()
            }
        }
    }
    
    // MARK: - Audio Controls
    
    
    func loadAudio(url: URL) {
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let data = data, error == nil {
                    self?.initializePlayer(with: data)
                } else {
                    // Handle the error, e.g., show an alert or log the error
                }
            }
        }.resume()
    }
    
     func playAudio() {
        guard let player = player, !isPlaying else { return }
        player.play()
        isPlaying = true
        startTimer()
    }
    
    func pauseAudio() {
        player?.pause()
        timer?.invalidate()
        isPlaying = false
    }
    
    private func playerDidFinishPlaying() {
        displayedTime = player?.duration ?? 0.0
        resetSoundSamples()
        print("Has finished playing.")
        player?.pause()
        timer?.invalidate()
        player?.stop()
    }
    
    // MARK: - Audio Visualization
    public func visualizeAudio(data: Data) {
        // Visualize audio using 'data'
        dataManager.buffer(data: data, id: UUID().uuidString, samplesCount: sample_count) { samples in
            DispatchQueue.main.async {
                self.soundSamples = samples
            }
        }
    }
    
    
    private func resetSoundSamples() {
         // Don't use animation block here, it's not necessary and could cause issues
         self.soundSamples = self.soundSamples.map { model in
             var newModel = model
             newModel.hasPlayed = false
             return newModel
         }
     }
    
    private func updateSoundSamples() {
        if self.index < self.soundSamples.count {
            self.soundSamples[self.index].color = Color.green
            withAnimation(Animation.linear(duration: self.time_interval)) {
                self.soundSamples[self.index].hasPlayed = true
            }
            self.index += 1
        }
    }
    
    // MARK: - Utility Functions
    private func count_duration(completion: @escaping (Float64) -> ()) {
        completion(player?.duration ?? 0.0)
    }
    
    // MARK: - AVAudioPlayerDelegate
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async {
            self.isPlaying = false
            self.timer?.invalidate()
            self.timer = nil
            self.displayedTime = 0
            self.index = 0
            self.resetSoundSamples()
        }
    }
    
    private func handleAudioPlaybackFinished() {
        self.isPlaying = false
        self.displayedTime = 0 // or player?.duration if you want to show the full length
        self.resetSoundSamples() // Make sure this doesn't trigger separate view updates
    }
}



struct AudioPreviewModel: Hashable {
    var magnitude: Float
    var color: Color
    var hasPlayed: Bool = false
}
