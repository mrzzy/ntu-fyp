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
    @Binding var showToolPicker: Bool
    // drawing change event callaback
    let onDrawingChanged: (PKDrawing) -> Void

    func makeUIView(context: Context) -> PKCanvasView {
        let canvasView = PKCanvasView()
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

    // captures view events and forwards them upstream to SwiftUI
    class Coordinator: NSObject, PKCanvasViewDelegate {
        var parent: DrawingCanvasView
        let toolPicker = PKToolPicker()

        init(_ parent: DrawingCanvasView) {
            self.parent = parent
            super.init()
        }

        func canvasViewDidEndDrawing(_ canvasView: PKCanvasView) {
            parent.onDrawingChanged(canvasView.drawing)
        }
    }
}

/// Presents the sketch to the user with a DrawView overlaid to capture user's drawing strokes
struct SketchDetailView: View {
    let id: Sketch.ID
    @Environment(\.modelContext) private var modelContext
    @State private var showToolPicker: Bool = true

    var body: some View {
        let descriptor = FetchDescriptor<Sketch>(
            predicate: #Predicate { $0.id == id }
        )
        let sketch = try? modelContext.fetch(descriptor).first

        ZStack {
            // white drawing background
            Color.white

            if let sketch = sketch {
                if sketch.layers.count > 1 {
                    let backgroundImage = sketch.renderLayers(indices: 0..<sketch.layers.count - 1) ?? UIImage()

                    ZStack {
                        Image(uiImage: backgroundImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)

                        renderLayer(sketch.layers[sketch.layers.count - 1])
                    }
                } else {
                    renderLayer(sketch.layers[0])
                }
            } else {
                Text("Sketch not found")
            }
        }
    }

    private func renderLayer(_ layer: Layer) -> some View {
        Group {
            switch layer {
            case .image(let data):
                if let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            case .drawing(let drawing):
                DrawingCanvasView(drawing: .constant(drawing), showToolPicker: $showToolPicker, onDrawingChanged: { _ in })
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
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
    return SketchDetailView(id: sketch.id)
        .modelContainer(container)
}
