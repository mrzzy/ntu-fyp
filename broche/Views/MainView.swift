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

extension EnvironmentValues {
    @Entry var aiModelsState: AIModelsLoadState = .unloaded
}

struct MainView: View {
    /// currently selected sketch id
    @State private var sketchId: Sketch.ID?
    /// Currently selected tab
    @State var tab: Tab = .Draw
    @State private var aiModelsState: AIModelsLoadState = .unloaded
    @Environment(\.undoManager) private var undoManager
    let repo = Repository.shared

    private var showAIError: Binding<Bool> {
        Binding(
            get: {
                if case .error = aiModelsState {
                    return true
                }
                return false
            },
            set: { isPresented in
                if !isPresented {
                    aiModelsState = .unloaded
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
            Button("OK") { aiModelsState = .unloaded }
        } message: {
            if case .error = aiModelsState {
                Text("Unexpected Error occurred. AI features are disabled.")
            }
        }
        // configure swiftdata for all child views
        .modelContainer(repo.modelContainer)
        .environment(\.aiModelsState, aiModelsState)
        .task {
            // track swiftdata model changes in view undoManager
            repo.modelContext.undoManager = undoManager

            // start loading AI models in the background as soon as app starts
            do {
                try await AIRepository.shared.load()
                aiModelsState = .loaded
            } catch {
                aiModelsState = .error
            }
        }
    }
}

#Preview {
    MainView()
}
