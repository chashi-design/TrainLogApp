import Combine
import SwiftData
import SwiftUI

@MainActor
final class LogViewModel: ObservableObject {
    @Published var selectedDate = LogDateHelper.normalized(Date())
    @Published var exercisesCatalog: [ExerciseCatalog] = []
    @Published var isLoadingExercises = true
    @Published var exerciseLoadFailed = false
    @Published var draftExercises: [DraftExerciseEntry] = []
    @Published private(set) var draftRevision: Int = 0
    private(set) var isSyncingDrafts = false

    private var draftsCache: [Date: [DraftExerciseEntry]] = [:]
    private var lastSyncedDate: Date?

    func loadExercises() async {
        isLoadingExercises = true
        exerciseLoadFailed = false
        do {
            let items = try ExerciseLoader.loadFromBundle()
            exercisesCatalog = items.sorted { $0.name < $1.name }
            isLoadingExercises = false
        } catch {
            print("exercises.json load error:", error)
            exerciseLoadFailed = true
            isLoadingExercises = false
        }
    }

    func startNewWorkout() {
        selectedDate = LogDateHelper.normalized(selectedDate)
        draftExercises.removeAll()
        draftRevision += 1
    }

    func removeDraftExercise(atOffsets indexSet: IndexSet) {
        draftExercises.remove(atOffsets: indexSet)
        draftRevision += 1
    }

    func removeDraftExercise(id: UUID) {
        draftExercises.removeAll { $0.id == id }
        draftRevision += 1
    }

    func displayName(for exerciseId: String, isJapanese: Bool) -> String {
        exercisesCatalog.displayName(forId: exerciseId, isJapanese: isJapanese)
    }

    func draftEntry(with id: UUID) -> DraftExerciseEntry? {
        draftExercises.first(where: { $0.id == id })
    }

    func saveWorkout(context: ModelContext, unit: WeightUnit) {
        let savedSets = buildExerciseSets(unit: unit)
        let normalizedDate = LogDateHelper.normalized(selectedDate)

        if savedSets.isEmpty {
            if let existing = findWorkout(on: normalizedDate, context: context) {
                context.delete(existing)
                do {
                    try context.save()
                    draftsCache[normalizedDate] = draftExercises
                } catch {
                    print("Workout delete error:", error)
                }
            }
            return
        }

        for set in savedSets {
            context.insert(set)
        }

        if let existing = findWorkout(on: normalizedDate, context: context) {
            existing.sets = savedSets
        } else {
            let workout = Workout(
                date: normalizedDate,
                note: "",
                sets: savedSets
            )
            context.insert(workout)
        }

        do {
            try context.save()
            draftsCache[normalizedDate] = draftExercises
        } catch {
            print("Workout save error:", error)
        }
    }

    private func findWorkout(on date: Date, context: ModelContext) -> Workout? {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return nil
        }

        let descriptor = FetchDescriptor<Workout>(
            predicate: #Predicate { workout in
                workout.date >= startOfDay && workout.date < endOfDay
            }
        )

        return try? context.fetch(descriptor).first
    }

    func syncDraftsForSelectedDate(context: ModelContext, unit: WeightUnit) {
        isSyncingDrafts = true
        defer { isSyncingDrafts = false }
        let normalizedNewDate = LogDateHelper.normalized(selectedDate)

        if let lastDate = lastSyncedDate {
            let normalizedLast = LogDateHelper.normalized(lastDate)
            draftsCache[normalizedLast] = draftExercises
        }

        if let cachedDrafts = draftsCache[normalizedNewDate] {
            draftExercises = cachedDrafts
            lastSyncedDate = normalizedNewDate
            return
        }

        if let workout = findWorkout(on: normalizedNewDate, context: context) {
            let locale = Locale.current
            let grouped = Dictionary(grouping: workout.sets, by: { $0.exerciseId })
            let mapped = grouped.map { exerciseId, sets -> DraftExerciseEntry in
                let rows: [DraftSetRow] = sets.map { set -> DraftSetRow in
                    let weightText = DraftSetRow.formattedWeightText(set.weight, unit: unit, locale: locale)
                    return DraftSetRow(weightText: weightText, repsText: String(set.reps))
                }
                var entry = DraftExerciseEntry(exerciseId: exerciseId, defaultSetCount: 0)
                entry.sets = rows
                return entry
            }

            let isJapanese = Locale.preferredLanguages.first?.hasPrefix("ja") ?? false
            draftExercises = mapped.sorted {
                displayName(for: $0.exerciseId, isJapanese: isJapanese) < displayName(for: $1.exerciseId, isJapanese: isJapanese)
            }
        } else {
            draftExercises = []
        }

        lastSyncedDate = normalizedNewDate
    }

    func appendExercise(_ id: String, initialSetCount: Int = 2) {
        let entry = DraftExerciseEntry(exerciseId: id, defaultSetCount: initialSetCount)
        draftExercises.append(entry)
        draftRevision += 1
    }

    func addSetRow(to exerciseID: UUID) {
        guard let index = draftExercises.firstIndex(where: { $0.id == exerciseID }) else { return }
        draftExercises[index].sets.append(DraftSetRow())
        draftRevision += 1
    }

    func removeSetRow(exerciseID: UUID, setID: UUID) {
        guard let index = draftExercises.firstIndex(where: { $0.id == exerciseID }) else { return }
        draftExercises[index].sets.removeAll { $0.id == setID }
        draftRevision += 1
    }

    func moveDraftExercises(from source: IndexSet, to destination: Int) {
        draftExercises.move(fromOffsets: source, toOffset: destination)
        draftRevision += 1
    }

    func updateSetRow(exerciseID: UUID, setID: UUID, weightText: String, repsText: String) {
        guard let exerciseIndex = draftExercises.firstIndex(where: { $0.id == exerciseID }) else { return }
        guard let setIndex = draftExercises[exerciseIndex].sets.firstIndex(where: { $0.id == setID }) else { return }
        draftExercises[exerciseIndex].sets[setIndex].weightText = weightText
        draftExercises[exerciseIndex].sets[setIndex].repsText = repsText
        draftRevision += 1
    }

    func weightText(exerciseID: UUID, setID: UUID) -> String {
        guard let exerciseIndex = draftExercises.firstIndex(where: { $0.id == exerciseID }) else { return "" }
        guard let setIndex = draftExercises[exerciseIndex].sets.firstIndex(where: { $0.id == setID }) else { return "" }
        return draftExercises[exerciseIndex].sets[setIndex].weightText
    }

    func repsText(exerciseID: UUID, setID: UUID) -> String {
        guard let exerciseIndex = draftExercises.firstIndex(where: { $0.id == exerciseID }) else { return "" }
        guard let setIndex = draftExercises[exerciseIndex].sets.firstIndex(where: { $0.id == setID }) else { return "" }
        return draftExercises[exerciseIndex].sets[setIndex].repsText
    }

    var hasValidSets: Bool {
        draftExercises.contains { entry in
            entry.sets.contains { $0.isValid }
        }
    }

    private func buildExerciseSets(unit: WeightUnit) -> [ExerciseSet] {
        let structured = draftExercises.flatMap { entry in
            return entry.exerciseSets(unit: unit, exerciseId: entry.exerciseId)
        }

        return structured
    }
}

struct DraftExerciseEntry: Identifiable {
    let id = UUID()
    var exerciseId: String
    var sets: [DraftSetRow]

    init(exerciseId: String, defaultSetCount: Int = 2) {
        self.exerciseId = exerciseId
        self.sets = (0..<defaultSetCount).map { _ in DraftSetRow() }
    }

    func exerciseSets(unit: WeightUnit, exerciseId: String) -> [ExerciseSet] {
        return sets.compactMap { $0.toExerciseSet(exerciseId: exerciseId, unit: unit) }
    }

    var completedSetCount: Int {
        sets.filter { $0.isValid }.count
    }
}

struct DraftSetRow: Identifiable {
    let id = UUID()
    var weightText: String = ""
    var repsText: String = ""

    func toExerciseSet(exerciseId: String, unit: WeightUnit) -> ExerciseSet? {
        guard let weightInput = Double(weightText), let reps = Int(repsText) else { return nil }
        let weightKg = unit.kgValue(fromDisplay: weightInput)
        return ExerciseSet(exerciseId: exerciseId, weight: weightKg, reps: reps)
    }

    var isValid: Bool {
        Double(weightText) != nil && Int(repsText) != nil
    }

    static func formattedWeightText(_ weight: Double, unit: WeightUnit, locale: Locale) -> String {
        unit.formattedValue(fromKg: weight, locale: locale, maximumFractionDigits: 3)
    }
}
