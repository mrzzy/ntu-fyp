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
enum User: Codable {
    case user
    case ai
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

    func toExyteChatUser() -> ExyteChat.User {
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
        }
    }
}

/// Represents the type of attachment attached to a message
enum AttachmentType: Codable {
    case image
    case video
    case audio
    case file
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
        id: String,
        user: User,
        createdAt: Date = Date(),
        text: String = "",
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

    /// Creates a SwiftData Message from an ExyteChat Message
    convenience init(fromExyteChat exyteMessage: ExyteChat.Message) {
        let reply: Message? = exyteMessage.replyMessage.map { replyMsg in
            Message(
                id: replyMsg.id,
                user: User(fromExyteChat: replyMsg.user),
                createdAt: replyMsg.createdAt,
                text: replyMsg.text,
                attachments: replyMsg.attachments.map { Attachment(fromExyteChat: $0) }
            )
        }

        self.init(
            id: exyteMessage.id,
            user: User(fromExyteChat: exyteMessage.user),
            createdAt: exyteMessage.createdAt,
            text: exyteMessage.text,
            attachments: exyteMessage.attachments.map { Attachment(fromExyteChat: $0) },
            replyMessage: reply
        )
    }

    /// Converts this SwiftData Message to an ExyteChat Message for display in the chat interface
    func toExyteChatMessage()
        -> ExyteChat.Message
    {
        let exyteAttachments = attachments.map(\.toExyteChat)

        return ExyteChat.Message(
            id: id,
            user: user.toExyteChatUser(),
            createdAt: createdAt,
            text: text,
            attachments: exyteAttachments,
            replyMessage: replyMessage?.toReplyMessage()
        )
    }

    /// Converts this message to a ReplyMessage for ExyteChat
    func toReplyMessage() -> ExyteChat.ReplyMessage {
        return ExyteChat.ReplyMessage(
            id: id,
            user: user.toExyteChatUser(),
            createdAt: createdAt,
            text: text,
            attachments: [],
            recording: nil
        )
    }
}
