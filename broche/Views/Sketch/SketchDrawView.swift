//
// SketchDrawView.swift
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
    let onDrawingChanged: (PKDrawing) -> Void

    func makeUIView(context: Context) -> PKCanvasView {
        let canvasView = PKCanvasView()
        canvasView.drawing = drawing
        canvasView.delegate = context.coordinator
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context _: Context) {
        if uiView.drawing != drawing {
            uiView.drawing = drawing
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PKCanvasViewDelegate {
        var parent: DrawingCanvasView

        init(_ parent: DrawingCanvasView) {
            self.parent = parent
        }

        func canvasViewDidEndDrawing(_ canvasView: PKCanvasView) {
            parent.onDrawingChanged(canvasView.drawing)
        }
    }
}

/// Presents the sketch to the user with a DrawView overlaid to capture user's drawing strokes
struct SketchDrawView: View {
    let id: Sketch.ID
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        let descriptor = FetchDescriptor<Sketch>(
            predicate: #Predicate { $0.id == id }
        )
        let sketch = try? modelContext.fetch(descriptor).first

        ZStack {
            Color.white

            if let sketch = sketch {
                if !sketch.layers.isEmpty {
                    if sketch.layers.count == 1 {
                        singleLayerView(sketch: sketch)
                    } else {
                        multiLayerView(sketch: sketch)
                    }
                }
            } else {
                Text("Sketch not found")
            }
        }
    }

    private func singleLayerView(sketch: Sketch) -> some View {
        renderLayer(sketch.layers[0])
    }

    private func multiLayerView(sketch: Sketch) -> some View {
        let backgroundImage = sketch.renderLayers(indices: 0..<sketch.layers.count - 1) ?? UIImage()

        return ZStack {
            Image(uiImage: backgroundImage)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            renderLayer(sketch.layers[sketch.layers.count - 1])
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
                DrawingCanvasView(drawing: .constant(drawing), onDrawingChanged: { _ in })
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
    return SketchDrawView(id: sketch.id)
        .modelContainer(container)
}
