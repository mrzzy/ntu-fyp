import Foundation
import SwiftData
import Testing

@testable import broche

@Suite("InjectMoodTool tests")
@MainActor
struct InjectMoodToolTests {
    private func makeTestRepository() throws -> Repository {
        let schema = Schema([Mood.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: [config])
        return Repository(modelContainer: container)
    }

    @Test("Injects mood description by id")
    func injectsMoodDescription() async throws {
        let repo = try makeTestRepository()
        let context = repo.modelContext

        let mood = Mood(
            title: "Serene Sunset",
            info: "Warm sunset colors over a calm ocean",
            images: [TestFixtures.appleAIOil]
        )
        context.insert(mood)
        try context.save()

        let tool = InjectMoodTool(repo: repo)
        let output = try await tool.call(arguments: InjectMoodArguments(id: mood.id.uuidString))

        #expect(output.title == "Serene Sunset")
        #expect(output.description == "Warm sunset colors over a calm ocean")
    }

    @Test("Throws moodNotFound for nonexistent id")
    func throwsForNonexistentId() async throws {
        let repo = try makeTestRepository()
        let tool = InjectMoodTool(repo: repo)

        await #expect(throws: InjectMoodError.self) {
            _ = try await tool.call(arguments: InjectMoodArguments(id: UUID().uuidString))
        }
    }

    @Test("Throws moodNotFound for invalid UUID string")
    func throwsForInvalidUUID() async throws {
        let repo = try makeTestRepository()
        let tool = InjectMoodTool(repo: repo)

        await #expect(throws: InjectMoodError.self) {
            _ = try await tool.call(arguments: InjectMoodArguments(id: "not-a-uuid"))
        }
    }
}
