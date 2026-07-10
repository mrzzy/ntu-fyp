//
//  LayerTests.swift
//  brocheTests
//
//  Created by Zhu Zhanyan on 7/10/26.
//

@testable import broche
import PencilKit
import Testing
import UIKit

@Suite("Layer rendering tests")
struct LayerTests {
    @Test("Drawing layer renders as PNG data")
    func drawingLayerRendersAsPNGData() throws {
        let drawing = PKDrawing()
        let layer = Layer.drawing(drawing: drawing)

        #expect(throws: LayerError.self) {
            try layer.render()
        }
    }

    @Test("Image layer returns original data")
    func imageLayerReturnsOriginalData() throws {
        let originalData = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        let layer = Layer.image(data: originalData)

        let result = try layer.render()

        #expect(result == originalData, "Image layer should return original data")
    }

    @Test("Drawing layer with strokes renders successfully")
    func drawingLayerWithStrokesRendersSuccessfully() throws {
        let drawing = PKDrawing()
        let layer = Layer.drawing(drawing: drawing)

        #expect(throws: LayerError.self) {
            try layer.render()
        }
    }

    @Test("Empty PNG data in image layer returns same data")
    func emptyPNGDataInImageLayerReturnsSameData() throws {
        let emptyData = Data()
        let layer = Layer.image(data: emptyData)

        let result = try layer.render()

        #expect(result.isEmpty, "Empty data should be returned as-is")
        #expect(result == emptyData)
    }

    @Test("Layer image with valid PNG data passes through")
    func layerImageWithValidPNGDataPassesThrough() throws {
        let pngData = try createTestPNGImage(size: CGSize(width: 100, height: 100))
        let layer = Layer.image(data: pngData)

        let result = try layer.render()

        #expect(result.count > 0, "Valid PNG data should return non-empty result")
    }
}

extension LayerTests {
    private func createTestPNGImage(size: CGSize) throws -> Data {
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        return try #require(image.pngData())
    }
}

@Suite("Sketch image generation tests")
struct SketchTests {
    @Test("Sketch with no layers returns nil image")
    func sketchWithNoLayersReturnsNilImage() {
        let sketch = Sketch(title: "Empty", layers: [])

        #expect(sketch.image == nil, "Empty sketch should return nil image")
    }

    @Test("Sketch with single drawing layer renders image")
    func sketchWithSingleDrawingLayerRendersImage() {
        let drawing = PKDrawing()
        let sketch = Sketch(title: "Single Drawing", layers: [.drawing(drawing: drawing)])

        #expect(sketch.image == nil, "Empty drawing should render nil")
    }

    @Test("Sketch with single image layer renders image")
    func sketchWithSingleImageLayerRendersImage() throws {
        let imageData = try createTestPNGImage(size: CGSize(width: 100, height: 100))
        let sketch = Sketch(title: "Single Image", layers: [.image(data: imageData)])

        let image = sketch.image
        #expect(image != nil, "Sketch with image should render")
    }

    @Test("Sketch composites multiple layers correctly")
    func sketchCompositesMultipleLayersCorrectly() throws {
        let drawing1 = PKDrawing()
        let drawing2 = PKDrawing()
        let imageData = try createTestPNGImage(size: CGSize(width: 200, height: 200))

        let sketch = Sketch(
            title: "Multiple Layers",
            layers: [
                .image(data: imageData),
                .drawing(drawing: drawing1),
                .drawing(drawing: drawing2),
            ]
        )

        let image = try #require(sketch.image, "Multiple layers should composite")
        #expect(image.size.width > 0 && image.size.height > 0)
    }

    @Test("Sketch skips layers that fail to render")
    func sketchSkipsLayersThatFailToRender() throws {
        let imageData = try createTestPNGImage(size: CGSize(width: 100, height: 100))
        let drawing = PKDrawing()

        let sketch = Sketch(
            title: "Mixed Layers",
            layers: [
                .image(data: imageData),
                .drawing(drawing: drawing),
                .image(data: Data()),
            ]
        )

        let image = sketch.image
        #expect(image != nil, "Should render despite invalid layer")
    }

    @Test("Sketch with only invalid layers returns nil")
    func sketchWithOnlyInvalidLayersReturnsNil() {
        let sketch = Sketch(
            title: "Invalid Only",
            layers: [
                .image(data: Data()),
                .image(data: Data([0x00])),
            ]
        )

        #expect(sketch.image == nil, "Sketch with only invalid layers should return nil")
    }

    @Test("Sketch composites in layer order")
    func sketchCompositesInLayerOrder() throws {
        let bottomLayerData = try createTestPNGImage(
            size: CGSize(width: 100, height: 100), color: .red
        )
        let topLayerData = try createTestPNGImage(
            size: CGSize(width: 100, height: 100), color: .blue
        )

        let sketch = Sketch(
            title: "Layer Order",
            layers: [
                .image(data: bottomLayerData),
                .image(data: topLayerData),
            ]
        )

        let image = sketch.image
        #expect(image != nil, "Should composite layers in order")
    }

    @Test("Sketch handles complex drawing with multiple strokes")
    func sketchHandlesComplexDrawingWithMultipleStrokes() {
        let drawing = PKDrawing()

        let sketch = Sketch(title: "Complex Drawing", layers: [.drawing(drawing: drawing)])

        #expect(sketch.image == nil, "Empty drawing should render nil")
    }
}

extension SketchTests {
    private func createTestPNGImage(size: CGSize, color: UIColor = .white) throws -> Data {
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        return try #require(image.pngData())
    }
}
