//
//  MainViewModel.swift
//  broche
//
//  Created by Zhu Zhanyan on 2026-07-05
//

import SwiftUI

/// Available tabs in the main view
enum Tab {
    case Mood
    case Draw
}

/// Manages state for the main view
@Observable
class MainViewModel {
    /// Currently selected tab
    var tab: Tab = .Draw
}
