//
//  TrainLogAppApp.swift
//  TrainLogApp
//
//  Created by Takanori Hirohashi on 2025/11/02.
//
import SwiftUI
import SwiftData
import Foundation

@main
struct TrainLogApp: App {
    private let modelContainer: ModelContainer

    init() {
        let schema = Schema([Workout.self, ExerciseSet.self])
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let storeURL = appSupport.appendingPathComponent("TrainLog.store")
        do {
            try FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
            let config = ModelConfiguration(schema: schema, url: storeURL)
            modelContainer = try ModelContainer(for: schema, configurations: config)
        } catch {
            let fm = FileManager.default
            let walURL = URL(fileURLWithPath: storeURL.path + "-wal")
            let shmURL = URL(fileURLWithPath: storeURL.path + "-shm")
            try? fm.removeItem(at: storeURL)
            try? fm.removeItem(at: walURL)
            try? fm.removeItem(at: shmURL)
            let config = ModelConfiguration(schema: schema, url: storeURL)
            modelContainer = try! ModelContainer(for: schema, configurations: config)
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
    }
}
