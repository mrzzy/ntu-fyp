//
//  Sketch.swift
//  broche
//
//  Created by Zhu Zhanyan on 2026-07-05.
//

import Foundation
import PencilKit
import SwiftData
import UIKit

/// Zoom
struct Zoom: Codable {
    var scale: Double
    var offsetX: Double
    var offsetY: Double
    var rotation: Double
    init(scale: Double = 1.0, offsetX: Double = 0.0, offsetY: Double = 0.0, rotation: Double = 0.0)
    {
        self.scale = scale
        self.offsetX = offsetX
        self.offsetY = offsetY
        self.rotation = rotation
    }
}

/// Defines a set of default layers a sketch starts with.
let SketchDefaultLayers: [Layer] = [
    .drawing(drawing: PKDrawing())
]
enum SketchError: Error, LocalizedError {
    case noLayersToRender
    case emptyRenderedImage

    var errorDescription: String? {
        switch self {
        case .noLayersToRender:
            return "No layers to render."
        case .emptyRenderedImage:
            return "Rendered image is empty."
        }
    }
}

/// Defines a sketch composed of a series of layers
@Model
class Sketch: CustomStringConvertible {
    var title: String
    var layers: [Layer]
    // dimensions of the sketch
    private(set) var width: Double
    private(set) var height: Double

    /// AI assistant conversation messages
    @Relationship(deleteRule: .cascade)
    var messages: [Message]

    /// Zoom view zoom/pan/rotation state
    var zoom: Zoom

    // cached compsited image version of the sketch
    @Transient private var _cachedImage: UIImage = UIImage()
    @Transient private var cacheImageTTL: Date = Date.distantPast

    var size: CGSize {
        CGSize(width: width, height: height)
    }

    var description: String {
        let layerDescriptions = layers.enumerated().map { index, layer in
            let type: String
            switch layer {
            case .drawing:
                type = "Drawing"
            case .image:
                type = "Image"
            }
            return "  [\(index)] \(type)"
        }.joined(separator: "\n")

        return """
            Sketch: \(title) 
            Dimensions (<width>x<height>): (\(Int(width))x\(Int(height)))
            Total Layers: \(layers.count)
            Layers: [<index>] <type>
            \(layerDescriptions)
            """
    }

    init(
        title: String = "Untitled", layers: [Layer] = SketchDefaultLayers,
        size: CGSize = CGSize(width: 512, height: 512),
        messages: [Message] = []

    ) {
        self.title = title
        self.layers = layers
        self.messages = messages
        width = size.width
        height = size.height
        zoom = Zoom()
    }

    /// Renders the sketch into a single flattened image by compositing all
    /// layers in order.
    ///
    /// Layers are drawn sequentially, with each subsequent layer composited on
    /// top of the previous ones. If the sketch contains no layers, an entirely transparent image is returned.
    ///
    /// - Returns: A `UIImage` representing the flattened sketch or an empty image if
    ///   the sketch has no layers.
    var image: UIImage {
        get throws { try renderLayers(indices: 0..<layers.count) }
    }

    /// Returns a cached image of the sketch, rendering it if the cache has expired.
    ///
    /// The cached image is valid for 5 seconds after the last render. If the cache
    /// has expired, the sketch is re-rendered and the cache is updated.
    var cachedImage: UIImage {
        get throws {
            let now = Date()
            if cacheImageTTL >= now {
                return _cachedImage
            }

            let renderedImage = try renderLayers(indices: 0..<layers.count)
            _cachedImage = renderedImage
            cacheImageTTL = now.addingTimeInterval(5)
            return renderedImage
        }
    }

    func renderLayers(indices: Range<Int>) throws -> UIImage {
        let selectedLayers = layers[indices]

        guard selectedLayers.first != nil else {
            throw SketchError.noLayersToRender
        }

        var images: [UIImage] = []
        for layer in selectedLayers {
            let data = try layer.render()
            guard let image = UIImage(data: data) else {
                throw SketchError.emptyRenderedImage
            }
            images.append(image)
        }

        let size = CGSize(width: width, height: height)
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            for image in images {
                image.draw(in: CGRect(origin: .zero, size: size))
            }
        }
    }
}
