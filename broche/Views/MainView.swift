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
}

struct MainView: View {
    /// Currently selected tab
    @State var tab: Tab = .Draw

    var body: some View {
        TabView(selection: $tab) {
            MoodView()
                .tabItem {
                    Label("Mood", systemImage: MoodIcon)
                }
                .tag(Tab.Mood)

            Text("Draw View")
                .tabItem {
                    Label("Draw", systemImage: "pencil.tip")
                }
                .tag(Tab.Draw)
        }
    }
}

#Preview {
    MainView()
}
