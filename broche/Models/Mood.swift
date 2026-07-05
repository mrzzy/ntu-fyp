//
//  Mood.swift
//  broche
//
//  Created by Zhu Zhanyan on 2026-07-05
//

import Foundation
import SwiftData


/// Defines a user created Mood for directing AI image generation
@Model
class Mood {
    /// User provided description for the mood.
    var info: String
    /// User provided images for the mood, serialised as binary data.
    var images: [Data]

    init(info: String, images: [Data]) {
        self.info = info
        self.images = images
    }
}

