//
//  Mood.swift
//  broche
//
//  Created by Zhu Zhanyan on 2026-07-05
//

import Foundation
import FoundationModels
import SwiftData

/// Defines a user created Mood for directing AI image generation
@Model
class Mood {
    var id: UUID = UUID()
    /// User provided title for the mood.
    var title: String
    /// User provided description for the mood.
    var info: String
    /// User provided images for the mood, serialised as binary data.
    var images: [Data]
    /// Modified on timestamp.
    var modifiedOn: Date = Date.now

    init(title: String, info: String, images: [Data]) {
        self.title = title
        self.info = info
        self.images = images
    }
}

/// MoodSummary represents a Mood to JSON format to AI agents
@Generable
struct MoodSummary: Codable, Sendable {
    @Guide(description: "The unique identifier of the mood.")
    let id: String

    @Guide(description: "The title of the mood.")
    let title: String

    @Guide(description: "The description of the mood.")
    let description: String

    static func fromMood(_ mood: Mood) -> MoodSummary {
        MoodSummary(
            id: mood.id.uuidString,
            title: mood.title,
            description: mood.info
        )
    }
}
