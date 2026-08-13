//
//  SketchTests.swift
//  brocheTests
//
//  Created by Zhu Zhanyan on 7/10/26.
//

@testable import broche
import Testing
import UIKit

private let epsilon = 1e-10

@Suite("Sketch model tests")
struct SketchTests {
    @Test("Sketch with default init has correct defaults")
    func defaultInitHasCorrectDefaults() {
        let sketch = Sketch()

        #expect(sketch.title == "Untitled")
        #expect(sketch.layers.count == 1)
        #expect(sketch.size == CGSize(width: 512, height: 512))
        #expect(abs(sketch.zoom.scale - 1.0) < epsilon)
    }

    @Test("Sketch maintains correct size")
    func sketchMaintainsCorrectSize() {
        let testSize = CGSize(width: 768, height: 1024)

        let sketch = Sketch(
            title: "Sized Sketch",
            size: testSize
        )

        #expect(sketch.size == testSize)
        #expect(abs(sketch.width - testSize.width) < epsilon)
        #expect(abs(sketch.height - testSize.height) < epsilon)
    }

    @Test("Sketch description includes title and layer info")
    func descriptionIncludesTitleAndLayers() {
        let sketch = Sketch(
            title: "Test Sketch",
            layers: [.drawing(), .drawing()],
            size: CGSize(width: 100, height: 200)
        )

        let desc = sketch.description

        #expect(desc.contains("Test Sketch"))
        #expect(desc.contains("100"))
        #expect(desc.contains("200"))
        #expect(desc.contains("2"))
    }

    @Test("Sketch with custom title stores title")
    func customTitleStored() {
        let sketch = Sketch(title: "My Art")

        #expect(sketch.title == "My Art")
    }

    @Test("Sketch with custom layers stores layers")
    func customLayersStored() {
        let sketch = Sketch(layers: [])

        #expect(sketch.layers.isEmpty)
    }

    @Test("Sketch zoom has default values")
    func zoomHasDefaults() {
        let sketch = Sketch()

        #expect(abs(sketch.zoom.scale - 1.0) < epsilon)
        #expect(abs(sketch.zoom.offsetX - 0.0) < epsilon)
        #expect(abs(sketch.zoom.offsetY - 0.0) < epsilon)
        #expect(abs(sketch.zoom.rotation - 0.0) < epsilon)
    }

    @Test("addLayer appends a layer")
    func addLayerAppendsLayer() {
        let sketch = Sketch(layers: [])

        sketch.addLayer(.drawing())

        #expect(sketch.layers.count == 1)
    }

    @Test("removeLayer removes layer at index")
    func removeLayerRemovesAtIndex() {
        let sketch = Sketch(layers: [.drawing(), .drawing()])

        sketch.removeLayer(at: 0)

        #expect(sketch.layers.count == 1)
    }

    @Test("updateLayer replaces layer at index")
    func updateLayerReplacesAtIndex() {
        let sketch = Sketch(layers: [.drawing()])

        sketch.setLayer(at: 0, to: .image(data: Data()))

        if case .image = sketch.layers[0] {
        } else {
            Issue.record("Expected image layer after update")
        }
    }
}
