//
// SketchDetailView.swift
// broche
//
// Created by Zhu Zhanyan on 2026-07-10.
//

import PencilKit
import SwiftData
import SwiftUI

/// Presents the sketch to the user with a DrawView overlaid to capture user's drawing strokes
struct SketchDetailView: View {
    let sketch: Sketch?
    let isEnabled: Bool

    @Environment(\.modelContext) private var modelContext

    init(sketch: Sketch?, isEnabled: Bool = true) {
        self.sketch = sketch
        self.isEnabled = isEnabled
    }

    var body: some View {
        if let sketch = sketch {
            let nLayers = sketch.layers.count
            // composite all layers except last layer in 1 image
            let backgroundLayers =
                if nLayers > 1 {
                    sketch.renderLayers(indices: 0 ..< sketch.layers.count - 1)
                } else {
                    UIImage()
                }

            // render sketch
            ZoomableScrollView(
                scale: Binding(
                    get: { sketch.zoom.scale },
                    set: { sketch.zoom.scale = $0 }
                ),
                offset: Binding(
                    get: { CGPoint(x: sketch.zoom.offsetX, y: sketch.zoom.offsetY) },
                    set: { sketch.zoom.offsetX = $0.x; sketch.zoom.offsetY = $0.y }
                ),
                rotation: Binding(
                    get: { .radians(sketch.zoom.rotation) },
                    set: { sketch.zoom.rotation = $0.radians }
                )
            ) {
                rotation in
                ZStack {
                    // white drawing background
                    Color.white

                    // render all layers except final layer as an image
                    Image(uiImage: backgroundLayers)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    // render final layer
                    renderLayer(sketch, layer: sketch.layers.count - 1)
                }
                // rotate sketch as per ZoomableScrollView instructions
                .rotationEffect(rotation)
                // bound sketch by preset sketch size
                .frame(width: sketch.size.width, height: sketch.size.height)
            }
            // reset zoom scroll settings for each new sketch by replacing ZoomableScrollView
            .id(sketch.id)
        } else {
            Text("Sketch not found")
        }
    }

    private func renderLayer(_ sketch: Sketch, layer: Int) -> some View {
        Group {
            switch sketch.layers[layer] {
            case let .image(data):
                if let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                }
            case let .drawing(drawing):
                GeometryReader { proxy in
                    DrawingCanvasView(
                        drawing:
                        Binding(
                            get: { drawing },
                            set: { newDrawing in
                                // sync drawing changes back to model
                                sketch.layers[layer] = .drawing(drawing: newDrawing)
                                do {
                                    try modelContext.save()
                                } catch {
                                    print("Warning: Failed to save drawing changes")
                                }
                            }
                        ),
                        isEnabled: isEnabled,
                        size: sketch.size
                    )
                    // force redraw view on screen resize
                    .id(proxy.size)
                    // force redraw view on sketch change
                    .id(sketch.id)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    let container = try! ModelContainer(
        for: Sketch.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let sketch = Sketch(
        title: "Sample Sketch",
        layers: [
            .image(data: UIImage(systemName: "star")!.pngData()!),
            .drawing(drawing: PKDrawing()),
        ]
    )
    container.mainContext.insert(sketch)
    return SketchDetailView(sketch: sketch) 
        .modelContainer(container)
}
