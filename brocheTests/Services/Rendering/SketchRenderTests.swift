//
//  SketchRenderTests.swift
//  brocheTests
//
//  Created by Zhu Zhanyan on 2026-07-05.
//

import PencilKit
import Testing
import UIKit

@testable import broche

@Suite("SketchRender tests")
struct SketchRenderTests {
    @Test("Renderer with no layers throws noLayersToRender")
    func noLayersThrowsNoLayersToRender() {
        let sketch = Sketch(
            title: "Empty",
            layers: [],
            size: CGSize(width: 512, height: 512)
        )

        #expect(throws: SketchRenderError.noLayersToRender) {
            try sketch.render.image
        }
    }

    @Test("Renderer throws noLayersToRender for empty range")
    func emptyRangeThrowsNoLayersToRender() throws {
        let imageData = try createTestPNGImage(size: CGSize(width: 100, height: 100))
        let sketch = Sketch(
            title: "One Layer",
            layers: [.image(data: imageData)],
            size: CGSize(width: 512, height: 512)
        )

        #expect(throws: SketchRenderError.noLayersToRender) {
            try sketch.render.renderLayers(indices: 1..<1)
        }
    }

    @Test("Rendering single empty drawing layer succeeds")
    func singleDrawingLayerRenders() throws {
        let sketch = Sketch(
            title: "Single Drawing",
            layers: [.drawing(drawing: TestFixtures.drawing)],
            size: CGSize(width: 512, height: 512)
        )

        let image = try sketch.render.image

        #expect(image.size.width == 512)
        #expect(image.size.height == 512)
    }

    @Test("Rendering single image layer succeeds")
    func singleImageLayerRenders() throws {
        let imageData = try createTestPNGImage(size: CGSize(width: 100, height: 100))
        let sketch = Sketch(
            title: "Single Image",
            layers: [.image(data: imageData)],
            size: CGSize(width: 512, height: 512)
        )

        let image = try sketch.render.image

        #expect(image.size.width == 512)
        #expect(image.size.height == 512)
    }

    @Test("Renderer composites multiple layers correctly")
    func compositesMultipleLayers() throws {
        let imageData = try createTestPNGImage(size: CGSize(width: 200, height: 200))
        let sketch = Sketch(
            title: "Multiple Layers",
            layers: [
                .image(data: imageData),
                .drawing(drawing: TestFixtures.drawing),
                .drawing(drawing: TestFixtures.drawing),
            ],
            size: CGSize(width: 512, height: 512)
        )

        let image = try sketch.render.image

        #expect(image.size.width == 512)
        #expect(image.size.height == 512)
    }

    @Test("Renderer throws when a layer contains invalid image data")
    func throwsWhenLayerFailsToDecode() throws {
        let validImageData = try createTestPNGImage(size: CGSize(width: 100, height: 100))
        let sketch = Sketch(
            title: "Mixed Layers",
            layers: [
                .image(data: validImageData),
                .drawing(drawing: TestFixtures.drawing),
                .image(data: Data()),
            ],
            size: CGSize(width: 512, height: 512)
        )

        #expect(throws: SketchRenderError.emptyRenderedImage) {
            try sketch.render.image
        }
    }

    @Test("Renderer throws when all image layers are invalid")
    func onlyInvalidImageLayersThrows() {
        let sketch = Sketch(
            title: "Invalid Only",
            layers: [
                .image(data: Data()),
                .image(data: Data([0x00])),
            ],
            size: CGSize(width: 512, height: 512)
        )

        #expect(throws: SketchRenderError.emptyRenderedImage) {
            try sketch.render.image
        }
    }

    @Test("Renderer composites layers in order")
    func compositesInLayerOrder() throws {
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

        let image = try sketch.render.image

        #expect(image.size.width == 512)
        #expect(image.size.height == 512)
    }

    @Test("Renderer with empty drawing layer renders successfully")
    func handlesEmptyDrawing() throws {
        let sketch = Sketch(
            title: "Empty Drawing",
            layers: [.drawing(drawing: TestFixtures.drawing)],
            size: CGSize(width: 512, height: 512)
        )

        let image = try sketch.render.image

        #expect(image.size.width == 512)
        #expect(image.size.height == 512)
    }

    // MARK: - Partial rendering

    @Test("Rendering a subset of layers succeeds")
    func partialRenderSucceeds() throws {
        let bottomData = try createTestPNGImage(size: CGSize(width: 100, height: 100))
        let middleData = try createTestPNGImage(size: CGSize(width: 100, height: 100))
        let topData = try createTestPNGImage(size: CGSize(width: 100, height: 100))

        let sketch = Sketch(
            title: "Partial",
            layers: [
                .image(data: bottomData),
                .image(data: middleData),
                .image(data: topData),
            ],
            size: CGSize(width: 512, height: 512)
        )

        let image = try sketch.render.renderLayers(indices: 0..<2)

        #expect(image.size.width == 512)
        #expect(image.size.height == 512)
    }

    @Test("Rendering last layer only succeeds")
    func renderLastLayerOnly() throws {
        let bottomData = try createTestPNGImage(size: CGSize(width: 100, height: 100))
        let topData = try createTestPNGImage(size: CGSize(width: 100, height: 100))

        let sketch = Sketch(
            title: "Last Only",
            layers: [
                .image(data: bottomData),
                .image(data: topData),
            ],
            size: CGSize(width: 512, height: 512)
        )

        let image = try sketch.render.renderLayers(indices: 1..<2)

        #expect(image.size.width == 512)
        #expect(image.size.height == 512)
    }

    // MARK: - Caching

    @Test("cachedImage returns same instance within TTL")
    func cachedImageReturnsSameWithinTTL() throws {
        let sketch = Sketch(
            title: "Cached",
            layers: [.drawing(drawing: TestFixtures.drawing)],
            size: CGSize(width: 512, height: 512)
        )

        let first = try sketch.render.cachedImage
        let second = try sketch.render.cachedImage

        #expect(first === second)
    }

    @Test("Layer cache returns same instance for same range")
    func layerCacheReturnsSameForSameRange() throws {
        let bottomData = try createTestPNGImage(size: CGSize(width: 100, height: 100))
        let topData = try createTestPNGImage(size: CGSize(width: 100, height: 100))

        let sketch = Sketch(
            title: "Layer Cache",
            layers: [
                .image(data: bottomData),
                .image(data: topData),
            ],
            size: CGSize(width: 512, height: 512)
        )

        let first = try sketch.render.renderLayers(indices: 0..<2)
        let second = try sketch.render.renderLayers(indices: 0..<2)

        #expect(first === second)
    }

    @Test("Modified layer invalidates render cache")
    func modifiedLayerInvalidatesCache() throws {
        let bottomData = try createTestPNGImage(size: CGSize(width: 100, height: 100))
        let topData = try createTestPNGImage(size: CGSize(width: 100, height: 100))

        let sketch = Sketch(
            title: "Stale Cache",
            layers: [
                .image(data: bottomData),
                .image(data: topData),
            ],
            size: CGSize(width: 512, height: 512)
        )

        let first = try sketch.render.renderLayers(indices: 0..<2)

        let newData = try createTestPNGImage(size: CGSize(width: 100, height: 100), color: .red)
        sketch.setLayer(at: 0, to: .image(data: newData, modifiedOn: .now))

        let second = try sketch.render.renderLayers(indices: 0..<2)

        #expect(first !== second)
    }

    @Test("Renderer output matches sketch dimensions")
    func outputMatchesSketchDimensions() throws {
        let testSize = CGSize(width: 256, height: 1024)
        let sketch = Sketch(
            title: "Non-square",
            layers: [.drawing(drawing: TestFixtures.drawing)],
            size: testSize
        )

        let image = try sketch.render.image

        #expect(image.size == testSize)
    }
}

extension SketchRenderTests {
    private func createTestPNGImage(
        size: CGSize,
        color: UIColor = .white
    ) throws -> Data {
        let renderer = UIGraphicsImageRenderer(size: size)

        let image = renderer.image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }

        return try #require(image.pngData())
    }
}
