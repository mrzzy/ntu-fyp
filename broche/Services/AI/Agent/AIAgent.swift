//
//  AIAgent
//  broche
//
//  Created by Zhu Zhanyan on 2026-07-28
//

import Foundation

/// An AI agent stateful actor that can hold a conversation with a user,
/// using a ``TextAIModel`` and tools to carry out tasks.
class AIAgent {
    let model: TextAIModel
    let options: TextAIOptions
    let tools: AIToolRegistry
    var _messages: [Message]
    var messages: [Message] {
        return _messages.filter { $0.user != .system }
    }

    /// Creates a new AI agent with the given model, tools, and messages.
    init(
        model: TextAIModel,
        tools: [any AITool] = [],
        messages: [Message] = []
    ) {
        self.model = model
        _messages = messages
        self.tools = AIToolRegistry(tools)
        options = TextAIOptions(
            temperature: 1.0,
            topP: 1.0,
            topK: 40,
            seed: 42,
            tools: self.tools.specs
        )
    }

    /// Sends a user prompt to the agent and streams updated message history.
    ///
    /// The agent appends the user message, generates a response, and yields
    /// the current messages after each step. If the response contains tool calls,
    /// each tool is executed and the loop continues until the model produces
    /// a final response with no tool calls.
    ///
    /// - Parameter prompt: The user's input text.
    /// - Returns: A stream of message snapshots after each generation step.
    func instruct(prompt: String) -> AsyncThrowingStream<[Message], Error> {
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    _messages.append(Message(user: .user, text: prompt))
                    continuation.yield(messages)

                    var toolCallsFound = true
                    while toolCallsFound {
                        toolCallsFound = false

                        var response = ""
                        // deduplicate tool calls from agent using set
                        var pendingToolCalls: Set<AIToolCall> = []

                        for try await out in model.generate(messages: _messages, options: options) {
                            switch out {
                            case .chunk(let text):
                                response += text
                            case .call(let call):
                                pendingToolCalls.insert(call)
                            case .complete:
                                break
                            }
                        }
                        print("AIAgent: \(response)")

                        if !response.isEmpty {
                            _messages.append(Message(user: .ai, text: response))
                        }
                        continuation.yield(messages)

                        toolCallsFound = !pendingToolCalls.isEmpty

                        for toolCall in pendingToolCalls {
                            let output: String
                            do {
                                output = try await tools.invoke(toolCall)
                            } catch {
                                output =
                                    "Tool call '\(toolCall)' failed: \(error.localizedDescription)"
                            }
                            let result = """
                                \(toolCall)
                                Results:
                                \(output)
                                """
                            print("AIAgent: Invoked tool call: \(result)")

                            _messages.append(
                                Message(
                                    user: .tool,
                                    text: result
                                )
                            )
                        }
                        continuation.yield(messages)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
