//
// DrawingCanvasView.swift
// broche
//
// Created by Zhu Zhanyan on 2026-07-10.
//

import PencilKit
import SwiftData
import SwiftUI

/// PencilKit canvas view for drawing layers
struct DrawingCanvasView: UIViewRepresentable {
    @Binding var drawing: PKDrawing
    // Whether drawing on the canvas view is enabled
    let isEnabled: Bool
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
        context.coordinator.toolPicker.setVisible(isEnabled, forFirstResponder: canvasView)
        if isEnabled {
            canvasView.becomeFirstResponder()
        }

        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        uiView.isDrawingEnabled = isEnabled
        if uiView.drawing != drawing {
            uiView.drawing = drawing
        }
        let toolPicker = context.coordinator.toolPicker
        toolPicker.setVisible(isEnabled, forFirstResponder: uiView)
        if isEnabled {
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
