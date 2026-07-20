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

/// Defines a set of default layers a sketch starts with.
let SketchDefaultLayers: [Layer] = [
    .drawing(drawing: PKDrawing())
]

let SketchDefaultMessages: [Message] = [
]

/// Defines a sketch composed of a series of layers
@Model
class Sketch {
    var title: String
    var layers: [Layer]
    // dimensions of the sketch
    private(set) var width: Double
    private(set) var height: Double

    /// AI assistant conversation messages
    @Relationship(deleteRule: .cascade)
    var messages: [Message] = []

    // cached compsited image version of the sketch
    @Transient private var _cachedImage: UIImage = UIImage()
    @Transient private var cacheImageTTL: Date = Date.distantPast

    var size: CGSize {
        CGSize(width: width, height: height)
    }

    init(
        title: String = "Untitled", layers: [Layer] = SketchDefaultLayers,
        size: CGSize = CGSize(width: 512, height: 512)
    ) {
        self.title = title
        self.layers = layers
        width = size.width
        height = size.height
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
        // image renders all layers
        return renderLayers(indices: 0..<layers.count)
    }

    /// Returns a cached image of the sketch, rendering it if the cache has expired.
    ///
    /// The cached image is valid for 5 seconds after the last render. If the cache
    /// has expired, the sketch is re-rendered and the cache is updated.
    var cachedImage: UIImage {
        let now = Date()
        // return cached image if still fresh
        if cacheImageTTL >= now {
            return _cachedImage
        }

        // composite all layers into a single image and cache it
        let renderedImage = renderLayers(indices: 0..<layers.count)
        _cachedImage = renderedImage
        cacheImageTTL = now.addingTimeInterval(5)
        return renderedImage
    }

    /// Renders only the selected layers
    /// indices: Range<Int> - the range of layer indices to render
    ///
    /// Layers are drawn sequentially, with each subsequent layer composited on
    /// top of the previous ones. If the sketch contains no layers an empty image is returned.
    ///
    /// - Returns: A `UIImage` representing the flattened sketch or an empty image if the sketch has no layers.
    func renderLayers(indices: Range<Int>) -> UIImage {
        let selectedLayers = layers[indices]

        guard
            !selectedLayers.isEmpty,
            let firstLayer = selectedLayers.first,
            let firstData = try? firstLayer.render(),
            let firstImage = UIImage(data: firstData)
        else {
            return UIImage()
        }

        let size = CGSize(width: width, height: height)
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { _ in
            firstImage.draw(in: CGRect(origin: .zero, size: size))

            for layer in selectedLayers.dropFirst() {
                guard
                    let data = try? layer.render(),
                    let image = UIImage(data: data)
                else {
                    continue
                }
                image.draw(in: CGRect(origin: .zero, size: size))
            }
        }
    }
}
