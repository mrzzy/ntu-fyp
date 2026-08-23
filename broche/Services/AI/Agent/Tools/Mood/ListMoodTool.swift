//
//  ListMoodTool.swift
//  broche
//
//  Created by Zhu Zhanyan on 2026-08-17.
//

import Foundation
import FoundationModels
import SwiftData

@Generable
struct ListMoodArguments: Codable, Sendable {}

@Generable
struct ListMoodOutput: Codable, Sendable {
    @Guide(
        description:
            "A list of all user-created moods or styles with their ids and titles."
    )
    let moods: [MoodListItem]
}

@Generable
struct MoodListItem: Codable, Sendable {
    @Guide(description: "The unique identifier of the mood.")
    let id: String

    @Guide(description: "The title of the mood.")
    let title: String

    static func fromMood(_ mood: Mood) -> MoodListItem {
        MoodListItem(
            id: mood.id.uuidString,
            title: mood.title
        )
    }
}

struct ListMoodTool: AITool {
    nonisolated static let NAME = "list_mood"
    let name = Self.NAME
    let description = """
        Use this tool to list all moods or styles the user has created.
        Use this tool to understand what moods or styles are available before selecting or working with one.

        It returns each mood in the following schema:
        \(MoodListItem.generationSchema.debugDescription)
        """

    let repo: Repository

    init(repo: Repository?) {
        self.repo = repo ?? .shared
    }

    func call(arguments _: ListMoodArguments) async throws -> ListMoodOutput {
        let moods = repo.fetchMoods()
        let items = moods.map { MoodListItem.fromMood($0) }
        return ListMoodOutput(moods: items)
    }
}
