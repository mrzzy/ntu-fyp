//
//  AITool
//  broche
//
//  Created by Zhu Zhanyan on 2026-07-28
//

import Foundation
import FoundationModels

typealias AIToolSpec = [String: any Sendable]

/// Defines a tool that can be used by an AI agent
/// within & a Generable input Argument and output Output types conforms to `Generable`.
protocol AITool: FoundationModels.Tool
where Output: Generable {}
extension AITool {
    /// Calls the tool with the given JSON arguments and returns the output as JSON string.
    func callJSON(argsJSON: String) async throws -> String {
        let args = try Arguments(GeneratedContent(json: argsJSON))
        let output = try await call(arguments: args)
        return output.generatedContent.jsonString
    }

    /// Tool specification in a dictionary format
    var spec: AIToolSpec {
        let paramsData = Data(parameters.debugDescription.utf8)
        let paramsDict =
            (try! JSONSerialization.jsonObject(with: paramsData)) as? [String: any Sendable]

        let functionDict =
            [
                "name": name,
                "description": description,
                "parameters": paramsDict,
            ] as [String: any Sendable]
        return ["type": "function", "function": functionDict]
    }

    /// Tool specification in a JSON string format
    var schema: String {
        let data = try! JSONSerialization.data(
            withJSONObject: spec,
            options: [.sortedKeys]
        )
        return String(data: data, encoding: .utf8)!
    }
}

/// Represents a call to an AI tool with the tool name and arguments in JSON format.
struct AIToolCall: CustomStringConvertible, Hashable, Equatable {
    /// A unique identifier for this tool call, assigned by the AI model.
    let id: String
    /// The name of the tool to be called.
    let name: String
    /// The arguments for the tool call in JSON string format.
    let argsJSON: String

    var description: String {
        "AIToolCall(id: \(id), name: \(name), argsJSON: \(argsJSON))"
    }
}

enum AIToolRegistryError: LocalizedError {
    case toolNotFound(name: String)

    var errorDescription: String? {
        switch self {
        case .toolNotFound(let name):
            return "Tool '\(name)' not found in the registry."
        }
    }
}

/// A registry that manages a collection of AI tools,
/// allowing for tool calls and access to tool specifications.
class AIToolRegistry {
    let tools: [String: any AITool]

    init(_ tools: [any AITool] = []) {
        self.tools = Dictionary(uniqueKeysWithValues: tools.map { ($0.name, $0) })
    }

    /// Tool specifications of available tools in this registry
    var specs: [AIToolSpec] {
        tools.values.map { $0.spec }
    }

    /// Invokes a tool by name with the provided ar guments in JSON format.
    func invoke(_ toolCall: AIToolCall) async throws -> String {
        guard let tool = tools[toolCall.name] else {
            throw AIToolRegistryError.toolNotFound(name: toolCall.name)
        }
        return try await tool.callJSON(argsJSON: toolCall.argsJSON)
    }
}
