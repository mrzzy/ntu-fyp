//
// SketchDetailView.swift
//  broche
//
//  Created by Zhu Zhanyan on 2026-07-10.
//

import PencilKit
import SwiftData
import SwiftUI

/// PencilKit canvas view for drawing layers
struct DrawingCanvasView: UIViewRepresentable {
    @Binding var drawing: PKDrawing
    let showToolPicker: Bool
    let size: CGSize

    func makeUIView(context: Context) -> PKCanvasView {
        let canvasView = PKCanvasView()
        canvasView.contentSize = size
        canvasView.drawing = drawing
        canvasView.delegate = context.coordinator
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        canvasView.drawingPolicy = .anyInput

        // setup toolpicker
        context.coordinator.toolPicker.addObserver(canvasView)
        context.coordinator.toolPicker.setVisible(showToolPicker, forFirstResponder: canvasView)
        if showToolPicker {
            canvasView.becomeFirstResponder()
        }

        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        if uiView.drawing != drawing {
            uiView.drawing = drawing
        }
        let toolPicker = context.coordinator.toolPicker
        toolPicker.setVisible(showToolPicker, forFirstResponder: uiView)
        if showToolPicker {
            uiView.becomeFirstResponder()
        } else {
            uiView.resignFirstResponder()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    /// captures view events and forwards them upstream to SwiftUI
    class Coordinator: NSObject, PKCanvasViewDelegate {
        var parent: DrawingCanvasView
        let toolPicker = PKToolPicker()

        init(_ parent: DrawingCanvasView) {
            self.parent = parent
            super.init()
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            parent.drawing = canvasView.drawing
        }
    }
}

/// Presents the sketch to the user with a DrawView overlaid to capture user's drawing strokes
struct SketchDetailView: View {
    let id: Sketch.ID
    @Environment(\.modelContext) private var modelContext
    @State private var showToolPicker: Bool = true
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGPoint = .zero

    var body: some View {
        // fetch sketch by id to render
        let sketch = try? modelContext.fetch(
            FetchDescriptor<Sketch>(
                predicate: #Predicate { $0.id == id }
            )
        ).first

        if let sketch = sketch {
            let nLayers = sketch.layers.count
            // composite all layers except last layer in 1 image
            let backgroundLayers =
                if nLayers > 1 {
                    sketch.renderLayers(indices: 0..<sketch.layers.count - 1)
                } else { UIImage() }

            // render sketch
            ZoomableScrollView(scale: $scale, offset: $offset) {
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
                // bound sketch by preset sketch size
                .frame(width: sketch.size.width, height: sketch.size.height)
            }
        } else {
            Text("Sketch not found")
        }
    }

    private func renderLayer(_ sketch: Sketch, layer: Int) -> some View {
        Group {
            switch sketch.layers[layer] {
            case .image(let data):
                if let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                }
            case .drawing(let drawing):
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
                        showToolPicker: showToolPicker,
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
    return SketchDetailView(id: sketch.id)
        .modelContainer(container)
}
