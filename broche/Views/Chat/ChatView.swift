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
    let sketchId: Sketch.ID?
    let repo = Repository.shared

    var body: some View {
        if let id = sketchId {
            let sketch = repo.fetchSketch(id: id)
            NavigationSplitView {
                ChatDetailView(sketch: sketch)
                    .navigationTitle("AI Assistant")
            } detail: {
                SketchDetailView(sketch: sketch, isEnabled: false)
                    .navigationTitle("AI")
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            Button {
                                let sketch = repo.fetchSketch(id: id)
                                sketch?.zoom = Zoom()
                            } label: {
                                Label("Reset Zoom", systemImage: "arrow.counterclockwise")
                            }
                        }
                    }
            }
        } else {
            ContentUnavailableView(
                "Select a sketch to ask for assistant from AI.",
                systemImage: ChatIcon
            )
        }
    }
}

private struct ChatDetailView: View {
    @Environment(\.aiModelsState) var aiModelsState
    let repo = Repository.shared
    let sketch: Sketch?
    /// disabled if sketch is not selected or AI models are not loaded
    var isDisabled: Bool {
        // aiModelsState != .loaded || sketch == nil
        false
    }

    var body: some View {
        if let sketch = sketch {
            let exyteMessages = sketch.messages.compactMap { $0.toExyteChatMessage() }

            ExyteChat.ChatView(
                messages: exyteMessages,
                didSendMessage: handleSendMessage
            )
            // Disable attachments for now (deferred feature)
            .setAvailableInputs([.text])
            .onAppear {
                if sketch.messages.isEmpty {
                    // display a welcome message to the user
                    sketch.messages.append(SketchAgent.welcomeMessage)
                    repo.save()
                }
            }
            .disabled(isDisabled)
        } else {
            ContentUnavailableView(
                "Sketch not found.",
                systemImage: "questionmark"
            )
        }
    }

    private func handleSendMessage(_ message: ExyteChat.DraftMessage) {
        guard let sketch = sketch else { return }

        Task {
            do {
                let agent = try SketchAgent(sketch: sketch, models: AIRepository.shared)
                for try await messages in agent.instruct(prompt: message.text) {
                    // needed? await MainActor.run {
                    sketch.messages = messages

                    try repo.modelContext.save()
                }
            } catch let error as SketchAgentError {
                print("Error: Failed to create SketchAgent: \(error)")
                return
            } catch {
                print("Error: Failed to instruct SketchAgent: \(error)")
            }
        }
    }
}

#Preview {
    let container = try! ModelContainer(
        for: Sketch.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )

    let welcome = Message(
        user: .ai,
        text: """
            Hey! 👋 I'm your AI art assistant. I can help you refine your sketch and explore ideas.

            You can ask me to:
            • Modify, refine, or enhance parts of your sketch
            • Colorize and experiment with different styles
            • Render your ideas into more polished artwork
            • Discuss creative changes and improvements
            """
    )
    let userMsg = Message(
        user: .user,
        text: "Can you add some soft shading to the background?"
    )
    let aiReply = Message(
        user: .ai,
        text:
            "Sure! I'll add some gentle gradient shading to the background to give it more depth. Let me process that for you — this will create a subtle radial gradient from light blue to white behind the main subject.",
        replyMessage: userMsg
    )
    let userMsg2 = Message(
        user: .user,
        text: "That looks great! Now can you make the outlines slightly thicker?"
    )
    let aiReply2 = Message(
        user: .ai,
        text:
            "Done! I've increased the stroke width on the main outlines. The thicker lines should give the sketch a bolder, more defined look while keeping the overall style consistent.",
        replyMessage: userMsg2
    )
    let sketch = Sketch(
        title: "Sample Sketch", size: CGSize(width: 400, height: 400),
        messages: [welcome, userMsg, aiReply, userMsg2, aiReply2]
    )
    container.mainContext.insert(sketch)

    return ChatView(sketchId: sketch.persistentModelID)
        .modelContainer(container)
}
