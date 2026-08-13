//
//  Layer.swift
//  broche
//
//  Created by Zhu Zhanyan on 2026-07-05.
//

import PencilKit
import SwiftData

enum LayerError: Error {
    case renderError(reason: String)
}

/// Layer of a sketch. A sketch is composed by one or more overlapping layers.
enum Layer: Codable, CustomStringConvertible {
    case drawing(drawing: PKDrawing = PKDrawing(), modifiedOn: Date = .now)
    case image(data: Data, modifiedOn: Date = .now)

    /// Render this layer of this sketch as a image encoded as binary data.
    func render(size: CGSize) throws -> Data {
        switch self {
        case let .drawing(drawing, _):
            if let data = drawing.image(from: CGRect(origin: .zero, size: size), scale: 1.0)
                .pngData()
            {
                return data
            }
            throw LayerError.renderError(reason: "Failed to render PKDrawing as PNG image data.")
        case let .image(data, _):
            return data
        }
    }

    var modifiedOn: Date {
        switch self {
        case let .drawing(_, modifiedOn):
            return modifiedOn
        case let .image(_, modifiedOn):
            return modifiedOn
        }
    }

    var description: String {
        switch self {
        case let .drawing(drawing, modifiedOn):
            return "Layer.drawing(drawing: \(drawing), modifiedOn: \(modifiedOn))"
        case let .image(data, modifiedOn):
            return "Layer.image(data: PNG \(data.count) bytes, modifiedOn: \(modifiedOn))"
        }
    }
}
