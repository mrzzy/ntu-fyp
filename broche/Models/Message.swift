//
//  Message.swift
//  Broche
//
// Created by Zhu Zhanyan on 2026-07-20.
//

import ExyteChat
import Foundation
import SwiftData
import SwiftUI

/// Represents the type of user who sent a message - either a regular user or AI
/// System messages are are hidden from the user and only show to the AI.
enum User: nonisolated Codable, CustomStringConvertible {
    case system
    case user
    case ai
    case tool

    var description: String {
        switch self {
        case .system:
            return "System"
        case .user:
            return "User"
        case .ai:
            return "AI"
        case .tool:
            return "Tool"
        }
    }
}

extension User {
    init(fromExyteChat exyteUser: ExyteChat.User) {
        switch exyteUser.type {
        case .current:
            self = .user
        default:
            self = .ai
        }
    }

    func toExyteChatUser() -> ExyteChat.User? {
        switch self {
        case .user:
            return ExyteChat.User(
                id: "user",
                name: "User",
                avatarURL: nil,
                isCurrentUser: true
            )
        case .ai:
            return ExyteChat.User(
                id: "ai",
                name: "AI",
                avatarURL: nil,
                isCurrentUser: false
            )
        // system & tool messages should not be shown in exyteChat
        case .tool:
            return nil
        case .system:
            return nil
        }
    }
}

/// Represents the type of attachment attached to a message
enum AttachmentType: Codable {
    case image
    case video
}

extension AttachmentType {
    init(fromExyteChat exyteType: ExyteChat.AttachmentType) {
        switch exyteType {
        case .image:
            self = .image
        default:
            self = .video
        }
    }

    var toExyteChat: ExyteChat.AttachmentType {
        self == .image ? .image : .video
    }
}

struct Attachment: Codable {
    var id: String

    var type: AttachmentType

    /// Thumbnail image shown in chat
    var thumbnail: URL

    /// Full-resolution asset
    var full: URL
}

extension Attachment {
    init(fromExyteChat exyteAttachment: ExyteChat.Attachment) {
        self.init(
            id: exyteAttachment.id,
            type: AttachmentType(fromExyteChat: exyteAttachment.type),
            thumbnail: exyteAttachment.thumbnail,
            full: exyteAttachment.full
        )
    }

    var toExyteChat: ExyteChat.Attachment {
        ExyteChat.Attachment(
            id: id,
            thumbnail: thumbnail,
            full: full,
            type: type.toExyteChat
        )
    }
}

/// AI chat message model
/// Uses cascade delete for attachments to maintain data integrity
/// Uses nullify for reply relationships to preserve reply chain when messages are deleted
@Model
final class Message {
    /// Unique identifier for this message (maps to ExyteChat Message.id)
    var id: String

    /// Type of user who sent the message
    var user: User

    /// Timestamp when the message was created
    var createdAt: Date

    /// Plain text content (converted from ExyteChat's AttributedString)
    var text: String

    /// Array of attachments associated with this message
    /// Cascade delete ensures attachments are removed when message is deleted
    var attachments: [Attachment]

    /// Reference to the message this is replying to (parent in thread)
    /// Nullify ensures the reply chain remains intact even if replyMessage is deleted
    @Relationship(deleteRule: .nullify)
    var replyMessage: Message?

    init(
        user: User,
        text: String,
        id: String = UUID().uuidString,
        createdAt: Date = Date(),
        attachments: [Attachment] = [],
        replyMessage: Message? = nil
    ) {
        self.id = id
        self.user = user
        self.createdAt = createdAt
        self.text = text
        self.attachments = attachments
        self.replyMessage = replyMessage
    }

    init(
        copying message: Message
    ) {
        id = message.id
        user = message.user
        createdAt = message.createdAt
        text = message.text
        attachments = message.attachments
        replyMessage = message.replyMessage
    }

    /// Creates a SwiftData Message from an ExyteChat Message
    convenience init(fromExyteChat exyteMessage: ExyteChat.Message) {
        let reply: Message? = exyteMessage.replyMessage.map { replyMsg in
            Message(
                user: User(fromExyteChat: replyMsg.user),
                text: replyMsg.text,
                id: replyMsg.id,
                createdAt: replyMsg.createdAt,
                attachments: replyMsg.attachments.map { Attachment(fromExyteChat: $0) }
            )
        }

        self.init(
            user: User(fromExyteChat: exyteMessage.user),
            text: exyteMessage.text,
            id: exyteMessage.id,
            createdAt: exyteMessage.createdAt,
            attachments: exyteMessage.attachments.map { Attachment(fromExyteChat: $0) },
            replyMessage: reply
        )
    }

    /// Converts this SwiftData Message to an ExyteChat Message for display in the chat interface
    /// Disregards system messages, which are not displayed in the chat UI by returning nil
    func toExyteChatMessage()
        -> ExyteChat.Message?
    {
        guard let exyteUser = user.toExyteChatUser() else {
            return nil
        }

        let exyteAttachments = attachments.map(\.toExyteChat)
        return ExyteChat.Message(
            id: id,
            user: exyteUser,
            createdAt: createdAt,
            text: text,
            attachments: exyteAttachments,
            replyMessage: replyMessage?.toReplyMessage()
        )
    }

    /// Converts this message to a ReplyMessage for ExyteChat
    func toReplyMessage() -> ExyteChat.ReplyMessage? {
        return toExyteChatMessage()?.toReplyMessage() ?? nil
    }
}
