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
    var sketch: Sketch?
    let isEnabled: Bool

    @Environment(\.modelContext) private var modelContext
    @Environment(\.undoManager) private var undoManager
    @Environment(\.appState) private var appState

    let repo: Repository = .shared

    var body: some View {
        if let sketch = sketch {
            let layers = sketch.layers
            let nLayers = layers.count
            // composite all layers except last layer in 1 image
            let backgroundLayers =
                if nLayers > 1 {
                    // hot should be cached
                    (try? sketch.render.renderLayers(indices: 0..<nLayers - 1))
                        ?? UIImage()
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
                    set: {
                        sketch.zoom.offsetX = $0.x
                        sketch.zoom.offsetY = $0.y
                    }
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

                    // render final layer
                    let iLastLayer = nLayers - 1
                    Group {
                        switch layers[iLastLayer] {
                        case .image(let data, _):
                            if let image = UIImage(data: data) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFit()
                            }
                        case .drawing(let drawing, _):
                            GeometryReader { proxy in
                                DrawingCanvasView(
                                    drawing:
                                        Binding(
                                            get: { drawing },
                                            set: { newDrawing in
                                                // sync drawing changes back to model
                                                sketch.setLayer(
                                                    at: iLastLayer,
                                                    to: .drawing(
                                                        drawing: newDrawing, modifiedOn: .now
                                                    )
                                                )
                                                repo.save()
                                            }
                                        ),
                                    isEnabled: isEnabled
                                )
                                // force redraw view on screen resize & undo / redo count change
                                .id(proxy.size)
                                .id(appState.nUndoRedo)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                // rotate sketch as per ZoomableScrollView instructions
                .rotationEffect(rotation)
                // bound sketch by preset sketch size
                .frame(width: sketch.size.width, height: sketch.size.height)
                // redraw when sketch layers change, avoid stale layer stack.
                .id(sketch.layers.count)
            }
            // reset zoom scroll settings for each new sketch by replacing ZoomableScrollView
            .id(sketch.id)
            .gesture(
                MultiFingerTapGesture(count: 2) {
                    undoManager?.undo()
                    appState.nUndoRedo += 1
                }
            )
            .gesture(
                MultiFingerTapGesture(count: 3) {
                    undoManager?.redo()
                    appState.nUndoRedo += 1
                }
            )
        } else {
            ContentUnavailableView(
                "Sketch not found",
                systemImage: "questionmark"
            )
        }
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
    return SketchDetailView(sketch: sketch, isEnabled: true)
        .modelContainer(container)
}
