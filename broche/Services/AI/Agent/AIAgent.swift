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

    /// Sends a user prompt to the agent and streams each new message.
    ///
    /// The agent appends the user message, generates a response, and yields
    /// each newly appended message. If the response contains tool calls,
    /// each tool is executed and the loop continues until the model produces
    /// a final response with no tool calls.
    ///
    /// - Parameter prompt: The user's input text.
    /// - Returns: A stream of new messages added during the conversation turn.
    func instruct(prompt: String) -> AsyncThrowingStream<Message, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let userMsg = Message(user: .user, text: prompt)
                    _messages.append(userMsg)
                    continuation.yield(userMsg)

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
                            let aiMsg = Message(user: .ai, text: response)
                            _messages.append(aiMsg)
                            continuation.yield(aiMsg)
                        }

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

                            let toolMsg = Message(user: .tool, text: result)
                            _messages.append(toolMsg)
                            continuation.yield(toolMsg)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
