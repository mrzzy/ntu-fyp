//
//  Layer.swift
//  broche
//
//  Created by Zhu Zhanyan on 2026-07-05.
//

import SwiftUI

enum LayerError: Error {
    case renderError(reason: String)
    // unsupported layer type
    case invalidType
}

/// Layer of a sketch. A sketch is composed by one or more overlapping layers.
protocol Layer: Codable {
    /// Render this layer of this sketch as a image encoded as binary data.
    func render() throws -> Data
}

/// Wrapper for encoding/decoding a layer of a specific type
struct TypedLayer: Codable, Equatable {
    let type: String
    let data: Data

    init(layer: Layer) throws {
        type = String(describing: Swift.type(of: layer))
        data = try JSONEncoder().encode(layer)
    }

    func decode() throws -> Layer {
        let decoder = JSONDecoder()
        switch type {
        case "ImageLayer":
            return try decoder.decode(ImageLayer.self, from: data)
        case "DrawingLayer":
            return try decoder.decode(DrawingLayer.self, from: data)
        default:
            throw LayerError.invalidType
        }
    }
}
