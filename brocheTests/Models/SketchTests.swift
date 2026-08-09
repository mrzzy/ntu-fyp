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
    @Test("Sketch with no layers throws noLayersToRender")
    func sketchWithNoLayersThrowsNoLayersToRender() {
        let sketch = Sketch(
            title: "Empty",
            layers: [],
            size: CGSize(width: 512, height: 512)
        )

        #expect(throws: SketchError.noLayersToRender) {
            try sketch.image
        }
    }

    @Test("Sketch with single empty drawing layer renders successfully")
    func sketchWithSingleDrawingLayerRendersImage() throws {
        let drawing = TestFixtures.drawing
        let sketch = Sketch(
            title: "Single Drawing",
            layers: [.drawing(drawing: drawing)],
            size: CGSize(width: 512, height: 512)
        )

        let image = try sketch.image

        #expect(image.size.width == 512)
        #expect(image.size.height == 512)
    }

    @Test("Sketch with single image layer renders image")
    func sketchWithSingleImageLayerRendersImage() throws {
        let imageData = try createTestPNGImage(
            size: CGSize(width: 100, height: 100)
        )

        let sketch = Sketch(
            title: "Single Image",
            layers: [.image(data: imageData)],
            size: CGSize(width: 512, height: 512)
        )

        let image = try sketch.image

        #expect(image.size.width == 512)
        #expect(image.size.height == 512)
    }

    @Test("Sketch composites multiple layers correctly")
    func sketchCompositesMultipleLayersCorrectly() throws {
        let imageData = try createTestPNGImage(
            size: CGSize(width: 200, height: 200)
        )

        let sketch = Sketch(
            title: "Multiple Layers",
            layers: [
                .image(data: imageData),
                .drawing(drawing: TestFixtures.drawing),
                .drawing(drawing: TestFixtures.drawing),
            ],
            size: CGSize(width: 512, height: 512)
        )

        let image = try sketch.image

        #expect(image.size.width == 512)
        #expect(image.size.height == 512)
    }

    @Test("Sketch throws when a layer contains invalid image data")
    func sketchThrowsWhenLayerFailsToDecode() throws {
        let validImageData = try createTestPNGImage(
            size: CGSize(width: 100, height: 100)
        )

        let sketch = Sketch(
            title: "Mixed Layers",
            layers: [
                .image(data: validImageData),
                .drawing(drawing: TestFixtures.drawing),
                .image(data: Data()),
            ],
            size: CGSize(width: 512, height: 512)
        )

        #expect(throws: SketchError.emptyRenderedImage) {
            try sketch.image
        }
    }

    @Test("Sketch with only invalid image layers throws emptyRenderedImage")
    func sketchWithOnlyInvalidLayersThrowsEmptyRenderedImage() {
        let sketch = Sketch(
            title: "Invalid Only",
            layers: [
                .image(data: Data()),
                .image(data: Data([0x00])),
            ],
            size: CGSize(width: 512, height: 512)
        )

        #expect(throws: SketchError.emptyRenderedImage) {
            try sketch.image
        }
    }

    @Test("Sketch composites layers in order")
    func sketchCompositesInLayerOrder() throws {
        let bottomLayerData = try createTestPNGImage(
            size: CGSize(width: 100, height: 100),
            color: .red
        )

        let topLayerData = try createTestPNGImage(
            size: CGSize(width: 100, height: 100),
            color: .blue
        )

        let sketch = Sketch(
            title: "Layer Order",
            layers: [
                .image(data: bottomLayerData),
                .image(data: topLayerData),
            ],
            size: CGSize(width: 512, height: 512)
        )

        let image = try sketch.image

        #expect(image.size.width == 512)
        #expect(image.size.height == 512)
    }

    @Test("Sketch with empty drawing layer renders successfully")
    func sketchHandlesEmptyDrawing() throws {
        let drawing = TestFixtures.drawing

        let sketch = Sketch(
            title: "Empty Drawing",
            layers: [.drawing(drawing: drawing)],
            size: CGSize(width: 512, height: 512)
        )

        let image = try sketch.image

        #expect(image.size.width == 512)
        #expect(image.size.height == 512)
    }

    @Test("Sketch maintains correct size")
    func sketchMaintainsCorrectSize() {
        let testSize = CGSize(width: 768, height: 1024)

        let sketch = Sketch(
            title: "Sized Sketch",
            size: testSize
        )

        #expect(sketch.size == testSize)
    }
}

extension SketchTests {
    private func createTestPNGImage(
        size: CGSize,
        color: UIColor = .white
    ) throws -> Data {
        let renderer = UIGraphicsImageRenderer(size: size)

        let image = renderer.image { context in
            color.setFill()
            context.fill(
                CGRect(origin: .zero, size: size)
            )
        }

        return try #require(image.pngData())
    }
}
