//
//  ConferenceScreen.swift
//  LiveKit-Playground
//
//  Created by Bogdan Vatamanu on 27.06.2024.
//

import SwiftUI
import LiveKit

struct ConferenceScreen: View {
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    
    @StateObject private var viewModel: ConferenceScreenViewModel
    
    init(room: Room) {
        _viewModel = StateObject(wrappedValue: ConferenceScreenViewModel(room: room))
    }
    
    var body: some View {
        VStack {
            
            VStack(spacing: .zero) {
                conferenceVideoView
                
                participantsCarousel
            }
            
            VStack {
                Toggle("Camera", isOn: $viewModel.isCameraEnabled)
                    .disabled(viewModel.isCameraSwitchingInProgress)
                
                Toggle("Microphone", isOn: $viewModel.isMicrophoneEnabled)
                    .disabled(viewModel.isMicrophoneSwitchingInProgress)
            }
            .padding(.horizontal)
            
            Spacer()
            
            Button("Disconnect") {
                viewModel.disconnect()
            }
            .font(.title2)
            
        }
        .onChange(of: viewModel.disconnected) { disconnected in
            if disconnected {
                presentationMode.wrappedValue.dismiss()
            }
        }
        .navigationTitle("Conference")
        .navigationBarBackButtonHidden(true)
    }
    
    // MARK: - Conference Videos
    
    @ViewBuilder
    private var conferenceVideoView: some View {
        ZStack(alignment: .bottomTrailing) {
            Color.black
            
            if let localCameraTrack = viewModel.selectedParticipantInfo?.cameraTrack {
                SwiftUIVideoView(localCameraTrack)
                    .id(viewModel.selectedParticipantInfo?.id)
            }
            
            if let remoteCameraTrack = viewModel.localParticipantInfo.cameraTrack {
                SwiftUIVideoView(remoteCameraTrack)
                    .frame(width: 128, height: 128)
                    .transition(.scale)
            }
        }
        .frame(height: 350)
        .overlay {
            if viewModel.selectedParticipantInfo?.cameraTrack == nil {
                Text("No video source from remote participant")
                    .foregroundColor(.white)
                    .bold()
            }
        }
    }
    
    // MARK: - Participants Carousel
    
    @ViewBuilder
    private var participantsCarousel: some View {
        let selectedParticipantId = viewModel.selectedParticipantInfo?.id
        
        ScrollView(.horizontal) {
            LazyHStack {
                ForEach(viewModel.remoteParticipantsInfos) { participant in
                    participantBubble(participant: participant,
                                      isSelected: selectedParticipantId == participant.id)
                    .transition(.scale)
                }
            }
        }
        .frame(height: 45)
        .background(Color.gray.opacity(0.3))
        .overlay(alignment: .leading) {
            if viewModel.remoteParticipantsInfos.isEmpty {
               Text("No participant")
                    .foregroundColor(.black)
                    .padding(.leading)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.remoteParticipantsInfos)
    }
        
    
    @ViewBuilder
    private func participantBubble(participant: ParticipantInfo, isSelected: Bool) -> some View {
        Button {
            viewModel.selectParticipant(withId: participant.id)
        } label: {
            Text("\(participant.name.first ?? "?")")
                .font(.title2)
                .bold()
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
                .background(isSelected ? .green : .blue)
                .clipShape(Circle())
        }
    }
}
