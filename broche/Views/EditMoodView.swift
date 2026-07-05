//
//  EditMoodView.swift
//  broche
//
//  Created by Zhu Zhanyan on 2026-07-05.
//

import SwiftUI
import SwiftData
import PhotosUI

/// Sheet for adding or editing a mood
struct EditMoodView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    var mood: Mood?

    @State private var info = ""
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var images: [Data] = []

    init(mood: Mood? = nil) {
        self.mood = mood
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    PhotosPicker(
                        selection: $selectedItems,
                        maxSelectionCount: 5,
                        matching: .images
                    ) {
                        Label("Add Photos", systemImage: "photo")
                    }

                    if !images.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(Array(images.enumerated()), id: \.offset) { index, imageData in
                                    if let uiImage = UIImage(data: imageData) {
                                        ZStack(alignment: .topTrailing) {
                                            Image(uiImage: uiImage)
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: 80, height: 80)
                                                .clipShape(RoundedRectangle(cornerRadius: 8))

                                            Button {
                                                images.remove(at: index)
                                            } label: {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundStyle(.white)
                                                    .background(Circle().fill(Color.black.opacity(0.5)))
                                            }
                                            .offset(x: 4, y: -4)
                                        }
                                    }
                                }
                            }
                            .padding(.vertical, 8)
                        }
                    }
                } header: {
                    Text("Pictures")
                }

                Section {
                    TextField("Description", text: $info, axis: .vertical)
                        .lineLimit(3...6)
                } header: {
                    Text("Describe it")
                }
            }
            .navigationTitle(mood == nil ? "New Mood" : "Edit Mood")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(mood == nil ? "Add" : "Save") {
                        saveMood()
                        dismiss()
                    }
                    .disabled(info.isEmpty && images.isEmpty)
                }
            }
            .onChange(of: selectedItems) { _, newItems in
                Task {
                    for item in newItems {
                        if let data = try? await item.loadTransferable(type: Data.self) {
                            images.append(data)
                        }
                    }
                    selectedItems = []
                }
            }
        }
        .onAppear {
            if let mood = mood {
                info = mood.info
                images = mood.images
            }
        }
    }

    private func saveMood() {
        if let mood = mood {
            mood.info = info
            mood.images = images
        } else {
            let newMood = Mood(info: info, images: images)
            modelContext.insert(newMood)
        }
    }
}

