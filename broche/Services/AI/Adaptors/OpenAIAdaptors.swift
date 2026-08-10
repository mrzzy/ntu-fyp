//
//  OpenAIAdaptors.swift
//  broche
//

import Foundation
import OpenAI

enum OpenAIAdaptors {
    /// Converts app ``Message`` values to OpenAI ``ChatQuery/ChatCompletionMessageParam`` values.
    ///
    /// - Parameter messages: The conversation history.
    /// - Returns: An array of OpenAI message parameters.
    static func toChatMessages(
        from messages: [Message]
    ) -> [ChatQuery.ChatCompletionMessageParam] {
        typealias MessageParam = ChatQuery.ChatCompletionMessageParam

        return messages.map { msg in
            switch msg.user {
            case .system:
                return MessageParam.system(.init(content: .textContent(msg.text)))
            case .user:
                return MessageParam.user(.init(content: .string(msg.text)))
            case .ai:
                return MessageParam.assistant(.init(content: .textContent(msg.text)))
            case .tool:
                return MessageParam.tool(.init(content: .textContent(msg.text), toolCallId: ""))
            }
        }
    }

    /// Converts a list of ``AIToolSpec`` dictionaries into OpenAI ``ChatQuery/ChatCompletionToolParam`` values.
    ///
    /// Returns `nil` when `specs` is empty, signalling to the API that no tools are available.
    /// Specs that lack a `"type": "function"` key or a function `name` are silently skipped.
    ///
    /// - Parameter specs: Tool specification dictionaries matching the OpenAI function-calling format.
    /// - Returns: An array of tool parameters, or `nil`.
    static func toToolParams(
        from specs: [AIToolSpec]
    ) -> [ChatQuery.ChatCompletionToolParam]? {
        guard !specs.isEmpty else { return nil }
        return specs.compactMap { spec -> ChatQuery.ChatCompletionToolParam? in
            guard let type = spec["type"] as? String,
                  type == "function",
                  let functionDict = spec["function"] as? [String: any Sendable],
                  let name = functionDict["name"] as? String
            else { return nil }
            let description = functionDict["description"] as? String
            var schema: JSONSchema?
            if let params = functionDict["parameters"],
               let data = try? JSONSerialization.data(
                   withJSONObject: params, options: [.sortedKeys]
               ) {
                schema = try? JSONDecoder().decode(JSONSchema.self, from: data)
            }
            return ChatQuery.ChatCompletionToolParam(
                function: .init(
                    name: name,
                    description: description,
                    parameters: schema
                )
            )
        }
    }
}
