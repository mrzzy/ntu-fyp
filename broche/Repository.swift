//
// Repository.swift
// broche
//
// Created by Zhu Zhanyan on 2026-07-17.
//

import Foundation
import SwiftData

/// Repository stores and manipulates data. Internally it uses swiftdata to persist the data.
@MainActor
class Repository {
    static let schema = Schema([
        Mood.self,
        Sketch.self,
    ])
    /// Access the shared instance of the Repository.
    static let shared = Repository()

    let modelContainer: ModelContainer

    var modelContext: ModelContext {
        return modelContainer.mainContext
    }

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    convenience init() {
        do {
            // disable swiftdata integration persistence in cloudkit
            let config = ModelConfiguration(schema: Self.schema, cloudKitDatabase: .none)
            let modelContainer = try ModelContainer(for: Self.schema, configurations: [config])
            self.init(modelContainer: modelContainer)
        } catch {
            fatalError("Failed to initialize ModelContainer: \(error)")
        }
    }

    /// Sketch model
    func addSketch(size: CGSize) -> Sketch {
        do {
            let newSketch = Sketch(size: size)
            modelContext.insert(newSketch)
            try modelContext.save()
            return newSketch
        } catch {
            fatalError("Failed to add sketch: \(error)")
        }
    }

    func fetchSketch(id: Sketch.ID) -> Sketch? {
        return try? modelContext.fetch(
            FetchDescriptor<Sketch>(
                predicate: #Predicate { $0.id == id }
            )
        ).first
    }

    func fetchMoods() -> [Mood] {
        do {
            let descriptor = FetchDescriptor<Mood>(
                sortBy: [SortDescriptor(\.modifiedOn, order: .forward)]
            )
            return try modelContext.fetch(descriptor)
        } catch {
            fatalError("Failed to fetch moods: \(error)")
        }
    }

    func fetchMood(id: UUID) -> Mood? {
        try? modelContext.fetch(
            FetchDescriptor<Mood>(
                predicate: #Predicate { $0.id == id }
            )
        ).first
    }

    func duplicate(_ sketch: Sketch) -> Sketch? {
        let copy = Sketch(
            title: "\(sketch.title) copy",
            layers: sketch.layers,
            size: sketch.size,
            messages: sketch.messages.map { Message(copying: $0) }
        )
        modelContext.insert(copy)
        save()
        return copy
    }

    func save() {
        do {
            try modelContext.save()
        } catch {
            fatalError("Failed to save changes: \(error)")
        }
    }
}
