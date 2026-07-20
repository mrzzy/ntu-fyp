//
//  ChatView.swift
//  broche
//
//  Created by Zhu Zhanyan on 2026-07-15.
//

import ExyteChat
import SwiftData
import SwiftUI

struct ChatView: View {
    @Binding var sketchId: Sketch.ID?

    let repo: Repository = .shared

    var body: some View {
        if let id = sketchId {
            NavigationSplitView {
                ChatDetailView(sketchId: $sketchId)
                    .navigationTitle("AI Assistant")
            } detail: {
                SketchDetailView(sketch: repo.fetchSketch(id: id), isEnabled: false)
                    .navigationTitle("AI")
            }
        } else {
            ContentUnavailableView(
                "Pick a sketch to start asking AI for help.",
                systemImage: ChatIcon
            )
        }
    }
}

private struct ChatDetailView: View {
    @Binding var sketchId: Sketch.ID?
    @Environment(\.modelContext) private var modelContext
    let repo: Repository = .shared

    var sketch: Sketch? {
        if let id = sketchId {
            return repo.fetchSketch(id: id)
        }
        return nil
    }

    private var exyteMessages: [ExyteChat.Message] {
        sketch?.messages.map {
            $0.toExyteChatMessage()
        } ?? []
    }

    var body: some View {
        ExyteChat.ChatView(messages: exyteMessages, didSendMessage: handleSendMessage)
            // Disable attachments for now (deferred feature)
            .setAvailableInputs([.text])
            .onAppear {
                if sketch?.messages.isEmpty ?? true {
                    let welcomeMessage = Message(
                        id: UUID().uuidString,
                        user: .ai,
                        createdAt: Date(),
                        text: """
                            Hey! 👋 I'm your AI art assistant. I can help you refine your sketch and explore ideas.

                            You can ask me to:
                            • Modify, refine, or enhance parts of your sketch
                            • Colorize and experiment with different styles
                            • Render your ideas into more polished artwork
                            • Discuss creative changes and improvements
                            """
                    )
                    sketch?.messages.append(welcomeMessage)
                    repo.save()
                }
            }
    }

    /// Creates sample messages for testing the chat interface.
    ///
    /// Returns a realistic conversation between user and assistant
    /// to demonstrate the chat UI functionality.
    ///
    /// - Returns: Array of sample ExyteChat.Message objects
    ///
    /// TODO: Remove this function when actual conversation history is implemented
    private func createSampleMessages() -> [ExyteChat.Message] {
        // Create user greeting message
        let greetingMessage = ExyteChat.Message(
            id: UUID().uuidString,
            user: ExyteChat.User(
                id: "user",
                name: "User",
                avatarURL: nil,
                isCurrentUser: true
            ),
            createdAt: Date().addingTimeInterval(-300),  // 5 minutes ago
            text: "Hello! Can you help me with my sketch?"
        )

        // Create assistant response
        let assistantResponse = ExyteChat.Message(
            id: UUID().uuidString,
            user: ExyteChat.User(
                id: "llm",
                name: "Assistant",
                avatarURL: nil,
                isCurrentUser: false
            ),
            createdAt: Date().addingTimeInterval(-290),  // 4:50 minutes ago
            text:
                "Of course! I can help you with your sketch. What would you like to work on? I can provide suggestions for improvements, help with composition, or offer creative ideas for your design."
        )

        // Create user follow-up
        let followUpMessage = ExyteChat.Message(
            id: UUID().uuidString,
            user: ExyteChat.User(
                id: "user",
                name: "User",
                avatarURL: nil,
                isCurrentUser: true
            ),
            createdAt: Date().addingTimeInterval(-180),  // 3 minutes ago
            text:
                "I'd like some suggestions for adding more depth to my landscape sketch. Any ideas?"
        )

        return [greetingMessage, assistantResponse, followUpMessage]
    }

    private func handleSendMessage(_ draft: ExyteChat.DraftMessage) {
        guard let sketch = sketch else { return }

        let userMessage = Message(
            id: UUID().uuidString,
            user: .user,
            createdAt: Date(),
            text: draft.text
        )
        sketch.messages.append(userMessage)
        do {
            try modelContext.save()
        } catch {
            print("Warning: Failed to save message: \(error)")
        }

        Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000)

            let llmResponse = Message(
                id: UUID().uuidString,
                user: .ai,
                createdAt: Date(),
                text: "This is a mock LLM response to: \"\(draft.text)\""
            )
            await MainActor.run {
                sketch.messages.append(llmResponse)
                do {
                    try modelContext.save()
                } catch {
                    print("Warning: Failed to save LLM response: \(error)")
                }
            }
        }
    }
}

#Preview {
    ChatView(sketchId: .constant(nil))
        .modelContainer(for: Sketch.self, inMemory: true)
}
