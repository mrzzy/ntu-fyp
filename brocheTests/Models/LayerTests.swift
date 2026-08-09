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

    @Test("Image layer returns original data")
    func imageLayerReturnsOriginalData() throws {
        let originalData = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        let layer = Layer.image(data: originalData)

        let result = try layer.render()

        #expect(result == originalData, "Image layer should return original data")
    }

    @Test("Drawing layer with strokes renders successfully")
    func drawingLayerWithStrokesRendersSuccessfully() throws {
        let drawing = TestFixtures.drawing
        let layer = Layer.drawing(drawing: drawing)

        try layer.render()
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
