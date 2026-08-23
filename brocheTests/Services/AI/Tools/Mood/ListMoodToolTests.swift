import Foundation
import SwiftData
import Testing

@testable import broche

@Suite("ListMoodTool tests")
@MainActor
struct ListMoodToolTests {
    private func makeTestRepository() throws -> Repository {
        let schema = Schema([Mood.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: [config])
        return Repository(modelContainer: container)
    }

    @Test("Lists moods with id and title only")
    func listsMoods() async throws {
        let repo = try makeTestRepository()
        let context = repo.modelContext

        let mood1 = Mood(
            title: "Serene Sunset",
            info: "Warm sunset colors over a calm ocean",
            images: [TestFixtures.appleAIOil]
        )
        mood1.modifiedOn = Date(timeIntervalSince1970: 1_700_000_000)

        let mood2 = Mood(
            title: "Urban Night",
            info: "City lights reflecting on wet streets",
            images: [TestFixtures.appleAIOil, TestFixtures.appleAIOilEdit]
        )
        mood2.modifiedOn = Date(timeIntervalSince1970: 1_700_100_000)

        context.insert(mood1)
        context.insert(mood2)
        try context.save()

        let tool = ListMoodTool(repo: repo)
        let output = try await tool.call(arguments: ListMoodArguments())

        #expect(output.moods.count == 2, "Should return 2 moods")
        #expect(
            output.moods[0].title == "Serene Sunset", "First mood should be the earliest modified"
        )
        #expect(output.moods[0].id == mood1.id.uuidString)
        #expect(output.moods[1].title == "Urban Night", "Second mood should be the later modified")
        #expect(output.moods[1].id == mood2.id.uuidString)
    }

    @Test("Returns empty list when no moods exist")
    func returnsEmptyList() async throws {
        let repo = try makeTestRepository()
        let tool = ListMoodTool(repo: repo)
        let output = try await tool.call(arguments: ListMoodArguments())

        #expect(output.moods.isEmpty, "Should return empty list when no moods exist")
    }
}
