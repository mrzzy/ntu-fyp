//
//  Sketch.swift
//  broche
//
//  Created by Zhu Zhanyan on 2026-07-05.
//

import Foundation
import PencilKit
import SwiftData

/// Zoom
struct Zoom: Codable {
    var scale: Double
    var offsetX: Double
    var offsetY: Double
    var rotation: Double
    init(scale: Double = 1.0, offsetX: Double = 0.0, offsetY: Double = 0.0, rotation: Double = 0.0) {
        self.scale = scale
        self.offsetX = offsetX
        self.offsetY = offsetY
        self.rotation = rotation
    }
}

/// Defines a set of default layers a sketch starts with.
let SketchDefaultLayers: [Layer] = [
    .drawing(drawing: PKDrawing()),
]

/// Defines a sketch composed of a series of layers
@Model
final class Sketch: CustomStringConvertible {
    var title: String

    @Attribute(originalName: "layers")
    private var _layers: [Layer]
    // dimensions of the sketch
    private(set) var width: Double
    private(set) var height: Double

    /// AI assistant conversation messages
    @Relationship(deleteRule: .cascade)
    var messages: [Message]

    /// Returns the messages sorted in chronological order (oldest first)
    var orderedMessages: [Message] {
        messages.sorted { $0.createdAt < $1.createdAt }
    }

    /// Zoom view zoom/pan/rotation state
    var zoom: Zoom = Zoom()

    var layers: [Layer] {
        _layers
    }

    /// When the sketch was last modified
    private var layersModifiedOn: Date = Date.distantPast

    var modifiedOn: Date {
        // max modified timestamp of all layers + layers array itself
        max(layers.map { $0.modifiedOn }.max() ?? .distantPast, layersModifiedOn)
    }

    var size: CGSize {
        CGSize(width: width, height: height)
    }

    var description: String {
        let layerDescriptions = layers.enumerated().map { index, layer in
            "  [\(index)] \(layer.description)"
        }.joined(separator: "\n")

        return """
        Sketch: \(title) 
        Dimensions: (\(Int(width))x\(Int(height)))
        Total Layers: \(layers.count)
        Layers:
        \(layerDescriptions)
        """
    }

    @Transient private var _renderer: SketchRender?
    var render: SketchRender {
        // create renderer on first access
        guard let r = _renderer else {
            let r = SketchRender(sketch: self)
            _renderer = r
            return r
        }
        return r
    }

    init(
        title: String = "Untitled", layers: [Layer] = SketchDefaultLayers,
        size: CGSize = CGSize(width: 512, height: 512),
        messages: [Message] = []
    ) {
        self.title = title
        _layers = layers
        self.messages = messages
        width = size.width
        height = size.height
    }

    /// Layer modification methods
    func addLayer(_ layer: Layer) {
        _layers.append(layer)
        layersModifiedOn = Date.now
    }

    func removeLayer(at index: Int) {
        _layers.remove(at: index)
        layersModifiedOn = Date.now
    }

    func setLayer(at index: Int, to layer: Layer) {
        _layers[index] = layer
    }
}
