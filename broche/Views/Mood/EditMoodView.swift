//
//  EditMoodView.swift
//  broche
//
//  Created by Zhu Zhanyan on 2026-07-05.
//

import PhotosUI
import SwiftData
import SwiftUI

/// Sheet for adding or editing a mood
struct EditMoodView: View {
    var mood: Mood?

    @State private var title = ""
    @State private var info = ""
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var images: [Data] = []
    @State private var isDescribing = false
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appState) private var appState

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
                                ForEach(Array(images.enumerated()), id: \.offset) {
                                    index, imageData in
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
                                                    .background(
                                                        Circle().fill(Color.black.opacity(0.5))
                                                    )
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
                    TextField("Title", text: $title)
                    TextField("Description", text: $info, axis: .vertical)
                        .lineLimit(3...6)
                } header: {
                    HStack {
                        Text("Description")
                        Spacer()
                        if isDescribing {
                            ProgressView()
                                .controlSize(.small)
                            Text("Generating…")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        } else {
                            Button {
                                Task { await handleDescribeMood() }
                            } label: {
                                Text("Generate")
                                Image(systemName: "wand.and.stars")
                            }
                            .disabled(images.isEmpty || appState.aiModels != .loaded)
                        }
                    }
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
                    .disabled(title.isEmpty && images.isEmpty)
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
                title = mood.title
                info = mood.info
                images = mood.images
            }
        }
    }

    private func saveMood() {
        if let mood = mood {
            mood.title = title
            mood.info = info
            mood.images = images
            mood.modifiedOn = .now
        } else {
            let newMood = Mood(title: title, info: info, images: images)
            modelContext.insert(newMood)
        }
    }

    private func handleDescribeMood() async {
        guard appState.aiModels == .loaded else {
            return
        }

        isDescribing = true
        defer { isDescribing = false }

        do {
            let output = try await describeMood(
                images: images, visualModel: AIRepository.shared.visualModel)
            title = output.title
            info = output.description
        } catch {
            print("Failed to describe mood: \(error)")
        }
    }
}
