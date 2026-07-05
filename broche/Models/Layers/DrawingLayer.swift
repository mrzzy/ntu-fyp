//
//  DrawingLayer.swift
//  broche
//
//  Created by Zhu Zhanyan on 2026-07-05.
//

import PencilKit
import UIKit

/// Layer that hosts a PencilKit drawing
struct DrawingLayer: Layer {
    /// PencilKit drawing stored in this layer
    var drawing: PKDrawing


    /// Size of the canvas for the drawing
    var size: CGSize

    /// Initialize with a PKDrawing
    /// - Parameters:
    ///   - drawing: The PencilKit drawing to store
    ///   - size: Size of the canvas
    ///   - backgroundColor: Background color for the drawing
    init(drawing: PKDrawing, size: CGSize, backgroundColor: UIColor = .clear) {
        self.drawing = drawing
        self.size = size
    }

    /// Initialize with PKDrawing data
    /// - Parameters:
    ///   - drawingData: Binary data of the PKDrawing
    ///   - size: Size of the canvas
    ///   - backgroundColor: Background color for the drawing
    init(drawingData: Data, size: CGSize, backgroundColor: UIColor = .clear) {
        self.drawing = (try? PKDrawing(data: drawingData)) ?? PKDrawing()
        self.size = size
    }

    /// Render this layer as image data
    /// - Returns: PNG-encoded image data representing the rendered drawing
    func render() throws -> Data {
        if let data =  drawing.image(from: CGRect(origin: .zero, size: size), scale: 1.0).pngData() {
            return data
        } 
        throw LayerError.renderError(reason: "Failed to render PKDrawing as PNG image data.")
    }
}
