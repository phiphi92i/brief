//
//  PlayerView.swift
//  brief.brief
//
//  Created by Philippe Tchinda on 20/09/2023.
//

import Foundation
import SwiftUI
import AVKit

class PlayerUIView: UIView {
    var isPlaying = false
    var url = ""
    
    var avPlayer: AVPlayer? {
        get {
            return playerLayer.player
        }
        set {
            playerLayer.player = newValue
        }
    }
    
    var playerLayer: AVPlayerLayer {
        return layer as! AVPlayerLayer
    }
    
    override static var layerClass: AnyClass {
        return AVPlayerLayer.self
    }
    
    init() {
        super.init(frame: .zero)
    }
    
    func setup(url: String, gravity: PlayerViewGravity? = .fit) {
        self.url = url
        if let url = URL(string: url) {
            self.avPlayer = AVPlayer(url: url)
            do {
                try AVAudioSession.sharedInstance().setCategory(.playback, options: .mixWithOthers)
            } catch let error {
                print(error.localizedDescription)
            }
            self.avPlayer?.isMuted = false
            
            _ = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: self.avPlayer?.currentItem, queue: nil) { _ in
                self.avPlayer?.seek(to: CMTime.zero)
                self.avPlayer?.play()
            }
            
            self.playerLayer.player = self.avPlayer
            self.playerLayer.videoGravity = gravity?.avGravity ?? .resizeAspect
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func togglePlay(play: Bool) {
        self.avPlayer?.seek(to: CMTime.zero)
        play ? self.avPlayer?.play() : self.avPlayer?.pause()
        self.isPlaying = play
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = bounds
    }
    
}


public enum PlayerViewGravity {
    case fit
    case fill
    case stretch
    
    var avGravity: AVLayerVideoGravity {
        switch self {
        case .fit:
            return .resizeAspect
        case .fill:
            return .resizeAspectFill
        case .stretch:
            return .resize
        }
    }
}

struct PlayerView: UIViewRepresentable {
    var url: String
    @Binding var play: Bool
    var gravity: PlayerViewGravity = .fill
    
    func updateUIView(_ uiView: PlayerUIView, context: UIViewRepresentableContext<PlayerView>) {
        if play != uiView.isPlaying {
            uiView.togglePlay(play: play)
        }
        if url != uiView.url {
            uiView.setup(url: url, gravity: gravity)
        }
    }
    
    func makeUIView(context: Context) -> PlayerUIView {
        let playerview = PlayerUIView()
        playerview.setup(url: url, gravity: gravity)
        return playerview
    }

}
