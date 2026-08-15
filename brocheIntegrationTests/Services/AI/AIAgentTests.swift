import Foundation
import FoundationModels
import Testing

@testable import broche

private let testModelID = DefaultAIModelFactory.defaultTextModelID

@Generable
private struct EmptyInput: Codable, Sendable {}

@Generable
private struct Coordinate: Codable, Sendable {
    @Guide(description: "Latitude of the location.")
    let latitude: Double

    @Guide(description: "Longitude of the location.")
    let longitude: Double
}

private struct GetCurrentLocationTool: AITool {
    let name = "get_current_location"
    let description =
        "Get the user's current geographic location as latitude and longitude coordinates."

    func call(arguments _: EmptyInput) async throws -> Coordinate {
        Coordinate(latitude: 51.5074, longitude: -0.1278)
    }
}

@Generable
private struct WeatherQuery: Codable, Sendable {
    @Guide(description: "Latitude of the location.")
    let latitude: Double

    @Guide(description: "Longitude of the location.")
    let longitude: Double
}

@Generable
private struct WeatherOutput: Codable, Sendable {
    @Guide(description: "Temperature in Celsius.")
    let temperature: Double

    @Guide(description: "Weather condition description.")
    let condition: String

    @Guide(description: "City name.")
    let city: String
}

private struct GetWeatherTool: AITool {
    let name = "get_weather"
    let description = "Get the current weather for a given latitude and longitude."

    func call(arguments _: WeatherQuery) async throws -> WeatherOutput {
        WeatherOutput(temperature: 25.0, condition: "Sunny", city: "London")
    }
}

@Suite("AIAgent integration tests")
@MainActor
struct AIAgentTests {
    @Test("Agent chaDefaultAIModelFactoryFactoryt_location then get_weather")
    func agentChainsLocationThenWeather() async throws {
        let model = DefaultAIModelFactory.shared.makeTextModel()
        // Ensure the model is loaded before using it
        try await model.load()
        let agent = AIAgent(
            model: model,
            tools: [GetCurrentLocationTool(), GetWeatherTool()],
            messages: [
                Message(
                    user: .system,
                    text:
                        "You are a helpful assistant. Use the available tools when needed. Keep responses short."
                )
            ]
        )

        var collectedMessages: [Message] = []
        for try await message in agent.instruct(
            prompt: "What is the weather at my current location?"
        ) {
            collectedMessages.append(message)
        }

        let messages = collectedMessages
        #expect(!messages.isEmpty, "Stream should yield messages")

        let toolMessages = messages.filter { $0.user == .tool }
        let toolNames = toolMessages.map { msg in msg.text }

        #expect(toolMessages.count >= 2, "Expected at least 2 tool calls (location + weather)")

        let locationUsed = toolNames.contains { $0.contains("get_current_location") }
        let weatherUsed = toolNames.contains { $0.contains("get_weather") }
        #expect(locationUsed, "Agent should have called get_current_location")
        #expect(weatherUsed, "Agent should have called get_weather")

        let hasAI = messages.contains { $0.user == .ai }
        #expect(hasAI, "Agent should produce a final AI response after tool calls")

        print("Messages yielded: \(messages.count)")
        for (i, msg) in messages.enumerated() {
            print("--- Message \(i) [\(msg.user)] ---")
            print("  \(msg.text)")
        }
    }
}
