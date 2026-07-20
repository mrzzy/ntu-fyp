//
//  MainView.swift
//  broche
//
//  Created by Zhu Zhanyan on 4/6/26.
//

import SwiftUI

/// Available tabs in the main view
enum Tab {
    case Mood
    case Draw
    case Chat
}

struct MainView: View {
    /// Currently selected tab
    @State var tab: Tab = .Draw
    /// currently selected sketch id
    @State private var sketchId: Sketch.ID?

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

            ChatView(sketchId: $sketchId)
                .tabItem {
                    Label("AI", systemImage: ChatIcon)
                }
                .tag(Tab.Chat)
        }
    }
}

#Preview {
    MainView()
}
