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
                        if let id = sketchId,
                            let sketch = repo.fetchSketch(id: id)
                        {
                            SketchToolbar(sketch: sketch)
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
    let repo: Repository = .shared
    @State var messages: [ExyteChat.Message] = []

    let sketch: Sketch?
    @Environment(\.aiModelsState) var aiModelsState
    @State var agent: SketchAgent? = nil

    var body: some View {
        if let sketch = sketch {
            if agent != nil {
                ExyteChat.ChatView(
                    messages: messages
                ) {
                    draft in handleSendMessage(draft)
                }
                // Disable attachments for now (deferred feature)
                .setAvailableInputs([.text])
                .onAppear {
                    // TODO: check if this is required
                    // sketch.messages.removeAll()
                    if sketch.messages.isEmpty {
                        // display a welcome message to the user
                        sketch.messages.append(SketchAgent.welcomeMessage)
                        repo.save()
                    }
                    // load sketch messages into exyte message state
                    messages = sketch.messages.compactMap { $0.toExyteChatMessage() }
                }
                .onDisappear {
                    messages = []
                    agent = nil
                }
            } else {
                switch aiModelsState {
                case .unloaded:
                    // wait for models to load
                    ProgressView("Loading AI")
                case .loaded:
                    // wait for agent to load
                    ProgressView("Loading AI")
                        .onAppear {
                            agent = try! SketchAgent(
                                sketch: sketch, models: AIRepository.shared
                            )
                        }
                case .error:
                    ContentUnavailableView(
                        "AI failed to Load. ",
                        systemImage: "exclamationmark.triangle"
                    )
                }
            }
        } else {
            ContentUnavailableView(
                "Sketch not found.",
                systemImage: "questionmark"
            )
        }
    }

    private func handleSendMessage(_ draft: ExyteChat.DraftMessage) {
        guard let agent = agent else { return }

        // typing placeholder message to indicate the model is processing
        let typingMessage = ExyteChat.Message(
            id: UUID().uuidString,
            user: User.ai.toExyteChatUser()!,
            createdAt: Date(),
            text: "⋯"
        )

        Task {
            do {
                for try await message in agent.instruct(prompt: draft.text) {
                    if let exyteMessage = message.toExyteChatMessage() {
                        if message.user == .user {
                            messages.append(exyteMessage)
                            messages.append(typingMessage)
                        }
                        if message.user == .ai {
                            messages.removeAll { $0.id == typingMessage.id }
                            messages.append(exyteMessage)
                            messages.append(typingMessage)
                        }
                    }
                }
            } catch let error as SketchAgentError {
                print("Error: Failed to create SketchAgent: \(error)")
                return
            } catch {
                print("Error: Failed to instruct SketchAgent: \(error)")
            }
            messages.removeAll { $0.id == typingMessage.id }
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
