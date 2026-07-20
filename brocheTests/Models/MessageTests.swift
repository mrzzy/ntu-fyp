//
//  MessageTests.swift
//  brocheTests
//
//  Created by Zhu Zhanyan on 7/10/26.
//

@testable import broche

import PencilKit
import Testing
import UIKit
import ExyteChat

@Suite("Message model tests")
struct MessageTests {
    @Test("Message conversion to ExyteChat.Message works correctly")
    func messageConversion() throws {
        // Create a test message with attachments and reactions
        let message = Message(
            id: "test-message-1",
            user: .user,
            createdAt: Date(),
            text: "Hello, this is a test message!",
            replyMessage: nil
        )

        // Add an attachment
        let attachment = try Attachment(
            id: "attachment-1",
            type: .image,
            thumbnail: #require(URL(string: "https://example.com/thumb.jpg")),
            full: #require(URL(string: "https://example.com/full.jpg"))
        )
        message.attachments.append(attachment)

        // Test conversion
        let exyteChatMessage = message.toExyteChatMessage()


        // Verify basic properties
        assert(exyteChatMessage.id == "test-message-1", "Message ID mismatch")
        assert(exyteChatMessage.text == "Hello, this is a test message!", "Message text mismatch")
        assert(exyteChatMessage.attachments.count == 1, "Attachment count mismatch")

        // Verify attachment conversion
        let convertedAttachment = try #require(exyteChatMessage.attachments.first)
        assert(convertedAttachment.id == "attachment-1", "Attachment ID mismatch")
        assert(convertedAttachment.type == .image, "Attachment type mismatch")
    }

    @Test("ExyteChat.Message conversion to Message works correctly")
    func exyteChatMessageConversion() throws {
        let thumbURL = try #require(URL(string: "https://example.com/thumb.jpg"))
        let fullURL = try #require(URL(string: "https://example.com/full.jpg"))

        let replyUser = User(
            id: "user-1",
            name: "Test User",
            avatarURL: nil,
            avatarCacheKey: nil,
            type: .other
        )
        let replyMessage = ExyteChat.ReplyMessage(
            id: "reply-1",
            user: replyUser,
            createdAt: Date().addingTimeInterval(-60),
            text: "Original message",
            attachments: [],
            recording: nil
        )

        let sender = User(
            id: "user-1",
            name: "Test User",
            avatarURL: nil,
            avatarCacheKey: nil,
            type: .current
        )
        let exyteMessage = ExyteChat.Message(
            id: "test-message-1",
            user: sender,
            createdAt: Date(),
            text: "Hello, this is a test message!",
            attachments: [
                ExyteChat.Attachment(
                    id: "attachment-1",
                    thumbnail: thumbURL,
                    full: fullURL,
                    type: ExyteChat.AttachmentType.image
                ),
            ],
            replyMessage: replyMessage
        )

        let message = Message(fromExyteChat: exyteMessage)

        #expect(message.id == "test-message-1")
        #expect(message.user == .user)
        #expect(message.text == "Hello, this is a test message!")
        #expect(message.attachments.count == 1)

        let attachment = try #require(message.attachments.first)
        #expect(attachment.id == "attachment-1")
        #expect(attachment.type == .image)
        #expect(attachment.thumbnail == thumbURL)
        #expect(attachment.full == fullURL)

        let reply = try #require(message.replyMessage)
        #expect(reply.id == "reply-1")
        #expect(reply.text == "Original message")
    }

    @Test("System user ExyteChat.Message converts to AI MessageUser")
    func systemUserConversion() {
        let systemUser = User(
            id: "system",
            name: "AI Assistant",
            avatarURL: nil,
            avatarCacheKey: nil,
            type: .system
        )
        let exyteMessage = ExyteChat.Message(
            id: "ai-1",
            user: systemUser,
            createdAt: Date(),
            text: "AI response"
        )

        let message = Message(fromExyteChat: exyteMessage)

        #expect(message.user == .ai)
    }

    @Test("AttachmentType converts to and from ExyteChat.AttachmentType")
    func attachmentTypeConversion() {
        #expect(AttachmentType(fromExyteChat:  .image) == .image)
        #expect(AttachmentType(fromExyteChat:  .video) == .video)
        #expect(AttachmentType.image.toExyteChat == .image)
        #expect(AttachmentType.video.toExyteChat == .video)
    }

    @Test("Attachment converts to and from ExyteChat.Attachment")
    func attachmentConversion() throws {
        let thumbURL = try #require(URL(string: "https://example.com/thumb.jpg"))
        let fullURL = try #require(URL(string: "https://example.com/full.jpg"))

        let exyteAttachment = ExyteChat.Attachment(
            id: "att-1",
            thumbnail: thumbURL,
            full: fullURL,
            type: ExyteChat.AttachmentType.image
        )

        let attachment = Attachment(fromExyteChat: exyteAttachment)
        #expect(attachment.id == "att-1")
        #expect(attachment.type == .image)
        #expect(attachment.thumbnail == thumbURL)
        #expect(attachment.full == fullURL)

        let roundtrip = attachment.toExyteChat
        #expect(roundtrip.id == "att-1")
        #expect(roundtrip.type == .image)
        #expect(roundtrip.thumbnail == thumbURL)
        #expect(roundtrip.full == fullURL)
    }
}
