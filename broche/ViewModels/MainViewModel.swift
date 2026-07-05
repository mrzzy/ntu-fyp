//
//  MainViewModel.swift
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

/// Manages state for the main view
@Observable
class MainViewModel {
    /// Currently selected tab
    var tab: Tab = .Draw
}
