//
//  SketchView.swift
//  broche
//
//  Created by Zhu Zhanyan on 2026-07-05.
//

import SwiftData
import SwiftUI

struct SketchView: View {
    /// currently selected sketch id
    @Binding var sketchId: Sketch.ID?
    @State private var editingSketch: Sketch?
    @State private var viewportSize: CGSize?

    let repo: Repository = .shared
    @Query private var sketches: [Sketch]
    @State private var showingSizePicker = false
    @State private var editedTitle: String = ""
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        GeometryReader { proxy in
            NavigationSplitView(columnVisibility: $columnVisibility) {
                List(sketches, selection: $sketchId) { sketch in
                    HStack {
                        Image(uiImage: (try? sketch.render.cachedImage) ?? UIImage())
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        Text(sketch.title)
                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .listRowBackground(
                        sketch.id == sketchId ? Color.accentColor.opacity(0.1) : Color.clear
                    )
                    .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                    .swipeActions(edge: .trailing) {
                        // delete (presented last)
                        Button(role: .destructive) {
                            repo.modelContext.delete(sketch)
                            if sketchId == sketch.id {
                                sketchId = nil
                            }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        // rename title
                        Button {
                            editingSketch = sketch
                            editedTitle = sketch.title
                        } label: {
                            Label("Rename", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
                }
                .alert(
                    "Edit Title",
                    isPresented: Binding(
                        get: { editingSketch != nil },
                        set: {
                            if !$0 {
                                resetEditTitle()
                            }
                        }
                    )
                ) {
                    TextField("Title", text: $editedTitle)
                    Button("Cancel", role: .cancel) {
                        resetEditTitle()
                    }
                    Button("Save") {
                        if let sketch = editingSketch {
                            sketch.title = editedTitle
                            repo.save()
                        }
                        resetEditTitle()
                    }
                }
                // '+' button to add new sketch
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            showingSizePicker = true
                        } label: {
                            Label("Add Sketch", systemImage: "plus")
                        }
                        .alert("Choose Sketch Size", isPresented: $showingSizePicker) {
                            Button("Portrait (768×1024)") {
                                sketchId = repo.addSketch(size: CGSize(width: 768, height: 1024)).id
                            }
                            Button("Landscape (1024×768)") {
                                sketchId = repo.addSketch(size: CGSize(width: 1024, height: 768)).id
                            }
                            if let viewport = viewportSize {
                                Button(
                                    "Viewport Size (\(Int(viewport.width))×\(Int(viewport.height)))"
                                ) {
                                    sketchId = repo.addSketch(size: viewport).id
                                }
                            }
                            Button("Cancel", role: .cancel) {}
                        }
                    }
                }
                .navigationTitle("Sketches")
            } detail: {
                Group {
                    if let id = sketchId {
                        SketchDetailView(
                            sketch: repo.fetchSketch(id: id),
                            isEnabled: columnVisibility == .detailOnly
                        )
                    } else {
                        ContentUnavailableView(
                            "Create or Select a Sketch", systemImage: SketchIcon
                        )
                    }
                }
                .navigationTitle("Sketch")
                .toolbar {
                    if let id = sketchId,
                        let sketch = repo.fetchSketch(id: id)
                    {
                        SketchToolbar(sketch: sketch)
                    }
                }
            }
            .onChange(of: proxy.size) {
                viewportSize = proxy.size
            }
        }
    }

    func resetEditTitle() {
        editedTitle = ""
        editingSketch = nil
    }
}

#Preview {
    SketchView(sketchId: .constant(nil))
        .modelContainer(for: Sketch.self, inMemory: true)
}
