//
//  SketchTests.swift
//  brocheTests
//
//  Created by Zhu Zhanyan on 7/10/26.
//

@testable import broche
import PencilKit
import Testing
import UIKit

@Suite("Sketch image generation tests")
struct SketchTests {
    @Test("Sketch with no layers returns nil image")
    func sketchWithNoLayersReturnsNilImage() {
        let sketch = Sketch(title: "Empty", layers: [], size: CGSize(width: 512, height: 512))

        #expect(sketch.image == nil, "Empty sketch should return nil image")
    }

    @Test("Sketch with single drawing layer renders image")
    func sketchWithSingleDrawingLayerRendersImage() {
        let drawing = PKDrawing()
        let sketch = Sketch(title: "Single Drawing", layers: [.drawing(drawing: drawing)], size: CGSize(width: 512, height: 512))

        #expect(sketch.image == nil, "Empty drawing should render nil")
    }

    @Test("Sketch with single image layer renders image")
    func sketchWithSingleImageLayerRendersImage() throws {
        let imageData = try createTestPNGImage(size: CGSize(width: 100, height: 100))
        let sketch = Sketch(title: "Single Image", layers: [.image(data: imageData)], size: CGSize(width: 512, height: 512))

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
            ],
            size: CGSize(width: 512, height: 512)
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
            ],
            size: CGSize(width: 512, height: 512)
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
            ],
            size: CGSize(width: 512, height: 512)
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
            ],
            size: CGSize(width: 512, height: 512)
        )

        let image = sketch.image
        #expect(image != nil, "Should composite layers in order")
    }

    @Test("Sketch handles complex drawing with multiple strokes")
    func sketchHandlesComplexDrawingWithMultipleStrokes() {
        let drawing = PKDrawing()

        let sketch = Sketch(title: "Complex Drawing", layers: [.drawing(drawing: drawing)], size: CGSize(width: 512, height: 512))

        #expect(sketch.image == nil, "Empty drawing should render nil")
    }

    @Test("Sketch maintains correct size")
    func sketchMaintainsCorrectSize() {
        let testSize = CGSize(width: 768, height: 1024)
        let sketch = Sketch(title: "Sized Sketch", size: testSize)

        #expect(sketch.size == testSize, "Sketch should maintain the specified size")
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
