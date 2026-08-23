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
            "A list of all user-created moods or styles with their titles, descriptions, image counts, and last modified times."
    )
    let moods: [MoodSummary]
}

struct ListMoodTool: AITool {
    nonisolated static let NAME = "list_mood"
    let name = Self.NAME
    let description = """
        Use this tool to list all moods or styles the user has created.
        Use this tool to understand what moods or styles are available before selecting or working with one.

        It returns each mood in the following schema:
        \(MoodSummary.generationSchema.debugDescription)
        """

    let repo: Repository

    init(repo: Repository?) {
        self.repo = repo ?? .shared
    }

    func call(arguments _: ListMoodArguments) async throws -> ListMoodOutput {
        let moods = repo.fetchMoods()
        let summaries = moods.map { MoodSummary.fromMood($0) }
        return ListMoodOutput(moods: summaries)
    }
}
