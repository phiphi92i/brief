//
//  UserEvents.swift
//  brief.brief
//
//  Created by Philippe Tchinda on 07/07/2023.
//

import SwiftUI

public class UserEvents: ObservableObject {
    @Published public var didAskToCapturePhoto = false
    @Published public var didAskToRotateCamera = false
    @Published public var didAskToChangeFlashMode = false
    
    @Published public var didAskToRecordVideo = false
    @Published public var didAskToStopRecording = false
    
    public init() {
        
    }
}
