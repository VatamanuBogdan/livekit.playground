//
//  ConnectScreenViewModel.swift
//  LiveKit-Playground
//
//  Created by Bogdan Vatamanu on 27.06.2024.
//

import SwiftUI

struct ConnectScreen: View {
    
    @StateObject private var viewModel = ConnectScreenViewModel()
    
    var body: some View {
        VStack {
            VStack {
                TextField(text: $viewModel.serverURL, prompt: Text("Server URL")) {
                    Image(systemName: "network")
                }
                
                TextField(text: $viewModel.token, prompt: Text("Token")) {
                    Image(systemName: "key.fill")
                }
            }
            .textFieldStyle(.roundedBorder)
            .textInputAutocapitalization(.never)
            .disableAutocorrection(true)
            
            NavigationLink(isActive: conferenceScreenIsActive) {
                if let room = viewModel.room {
                    ConferenceScreen(room: room)
                }
            } label: {
                Button("Connect") {
                    viewModel.connect()
                }
            }
            .padding(.top, 10)
            
            Spacer()
        }
        .padding()
        .alert(viewModel.errorMessage, isPresented: $viewModel.showError) {
            Button("Ok", role: .cancel) {
            }
        }
        .progressOverlay($viewModel.connecting) {
            viewModel.cancelInProgressConnection()
        }
        .navigationTitle("LiveKit Demo")
    }

    private var conferenceScreenIsActive: Binding<Bool> {
        Binding<Bool>(
            get: {
                viewModel.room != nil
            },
            set: { value in
                if value == false {
                    viewModel.room = nil
                }
            }
        )
    }
}

#Preview {
    NavigationView {
        ConnectScreen()
    }
}
