//
//  ConferenceScreenViewModel.swift
//  LiveKit-Playground
//
//  Created by Bogdan Vatamanu on 27.06.2024.
//

import Foundation
import Combine
import LiveKit

@MainActor
final class ConferenceScreenViewModel: ObservableObject {
    
    @Published var isMicrophoneEnabled: Bool
    @Published var isCameraEnabled: Bool
    
    @Published var isMicrophoneSwitchingInProgress: Bool = false
    @Published var isCameraSwitchingInProgress: Bool = false
    
    @Published private(set) var localParticipantInfo: ParticipantInfo
    @Published private(set) var remoteParticipantsInfos: [ParticipantInfo] = []
    @Published private(set) var selectedParticipantInfo: ParticipantInfo?
    
    @Published private(set) var disconnected: Bool = false
    
    private var room: Room
    private var cancellables = Set<AnyCancellable>()
    
    private var localParticipant: LocalParticipant {
        room.localParticipant
    }
    
    private var selectedParticipant: RemoteParticipant? {
        didSet {
            selectedParticipantInfo = if let selectedParticipant = selectedParticipant {
                 ParticipantInfo(selectedParticipant)
            } else {
                nil
            }
        }
    }
    
    init(room: Room) {
        self.room = room
        
        let localParticiapant = self.room.localParticipant
        isMicrophoneEnabled = localParticiapant.isMicrophoneEnabled()
        isCameraEnabled = localParticiapant.isCameraEnabled()
        
        localParticipantInfo = ParticipantInfo(room.localParticipant)
        
        room.add(delegate: self)
        setupListeners()
        
        subscribeToAllAvailableTracks()
        refreshLocalParticipant()
        refreshRemoteParticipants()
        
        selectParticipant(withId: findFirstParticipantWithCameraEnabled()?.id)
        refreshSelectedParticipant()
    }
    
    deinit {
        room.remove(delegate: self)
    }
    
    // MARK: - Public API
    
    func selectParticipant(withId id: String?) {
                
        if let id = id {
            if let selectedParticipant = findParticipant(withId: id) {
                self.selectedParticipant = selectedParticipant
            } else {
                print("Could not select participant because there is no one with \(id) id")
            }
        } else {
            selectedParticipant = nil
        }
    }
    
    func disconnect() {
        
        Task { @MainActor in
            await room.disconnect()
            disconnected = true
        }
    }
    
    // MARK: - Private API
    
    private func setupListeners() {
        
        $isMicrophoneEnabled.sink { [weak self] isMicrophoneEnabled in
            
            Task { @MainActor in
                await self?.setMicrophone(enabled: isMicrophoneEnabled)
       
            }
        }.store(in: &cancellables)
        
        $isCameraEnabled.sink { [weak self] isCameraEnabled in
            
            Task { @MainActor in
                await self?.setCamera(enabled: isCameraEnabled)
            }
        }.store(in: &cancellables)
    }
    
    private func subscribeToAllAvailableTracks() {
        Task {
            for participant in room.remoteParticipants.values {
                for publication in participant.trackPublications.values {
                    
                    guard
                        let publication = publication as? RemoteTrackPublication,
                        !publication.isSubscribed
                    else {
                        continue
                    }
                    
                    do {
                        try await publication.set(subscribed: true)
                    } catch {
                        print("Failed to subscribe to track with sid \(publication.sid)")
                    }
                }
            }
            
        }
    }
    
    // MARK: - Media Control
    
    private func setMicrophone(enabled: Bool) async {
        
        guard 
            !isMicrophoneSwitchingInProgress,
            localParticipant.isMicrophoneEnabled() != enabled
        else {
            return
        }
        
        await MainActor.run {
            isMicrophoneSwitchingInProgress = true
        }
        
        do {
            if enabled {
                let audioTrack = LocalAudioTrack.createTrack()
                try await localParticipant.publish(audioTrack: audioTrack)
            } else {
                
                guard let microphonePublication = self.localParticipant.firstAudioPublication as? LocalTrackPublication else {
                    throw "Invalid audio publication"
                }
                
                try await self.localParticipant.unpublish(publication: microphonePublication)
            }
        } catch {
            print("Error while tying to switch microphone \(isMicrophoneEnabled ? "on" : "off"): \(error)")
        }
        
        await MainActor.run {
            isMicrophoneSwitchingInProgress = false
        }
    }
    
    private func setCamera(enabled: Bool) async {
        
        guard 
            !isCameraSwitchingInProgress,
            localParticipant.isCameraEnabled() != enabled
        else {
            return
        }
        
        await MainActor.run {
            isCameraSwitchingInProgress = true
        }
        
        do {
            if enabled {
                let videoTrack = LocalVideoTrack.createCameraTrack()
                try await localParticipant.publish(videoTrack: videoTrack)
            } else {
                
                guard let cameraPublication = self.localParticipant.firstCameraPublication as? LocalTrackPublication else {
                    throw "Invalid camera publication"
                }
                
                try await self.localParticipant.unpublish(publication: cameraPublication)
            }
        } catch {
            print("Error while tying to switch camera \(isMicrophoneEnabled ? "on" : "off"): \(error)")
        }
        
        await MainActor.run {
            isCameraSwitchingInProgress = false
        }
    }
    
    // MARK: - Utils
    
    private func refreshLocalParticipant() {
        
        localParticipantInfo = ParticipantInfo(localParticipant)
    }
    
    private func refreshSelectedParticipant() {
        
        selectedParticipantInfo = if let selectedParticipant = selectedParticipant {
            ParticipantInfo(selectedParticipant)
        } else {
            nil
        }
    }
    
    private func refreshRemoteParticipants() {
        
        remoteParticipantsInfos = room.remoteParticipants.map { ParticipantInfo($0.value) }.sorted {
            $0.id < $1.id
        }
    }
    
    private func findParticipant(withId id: String) -> RemoteParticipant? {
        
        return room.remoteParticipants.first { $0.value.id == id }?.value
    }
    
    private func findFirstParticipantWithCameraEnabled() -> RemoteParticipant? {
        
        return room.remoteParticipants.first { $0.value.isCameraEnabled() }?.value
    }
}

// MARK: - Room Delegate

extension ConferenceScreenViewModel: RoomDelegate {
    
    // MARK: - Local Connection State
    
    func room(_ room: Room, didUpdateConnectionState connectionState: ConnectionState, from oldConnectionState: ConnectionState) {
        
        print("Local connection state did change old: \(oldConnectionState) -> new: \(connectionState)")
        
        if case .disconnected = connectionState {
            Task { @MainActor in
                disconnected = true
            }
        }
    }
    
    // MARK: - Remote Participant Connections
    
    func room(_ room: Room, participantDidConnect participant: RemoteParticipant) {
        
        print("Participant with id \(participant.id) connected to the room")
        
        Task { @MainActor in
            if selectedParticipant == nil {
                selectParticipant(withId: participant.id)
            }
            refreshRemoteParticipants()
        }
    }

    func room(_ room: Room, participantDidDisconnect participant: RemoteParticipant) {
        
        print("Participant with id \(participant.id) disconnected the room")
        
        Task { @MainActor in
            if selectedParticipantInfo?.id == participant.id {
                selectParticipant(withId: findFirstParticipantWithCameraEnabled()?.id)
            }
            refreshRemoteParticipants()
        }
    }
    
    // MARK: - Publish & Unpublish
    
    func room(_ room: Room, participant: RemoteParticipant, didPublishTrack publication: RemoteTrackPublication) {
        
        print("Remote participant with id \(participant.id) published track with sid \(publication.sid)")
       
        Task { @MainActor in
            do {
                try await publication.set(subscribed: true)
            } catch {
                print("Failed to subscribe to \(publication.sid) because \(error)")
            }
        }
    }
    
    func room(_ room: Room, participant: RemoteParticipant, didUnpublishTrack publication: RemoteTrackPublication) {
        
        print("Remote participant with id \(participant.id) unpublished track with sid \(publication.sid)")
        
        Task { @MainActor in
            do {
                try await publication.set(subscribed: false)
            } catch {
                print("Failed to subscribe to \(publication.sid) because \(error)")
            }
        }
    }
    
    func room(_ room: Room, participant: LocalParticipant, didPublishTrack publication: LocalTrackPublication) {
        
        print("Local participant published track with sid \(publication.sid)")
        
        Task { @MainActor in
            refreshLocalParticipant()
        }
    }
    
    func room(_ room: Room, participant: LocalParticipant, didUnpublishTrack publication: LocalTrackPublication) {
        
        print("Local participant unpublished track with sid \(publication.sid)")
        
        Task { @MainActor in
            refreshLocalParticipant()
        }
    }
    
    // MARK: - Subscriptions
    
    func room(_ room: Room, participant: RemoteParticipant, didSubscribeTrack publication: RemoteTrackPublication) {
        
        print("Remote participant with id \(participant.id) subscribed track with sid \(publication.sid)")
     
        Task { @MainActor in
            refreshRemoteParticipants()
            refreshSelectedParticipant()
        }
    }
    
    func room(_ room: Room, participant: RemoteParticipant, didUnsubscribeTrack publication: RemoteTrackPublication) {
        
        print("Remote participant with id \(participant.id) unsubscribed track with sid \(publication.sid)")
      
        Task { @MainActor in
            refreshRemoteParticipants()
            refreshSelectedParticipant()
        }
    }
    
    // MARK: - Track Updates
    
    func room(_ room: Room, participant: Participant, trackPublication: TrackPublication, didUpdateIsMuted isMuted: Bool) {
        
        if participant.id == localParticipant.id {
            
            print("Local participant \(isMuted ? "muted" : "unmuted") the track with sid \(trackPublication.sid)")
            
            Task { @MainActor in
                refreshLocalParticipant()
            }
        } else {
            
            print("Remote participant with id \(participant.id) \(isMuted ? "muted" : "unmuted") the track with sid \(trackPublication.sid)")
            
            if selectedParticipant?.id == participant.id {
                Task { @MainActor in
                    refreshSelectedParticipant()
                }
            }
        }
    }
}

// MARK: - Utils Structures

struct ParticipantInfo: Equatable, Identifiable {
    
    let id: String
    let name: String
    var cameraTrack: VideoTrack?
    
    fileprivate init(_ participant: Participant) {
        id = participant.id
        name = participant.name ?? id
        
        cameraTrack = if let track = participant.firstCameraVideoTrack, !track.isMuted {
            track
        } else {
            nil
        }
    }
    
    static func == (lhs: ParticipantInfo, rhs: ParticipantInfo) -> Bool {
        lhs.id == rhs.id
    }
}
