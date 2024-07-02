//
//  ConnectScreenViewModel.swift
//  LiveKit-Playground
//
//  Created by Bogdan Vatamanu on 27.06.2024.
//

import Foundation
import Combine
import LiveKit

@MainActor
final class ConnectScreenViewModel: ObservableObject {
    @Published var serverURL: String = Constants.defaultServerURL
    @Published var token: String = Constants.defaultToken
    @Published var room: Room?
    
    @Published var connecting: Bool = false
    @Published var showError: Bool = false
    @Published var errorMessage: String = ""
    
    private var connectionTask: Task<(), Never>?
    
    private var connectOptions: ConnectOptions = {
        ConnectOptions(autoSubscribe: false, protocolVersion: .v9)
    }()
    
    private var roomOptions: RoomOptions = {
        let cameraCaptureOptions = CameraCaptureOptions()
        let audioCaptureOptions = AudioCaptureOptions()
        let videoPublishOptions = VideoPublishOptions(encoding: VideoEncoding(maxBitrate: 2_000_000, maxFps: 30),
                                                      simulcast: false,
                                                      preferredCodec: VideoCodec.vp8)
        let audioPublishOptions = AudioPublishOptions()
        
        return RoomOptions(
            defaultCameraCaptureOptions: cameraCaptureOptions,
            defaultAudioCaptureOptions: audioCaptureOptions,
            defaultVideoPublishOptions: videoPublishOptions,
            defaultAudioPublishOptions: audioPublishOptions,
            adaptiveStream: false,
            dynacast: false,
            reportRemoteTrackStatistics: true
        )
    }()
    
    func connect() {
        let room = Room()
        
        connectionTask = Task { @MainActor in
            connecting = true
            do {
                try await room.connect(url: serverURL,
                                       token: token,
                                       connectOptions: connectOptions,
                                       roomOptions: roomOptions)
                self.room = room
            } catch {
                self.errorMessage = "\(error)"
                showError = true
            }
            connectionTask = nil
            connecting = false
        }
    }
    
    func cancelInProgressConnection() {
        connectionTask?.cancel()
    }
}
