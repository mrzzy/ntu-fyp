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
class Sketch: Codable, Equatable {
    var layers: [Layer] = []
    enum CodingKeys: String, CodingKey {
        case layers
    }

    init() {}

    required init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typedLayers = try container.decode([TypedLayer].self, forKey: .layers)
        layers = try typedLayers.compactMap { try $0.decode() }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let layersData = try layers.map { try TypedLayer(layer: $0) }
        try container.encode(layersData, forKey: .layers)
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
    var renderedImage: UIImage? {
        guard
            let firstLayer = layers.first,
            let firstData = try? firstLayer.render(),
            let firstImage = UIImage(data: firstData)
        else {
            return nil
        }

        let size = firstImage.size
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { _ in
            firstImage.draw(in: CGRect(origin: .zero, size: size))

            for layer in layers.dropFirst() {
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

    static func == (lhs: Sketch, rhs: Sketch) -> Bool {
        lhs.layers.count == rhs.layers.count
    }
}
