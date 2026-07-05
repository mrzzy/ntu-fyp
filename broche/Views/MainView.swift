//
//  MainView.swift
//  broche
//
//  Created by Zhu Zhanyan on 4/6/26.
//

import SwiftUI

struct MainView: View {
    @State private var viewModel = MainViewModel()

    var body: some View {
        TabView(selection: $viewModel.tab) {
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
