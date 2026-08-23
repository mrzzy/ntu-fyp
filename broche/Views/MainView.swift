//
//  MainView.swift
//  broche
//
//  Created by Zhu Zhanyan on 4/6/26.
//

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
    /// currently selected sketch id
    @State private var sketchId: Sketch.ID?
    /// Currently selected tab
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
        .environment(\.appState, appState)
        // configure swiftdata for all child views
        .modelContainer(repo.modelContainer)
        .task {
            // track swiftdata model changes in view undoManager
            repo.modelContext.undoManager = undoManager

            // start loading AI models in the background as soon as app starts
            do {
                try await AIRepository.shared.load()
                appState.aiModels = .loaded
            } catch {
                print("Failed to load AI models: \(error)")
                appState.aiModels = .error
            }
        }
    }
}

#Preview {
    MainView()
}
