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
            )
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

    static let sketch: Sketch = {
        let appleSketchURL = Bundle.main.url(
            forResource: "apple_sketch",
            withExtension: "png"
        )!
        let appleSketchData = try! Data(contentsOf: appleSketchURL)

        return Sketch(
            title: "Apple Sketch",
            layers: [
                .image(data: appleSketchData),
                .drawing(drawing: TestFixtures.drawing),
            ],
            size: CGSize(width: 512, height: 512)
        )
    }()
}
