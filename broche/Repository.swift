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
    /// Access the shared instance of the Repository.
    static let shared = Repository()

    let modelContainer: ModelContainer
    let schema = Schema([
        Mood.self,
        Sketch.self,
    ])

    var modelContext: ModelContext {
        return modelContainer.mainContext
    }

    private init() {
        do {
            // disable swiftdata integration persistence in cloudkit
            let config = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
            modelContainer = try ModelContainer(for: schema, configurations: [config])
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

    func save() {
        do {
            try modelContext.save()
        } catch {
            fatalError("Failed to save changes: \(error)")
        }
    }
}
