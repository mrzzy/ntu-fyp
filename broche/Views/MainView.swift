//
//  MainView.swift
//  broche
//
//  Created by Zhu Zhanyan on 4/6/26.
//

import FirebaseAuth
import SwiftData
import SwiftUI

/// Available tabs in the main view
enum Tab {
    case Mood
    case Draw
    case Chat
}

enum AIModelsLoadState: Sendable, Equatable {
    case unloaded
    case loaded
    case error
}

/// Non-persistent shared app state object
/// Use for cross cutting app state.
@Observable
class AppState {
    var aiModels: AIModelsLoadState = .unloaded
    var nUndoRedo: Int = 0
}

extension EnvironmentValues {
    @Entry var appState: AppState = .init()
}

struct MainView: View {
    @State private var isUnauthenticated = true
    @State private var sketchId: Sketch.ID?
    @State var tab: Tab = .Draw
    @State var appState: AppState = .init()
    @Environment(\.undoManager) private var undoManager
    let repo = Repository.shared

    private var showAIError: Binding<Bool> {
        Binding(
            get: {
                if case .error = appState.aiModels {
                    return true
                }
                return false
            },
            set: { isPresented in
                if !isPresented {
                    appState.aiModels = .unloaded
                }
            }
        )
    }

    var body: some View {
        TabView(selection: $tab) {
            MoodView()
                .tabItem {
                    Label("Mood", systemImage: MoodIcon)
                }
                .tag(Tab.Mood)

            SketchView(sketchId: $sketchId)
                .tabItem {
                    Label("Sketch", systemImage: SketchIcon)
                }
                .tag(Tab.Draw)

            ChatView(sketchId: sketchId)
                .tabItem {
                    Label("AI", systemImage: ChatIcon)
                }
                .tag(Tab.Chat)
        }
        .alert("AI Features Unavailable", isPresented: showAIError) {
            Button("OK") { appState.aiModels = .unloaded }
        } message: {
            if case .error = appState.aiModels {
                Text("Unexpected Error occurred. AI features are disabled.")
            }
        }
        // prompt user to login if not authenticated
        .sheet(
            isPresented: $isUnauthenticated
        ) {
            LoginView(isUnauthenticated: $isUnauthenticated)
                // dont allow interactive dismiss, user must log in to use the app
                .presentationDragIndicator(.hidden)
        }
        .environment(\.appState, appState)
        .modelContainer(repo.modelContainer)
        .onAppear {
            // reset firebase auth on first start
            // user may remain authenticated as firebase persists auth data in keychain
            // which is outside of the application's installation lifecycle
            let nStarts = UserDefaults.standard.integer(forKey: AppStarts)
            if nStarts == 0 {
                try? Auth.auth().signOut()
            }
            UserDefaults.standard.set(nStarts + 1, forKey: AppStarts)

            // check authentication status before view renders
            isUnauthenticated = Auth.auth().currentUser == nil
        }
        .onChange(of: isUnauthenticated, initial: false) {
            // user logged in, load AI models
            let models = AIRepository.shared
            guard !(isUnauthenticated || models.isLoaded) else { return }

            Task {
                do {
                    try await models.load()
                    appState.aiModels = .loaded
                } catch {
                    print("Failed to load AI models: \(error)")
                    appState.aiModels = .error
                }
            }
        }
    }
}

#Preview {
    MainView()
}
