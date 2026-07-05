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
            Text("Mood View")
                .tabItem {
                    Label("Mood", systemImage: "sun.horizon")
                }
                .tag(Tab.Mood)

            Text("Draw View")
                .tabItem {
                    Label("Draw", systemImage: "pencil")
                }
                .tag(Tab.Draw)
        }
    }
}

#Preview {
    MainView()
}
