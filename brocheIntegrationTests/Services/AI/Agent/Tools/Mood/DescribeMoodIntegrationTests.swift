import Foundation
import Testing

@testable import broche

@Suite("describeMood integration tests")
@MainActor
struct DescribeMoodIntegrationTests {
    @Test("Generates title and description from images")
    func generatesTitleAndDescription() async throws {
        let visualModel = DefaultAIModelFactory.shared.makeVisualModel()
        try await visualModel.load()

        let output = try await describeMood(images: [TestFixtures.appleAIOil], visualModel: visualModel)
        #expect(!output.title.isEmpty, "Title should not be empty")
        #expect(!output.description.isEmpty, "Description should not be empty")
        print("Title: \(output.title)")
        print("Description: \(output.description)")
    }

    @Test("Throws noImagesProvided when images array is empty")
    func throwsNoImagesProvided() async {
        let visualModel = DefaultAIModelFactory.shared.makeVisualModel()

        await #expect(throws: DescribeMoodError.self) {
            _ = try await describeMood(images: [], visualModel: visualModel)
        }
    }
}
