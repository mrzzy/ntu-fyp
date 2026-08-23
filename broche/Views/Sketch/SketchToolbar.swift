//
//  SketchToolbar.swift
//  broche
//
//  Created by Zhu Zhanyan on 2026-07-05.
//

import SwiftUI
import UniformTypeIdentifiers

/// Common toolbar for views hosting a Sketch
struct SketchToolbar: ToolbarContent {
    let sketch: Sketch
    @Environment(\.appState) var appState

    @Environment(\.undoManager) private var undoManager

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                undoManager?.undo()
                appState.nUndoRedo += 1
            } label: {
                Label("Undo", systemImage: "arrow.uturn.backward")
            }
            .disabled(!(undoManager?.canUndo ?? false))

            Button {
                undoManager?.redo()
                appState.nUndoRedo += 1
            } label: {
                Label("Redo", systemImage: "arrow.uturn.forward")
            }
            .disabled(!(undoManager?.canRedo ?? false))

            Button {
                sketch.zoom = Zoom()
            } label: {
                Label("Reset Zoom", systemImage: "arrow.counterclockwise")
            }

            // Export sketch button
            ShareLink(
                item: ShareableSketch(sketch: sketch),
                preview: SharePreview(
                    sketch.title,
                    image: Image(
                        uiImage: (try? sketch.render.cachedImage) ?? UIImage()
                    )
                )
            )
        }
    }
}

/// Wrapper for Sketch that can be shared via ShareLink
struct ShareableSketch: Transferable {
    let sketch: Sketch

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) {
            let image = try? await $0.sketch.render.image
            return image?.pngData() ?? Data()
        }.suggestedFileName {
            $0.sketch.title
        }
    }
}
