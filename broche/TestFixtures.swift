//
//  TestFixtures.swift
//  broche
//
//  Created by Zhu Zhanyan on 2026-07-05.
//
import PencilKit

/// Test Fixtures
enum TestFixtures {
    /// A simple drawing with a single stroke from (100, 100) to (400, 400).
    static let drawing: PKDrawing = {
        let points = [
            PKStrokePoint(
                location: CGPoint(x: 100, y: 100),
                timeOffset: 0,
                size: CGSize(width: 10, height: 10),
                opacity: 1,
                force: 1,
                azimuth: 0,
                altitude: .pi / 2
            ),
            PKStrokePoint(
                location: CGPoint(x: 400, y: 400),
                timeOffset: 0.1,
                size: CGSize(width: 10, height: 10),
                opacity: 1,
                force: 1,
                azimuth: 0,
                altitude: .pi / 2
            ),
        ]

        let path = PKStrokePath(
            controlPoints: points,
            creationDate: Date()
        )

        return PKDrawing(strokes: [
            PKStroke(
                ink: PKInk(.pen, color: .black),
                path: path
            )
        ])
    }()

    static let appleSketchData: Data = loadBundlePNG("apple_sketch")
    static let appleAIOil: Data = loadBundlePNG("apple_ai_oil")
    static let appleAIOilEdit: Data = loadBundlePNG("apple_ai_oil_edit")

    static let sketch: Sketch = .init(
        title: "Apple Sketch",
        layers: [
            .image(data: TestFixtures.appleSketchData),
            .drawing(drawing: TestFixtures.drawing),
        ],
        size: CGSize(width: 512, height: 512)
    )

    private static func loadBundlePNG(_ path: String) -> Data {
        let url = Bundle.main.url(forResource: path, withExtension: "png")!
        return UIImage(contentsOfFile: url.path())!.pngData()!
    }
}
