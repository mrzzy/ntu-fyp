//
//  brocheApp.swift
//  broche
//
//  Created by Zhu Zhanyan on 4/6/26.
//

import SwiftData
import SwiftUI

@main
struct brocheApp: App {
    var body: some Scene {
        WindowGroup {
            MainView()
        }
        .modelContainer(Repository.shared.modelContainer)
    }
}
