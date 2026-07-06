//
//  SketchView.swift
//  broche
//
//  Created by Zhu Zhanyan on 2026-07-05.
//

import SwiftData
import SwiftUI

struct SketchView: View {
    @Query private var sketches: [Sketch]
    @State private var selectedId: UUID?

    var body: some View {
        NavigationSplitView {
            List(sketches, selection: $selectedId) { sketch in
                HStack {
                    if let image = sketch.image {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.secondary.opacity(0.3))
                            .frame(width: 60, height: 60)
                    }
                    Text(sketch.title)
                    Spacer()
                }
                .contentShape(Rectangle())
                .listRowBackground(sketch.id == selectedId ? Color.accentColor.opacity(0.1) : Color.clear)
                .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
            }
            .navigationTitle("Sketches")
        } detail: {
            if let id = selectedId {
                Text("Sketch: \(id)")
            } else {
                ContentUnavailableView("Create or Select a Sketch", systemImage: "sidebar.leading")
            }
        }
    }
}

#Preview {
    SketchView()
        .modelContainer(for: Sketch.self, inMemory: true)
}
