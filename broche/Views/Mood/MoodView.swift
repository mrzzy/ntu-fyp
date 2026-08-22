//
//  MoodView.swift
//  broche
//
//  Created by Zhu Zhanyan on 2026-07-05.
//

import PhotosUI
import SwiftData
import SwiftUI

/// Renders a grid of user created moods
struct MoodView: View {
    @Query(sort: \Mood.modifiedOn, order: .reverse) var moods: [Mood]
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.modelContext) private var modelContext
    @State private var showingAddSheet = false
    @State private var editingMood: Mood?
    @State private var selectedMoods = Set<Mood.ID>()
    let columnWidth: CGFloat = 180

    private var isSelecting: Bool {
        !selectedMoods.isEmpty
    }

    private var columns: [GridItem] {
        return [
            // multiple items on the same row
            GridItem(.adaptive(minimum: columnWidth, maximum: columnWidth), spacing: 24),
        ]
    }

    var body: some View {
        NavigationStack {
            VStack {
                if moods.isEmpty {
                    ContentUnavailableView(
                        "No Moods", systemImage: MoodIcon,
                        description: Text(
                            "New moods you create will appear here."
                        )
                    )
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(moods) { mood in
                                MoodCard(mood: mood, width: columnWidth)
                                    // ring to indicate selection
                                    .overlay {
                                        if selectedMoods.contains(mood.id) {
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Color.accentColor, lineWidth: 3)
                                        }
                                    }
                                    .onTapGesture {
                                        if isSelecting {
                                            toggleSelection(of: mood)
                                        } else {
                                            editingMood = mood
                                        }
                                    }
                                    .onLongPressGesture {
                                        let _ = withAnimation {
                                            selectedMoods.insert(mood.id)
                                        }
                                    }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Moods")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if isSelecting {
                        Button("Cancel") {
                            withAnimation { selectedMoods.removeAll() }
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isSelecting {
                        Button(role: .destructive) {
                            deleteSelected()
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(.red)
                        }
                        .disabled(selectedMoods.isEmpty)
                    } else {
                        Button {
                            showingAddSheet = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                EditMoodView()
            }
            .sheet(item: $editingMood) { mood in
                EditMoodView(mood: mood)
            }
        }
    }

    private func toggleSelection(of mood: Mood) {
        withAnimation {
            if selectedMoods.contains(mood.id) {
                selectedMoods.remove(mood.id)
            } else {
                selectedMoods.insert(mood.id)
            }
        }
    }

    private func deleteSelected() {
        for mood in moods where selectedMoods.contains(mood.id) {
            modelContext.delete(mood)
        }
        selectedMoods.removeAll()
    }
}

/// Displays a single mood as a card with optional image and description
struct MoodCard: View {
    let mood: Mood
    let width: CGFloat

    var body: some View {
        VStack(alignment: .center, spacing: 16) {
            Group {
                if let imageData = mood.images.first,
                   let uiImage = UIImage(data: imageData)
                {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .clipped()
                } else {
                    Image(systemName: MoodIcon)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .foregroundStyle(.secondary)
                        .clipped()
                }
            }
            .frame(width: width, height: 180)
            .background(Color(.tertiarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Text(mood.title)
                .font(.headline)
                .lineLimit(1)
        }
        .padding(.bottom, 12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .frame(maxWidth: width)
    }
}

#Preview {
    MoodView().modelContainer(for: Mood.self, inMemory: true)
}
