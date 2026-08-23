//
//  InjectMoodTool.swift
//  broche
//
//  Created by Zhu Zhanyan on 2026-08-23.
//

import Foundation
import FoundationModels

enum InjectMoodError: Error, LocalizedError {
    case moodNotFound(id: String)

    var errorDescription: String? {
        switch self {
        case .moodNotFound(let id):
            return "Mood with id '\(id)' not found."
        }
    }
}

@Generable
struct InjectMoodArguments: Codable, Sendable {
    @Guide(
        description:
            "The unique identifier of the mood to retrieve the description for."
    )
    let id: String
}

@Generable
struct InjectMoodOutput: Codable, Sendable {
    @Guide(description: "The title of the mood.")
    let title: String

    @Guide(description: "The description of the mood, capturing the visual atmosphere, colors, style, and overall feeling.")
    let description: String
}

struct InjectMoodTool: AITool {
    nonisolated static let NAME = "inject_mood"
    let name = Self.NAME
    let description = """
        Use this tool to retrieve the full description of a specific mood or style by its id.
        Use this after listing moods with the list_mood tool to get the details of a mood you want to use.

        It returns the mood description in the following schema:
        \(InjectMoodOutput.generationSchema.debugDescription)
        """

    let repo: Repository

    init(repo: Repository?) {
        self.repo = repo ?? .shared
    }

    func call(arguments: InjectMoodArguments) async throws -> InjectMoodOutput {
        guard let uuid = UUID(uuidString: arguments.id) else {
            throw InjectMoodError.moodNotFound(id: arguments.id)
        }
        guard let mood = repo.fetchMood(id: uuid) else {
            throw InjectMoodError.moodNotFound(id: arguments.id)
        }
        return InjectMoodOutput(title: mood.title, description: mood.info)
    }
}
