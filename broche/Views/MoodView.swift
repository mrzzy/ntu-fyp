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
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.modelContext) private var modelContext
    @Query private var moods: [Mood]
    @State private var showingAddSheet = false
    @State private var editingMood: Mood?

    private var columns: [GridItem] {
        return [
            GridItem(.adaptive(minimum: 220, maximum: 240), spacing: 16)
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
                            MoodCard(mood: mood)
                                .onTapGesture {
                                    editingMood = mood
                                }
                        }
                    }
                        .padding(16)
                    }
                }
            }
            .navigationTitle("Moods")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus")
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
}
/// Displays a single mood as a card with optional image and description
struct MoodCard: View {
    let mood: Mood

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                if let imageData = mood.images.first,
                    let uiImage = UIImage(data: imageData)
                {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode:.fit)
                        .clipped()
                        .frame(width: 240)
                } else {
                    Image(systemName: MoodIcon)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .foregroundStyle(.secondary)
                        .padding(32)
                        .clipped()
                }
            }
            .frame(height: 160)
            .background(Color(.tertiarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Text(mood.info)
                .font(.caption)
                .lineLimit(3)
                .padding(16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    MoodView()
        .modelContainer(for: Mood.self, inMemory: true)
}
