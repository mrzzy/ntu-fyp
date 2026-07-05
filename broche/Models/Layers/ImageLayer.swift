//
//  ImageLayer.swift
//  broche
//
//  Created by Zhu Zhanyan on 2026-07-05.
//

import Foundation

/// Layer that hosts a single image
struct ImageLayer: Layer {
    /// Image data stored in this layer
    var image: Data

    /// Render this layer as image data
    /// - Returns: PNG-encoded image data representing the rendered layer
    func render() throws -> Data {
        return image
    }
}

