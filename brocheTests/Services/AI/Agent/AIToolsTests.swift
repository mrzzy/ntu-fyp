import Foundation
import FoundationModels
import Testing

@testable import broche

@Generable
private struct Coordinate: Codable, Sendable {
    @Guide(description: "Latitude in decimal degrees.")
    let latitude: Double

    @Guide(description: "Longitude in decimal degrees.")
    let longitude: Double
}

@Generable
private struct EmptyInput: Codable, Sendable {}

@Generable
private struct TemperatureOutput: Codable, Sendable {
    @Guide(description: "Temperature in Celsius.")
    let celsius: Double
}

private struct GetCurrentLocationTool: AITool {
    let description = "Return the current location in coordinates."

    func call(arguments _: EmptyInput) async throws -> Coordinate {
        Coordinate(latitude: 51.5074, longitude: -0.1278)
    }
}

private struct GetCurrentTemperatureTool: AITool {
    let name = "get_current_temperature"
    let description = "Return the temperature at the provided coordinates."

    func call(arguments _: Coordinate) async throws -> TemperatureOutput {
        TemperatureOutput(celsius: 25.0)
    }
}

@Suite("AITools tests")
struct AIToolsTests {
    // MARK: - Tool schema tests

    @Test("Tool spec is a type:function dict with name, description and parameters")
    func toolSpecHasCorrectStructure() throws {
        let tool = GetCurrentTemperatureTool()
        let spec = tool.spec

        #expect(spec["type"] as? String == "function")
        let function = try #require(spec["function"] as? [String: Any])
        #expect(function["name"] as? String == "get_current_temperature")
        #expect(
            function["description"] as? String
                == "Return the temperature at the provided coordinates.")
        let params = try #require(function["parameters"] as? [String: Any])
        #expect(params["type"] as? String == "object")
    }

    @Test("Tool schema string is valid JSON derived from spec")
    func toolSchemaStringMatchesSpec() throws {
        let tool = GetCurrentTemperatureTool()
        let schemaStr = tool.schema

        let data = Data(schemaStr.utf8)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        #expect(json?["type"] as? String == "function")
        let function = try #require(json?["function"] as? [String: Any])
        #expect(function["name"] as? String == "get_current_temperature")
        #expect(
            function["description"] as? String
                == "Return the temperature at the provided coordinates.")
        #expect(function["parameters"] is [String: Any])
    }
}
