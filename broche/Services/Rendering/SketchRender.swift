//
//  SketchRender.swift
//  broche
//
//  Created by Zhu Zhanyan on 2026-07-05.
//

import Foundation
import UIKit

/// Errors that can occur during sketch rendering.
enum SketchRenderError: Error, LocalizedError {
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

struct RenderCache {
    let image: UIImage
    let cachedOn: Date
}

/// Renders a ``Sketch`` into composited images by flattening its layers in order.
///
/// `SketchRender` caches full render calls keyed by layer range to avoid redundant compositing.
///
final class SketchRender {
    private unowned let sketch: Sketch

    private var layerCache: [Range<Int>: RenderCache] = [:]

    private var _cachedImage: UIImage = .init()
    private var _cachedImageAt: ContinuousClock.Instant?

    /// Creates a renderer bound to the given sketch.
    ///
    /// The renderer reads layers and dimensions directly from the sketch,
    /// so changes to the sketch are automatically picked up on the next render.
    init(sketch: Sketch) {
        self.sketch = sketch
    }

    /// Renders all layers of the sketch into a single flattened image.
    ///
    /// Convenience wrapper that calls ``renderLayers(indices:)`` with the full
    /// layer range `0 ..< sketch.layers.count`.
    ///
    /// - Throws: ``SketchRenderError/noLayersToRender`` when the sketch has no layers,
    ///           or ``SketchRenderError/emptyRenderedImage`` when a layer fails to decode.
    /// - Returns: A `UIImage` of the sketch at the sketch's configured dimensions.
    var image: UIImage {
        get throws { try renderLayers(indices: 0..<sketch.layers.count) }
    }

    /// Returns a cached composite image of the sketch, re-rendering if the cache has expired.
    ///
    /// The cached image is valid for 5 seconds after the last render. If the cache
    /// has expired, the sketch is re-rendered and the cache is updated.
    ///
    /// - Throws: Same errors as ``image``.
    var cachedImage: UIImage {
        get throws {
            if let cachedAt = _cachedImageAt,
                ContinuousClock.now - cachedAt < Duration.seconds(5)
            {
                return _cachedImage
            }

            let renderedImage = try renderLayers(indices: 0..<sketch.layers.count)
            _cachedImage = renderedImage
            _cachedImageAt = ContinuousClock.now
            return renderedImage
        }
    }

    /// Renders a subset of layers identified by `indices` into a single flattened image.
    ///
    /// The composite result is cached by `indices`. A cache entry is considered
    /// valid when no layer in the range has been modified since it was cached.
    ///
    /// - Parameter indices: The range of layer indices to render.
    /// - Throws: ``SketchRenderError/noLayersToRender`` when the range is empty,
    ///           or ``SketchRenderError/emptyRenderedImage`` when a layer fails to decode.
    /// - Returns: A `UIImage` of the selected layers at the sketch's configured dimensions.
    func renderLayers(indices: Range<Int>) throws -> UIImage {
        // return cached entry if not scale
        if let cache = layerCache[indices],
            sketch.layers[indices].allSatisfy({ $0.modifiedOn <= cache.cachedOn })
        {
            return cache.image
        }

        let layers = sketch.layers[indices]

        guard layers.first != nil else {
            throw SketchRenderError.noLayersToRender
        }

        // render layers as images
        var images: [UIImage] = []
        let size = sketch.size
        for layer in layers {
            let data = try layer.render(size: size)
            guard let image = UIImage(data: data) else {
                throw SketchRenderError.emptyRenderedImage
            }
            images.append(image)
        }

        // composite layers as a single image
        let renderer = UIGraphicsImageRenderer(size: size)
        let composited = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            for image in images {
                image.draw(in: CGRect(origin: .zero, size: size))
            }
        }

        // cache layer for fture accesses
        layerCache[indices] = RenderCache(image: composited, cachedOn: .now)
        return composited
    }
}
