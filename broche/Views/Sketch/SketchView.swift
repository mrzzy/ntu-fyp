//
//  SketchView.swift
//  broche
//
//  Created by Zhu Zhanyan on 2026-07-05.
//

import SwiftData
import SwiftUI

struct SketchView: View {
    @Environment(\.modelContext) var modelContext
    @Query private var sketches: [Sketch]
    @State private var selectedId: Sketch.ID?
    @State private var editingSketch: Sketch?
    @State private var editedTitle: String = ""
    @State private var viewportSize: CGSize?

    var body: some View {
        NavigationSplitView {
            List(sketches, selection: $selectedId) { sketch in
                HStack {
                    Image(uiImage: sketch.image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    Text(sketch.title)
                    Spacer()
                }
                .contentShape(Rectangle())
                .listRowBackground(
                    sketch.id == selectedId ? Color.accentColor.opacity(0.1) : Color.clear
                )
                .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                .swipeActions(edge: .trailing) {
                    // delete (presented last)
                    Button(role: .destructive) {
                        modelContext.delete(sketch)
                        if selectedId == sketch.id {
                            selectedId = nil
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
            .navigationTitle("Sketches")
            .alert(
                "Edit Title",
                isPresented: Binding(
                    get: { editingSketch != nil },
                    set: { if !$0 { resetEditTitle() } }
                )
            ) {
                TextField("Title", text: $editedTitle)
                Button("Cancel", role: .cancel) {
                    resetEditTitle()
                }
                Button("Save") {
                    if let sketch = editingSketch {
                        sketch.title = editedTitle
                    }
                    resetEditTitle()
                }
            }
            // '+' button to add new sketch
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        // initialise new sketch based on viewport size
                        let newSketch = Sketch(size: viewportSize ?? CGSize(width: 512, height: 512))
                        modelContext.insert(newSketch)

                        selectedId = newSketch.id
                    } label: {
                        Label("Add Sketch", systemImage: "plus")
                    }
                }
            }
        } detail: {
            if let id = selectedId {
                GeometryReader { proxy in
                    SketchDetailView(id: id)
                        .onChange(of: proxy.size) {
                            viewportSize = proxy.size
                        }
                }
            } else {
                ContentUnavailableView("Create or Select a Sketch", systemImage: "pencil.tip")
            }
        }
    }

    func resetEditTitle() {
        editedTitle = ""
        editingSketch = nil
    }
}

#Preview {
    SketchView()
        .modelContainer(for: Sketch.self, inMemory: true)
}
