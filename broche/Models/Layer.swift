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
enum Layer: Codable {
    case drawing(drawing: PKDrawing)
    case image(data: Data)

    /// Render this layer of this sketch as a image encoded as binary data.
    func render(size: CGSize) throws -> Data {
        switch self {
        case .drawing(let drawing):
            if let data = drawing.image(from: CGRect(origin: .zero, size: size), scale: 1.0)
                .pngData()
            {   
                return data
            }
            throw LayerError.renderError(reason: "Failed to render PKDrawing as PNG image data.")
        case .image(let data):
            return data
        }
    }
}
