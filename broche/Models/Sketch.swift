//
//  Sketch.swift
//  broche
//
//  Created by Zhu Zhanyan on 2026-07-05.
//

import Foundation
import SwiftData
import UIKit

/// Defines a sketch composed of a series of layers
@Model
class Sketch: Identifiable, Hashable {
    @Attribute(.unique)
    var id: UUID
    var title: String
    var layers: [Layer]

    init(title: String, layers: [Layer] = [], id: UUID = UUID()) {
        self.title = title
        self.layers = layers
        self.id = id
    }

    /// Renders the sketch into a single flattened image by compositing all
    /// layers in order.
    ///
    /// Layers are drawn sequentially, with each subsequent layer composited on
    /// top of the previous ones. If the sketch contains no layers, this
    /// property returns `nil`.
    ///
    /// - Returns: A `UIImage` representing the flattened sketch, or `nil` if
    ///   the sketch has no layers.
    var image: UIImage? {
        // image renders all layers
        return renderLayers(indices: 0 ..< layers.count)
    }

    /// Renders only the selected layers
    /// indices: Range<Int> - the range of layer indices to render
    ///
    /// Layers are drawn sequentially, with each subsequent layer composited on
    /// top of the previous ones. If the sketch contains no layers, this
    /// property returns `nil`.
    ///
    /// - Returns: A `UIImage` representing the flattened sketch, or `nil` if
    ///   the sketch has no layers.
    func renderLayers(indices: Range<Int>) -> UIImage? {
        let selectedLayers = layers[indices]

        guard
            !selectedLayers.isEmpty,
            let firstLayer = selectedLayers.first,
            let firstData = try? firstLayer.render(),
            let firstImage = UIImage(data: firstData)
        else {
            return UIImage()
        }

        let size = firstImage.size
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
