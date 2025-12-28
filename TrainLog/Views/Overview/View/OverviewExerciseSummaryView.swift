import SwiftUI

// 種目ごとの集計画面を表示する画面
struct OverviewExerciseSummaryView: View {
    let exercise: ExerciseCatalog
    let workouts: [Workout]

    @Environment(\.weightUnit) private var weightUnit
    @State private var chartPeriod: ExerciseChartPeriod = .day
    @State private var navigationFeedbackTrigger = 0
    @State private var selectedWeekItem: ExerciseWeekListItem?
    private let calendar = Calendar.appCurrent
    private var isJapaneseLocale: Bool {
        Locale.preferredLanguages.first?.hasPrefix("ja") ?? false
    }
    private var strings: OverviewExerciseStrings {
        OverviewExerciseStrings(isJapanese: isJapaneseLocale)
    }
    private var locale: Locale { strings.locale }
    private var displayName: String {
        exercise.displayName(isJapanese: isJapaneseLocale)
    }

    private var chartData: [(label: String, value: Double)] {
        let series = OverviewMetrics.exerciseChartSeries(
            for: exercise.id,
            workouts: workouts,
            period: chartPeriod,
            calendar: calendar
        )
        return series.map { point in
            (axisLabel(for: point.date, period: chartPeriod), weightUnit.displayValue(fromKg: point.volume))
        }
    }

    private var hasAnyHistory: Bool {
        workouts.contains { workout in
            workout.sets.contains { OverviewMetrics.matches(set: $0, exerciseId: exercise.id) }
        }
    }

    private var weeklyListData: [ExerciseWeekListItem] {
        OverviewMetrics.weeklyExerciseVolumesAll(
            for: exercise.id,
            workouts: workouts,
            calendar: calendar
        )
        .map { point in
            let start = calendar.startOfWeek(for: point.date) ?? point.date
            return ExerciseWeekListItem(
                start: start,
                label: weekRangeLabel(for: start),
                volume: point.volume
            )
        }
    }

    var body: some View {
        List {
            if hasAnyHistory {
                Section(strings.totalVolumeSectionTitle) {
                    Picker(strings.periodPickerTitle, selection: $chartPeriod) {
                        ForEach(ExerciseChartPeriod.allCases, id: \.self) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    .segmentedHaptic(trigger: chartPeriod)
                    .padding(.horizontal, 4)

                    ExerciseVolumeChart(
                        data: chartData,
                        barColor: MuscleGroupColor.color(for: exercise.muscleGroup),
                        animateOnAppear: true,
                        animateOnTrigger: true,
                        animationTrigger: chartPeriod.hashValue,
                        yValueLabel: strings.volumeLabel(unit: weightUnit.unitLabel),
                        yAxisLabel: weightUnit.unitLabel
                    )
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
            }

            Section(strings.weeklyRecordsTitle) {
                ForEach(weeklyListData) { item in
                    Button {
                        selectedWeekItem = item
                    } label: {
                        HStack {
                            Text(item.label)
                                .font(.headline)
                            Spacer()
                            let parts = VolumeFormatter.volumePartsWithFraction(from: item.volume, locale: locale, unit: weightUnit)
                            ValueWithUnitText(
                                value: parts.value,
                                unit: " \(parts.unit)",
                                valueFont: .body,
                                unitFont: .subheadline,
                                valueColor: .secondary,
                                unitColor: .secondary
                            )
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.tertiary)
                                .imageScale(.small)
                                .font(.system(size: 17, weight: .semibold))
                        }
                        .padding(.vertical, 4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                if weeklyListData.isEmpty {
                    Text(strings.noHistoryText)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(displayName)
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(item: $selectedWeekItem) { item in
            OverviewExerciseWeekDetailView(
                weekStart: item.start,
                exerciseId: exercise.id,
                displayName: displayName,
                workouts: workouts
            )
        }
        .onChange(of: selectedWeekItem) { _, newValue in
            if newValue != nil {
                navigationFeedbackTrigger += 1
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: navigationFeedbackTrigger)
    }

    private func weekRangeLabel(for date: Date) -> String {
        let start = calendar.startOfWeek(for: date) ?? date
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = strings.weekRangeDateFormat
        return strings.weekRangeLabel(base: formatter.string(from: start))
    }

    private func axisLabel(for date: Date, period: ExerciseChartPeriod) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        switch period {
        case .day:
            formatter.dateFormat = strings.dayAxisDateFormat
        case .week:
            formatter.dateFormat = strings.weekAxisDateFormat
        case .month:
            formatter.dateFormat = strings.monthAxisDateFormat
        }
        let base = formatter.string(from: date)
        return period == .week ? strings.weekAxisLabel(base: base) : base
    }
}

struct ExerciseWeekListItem: Identifiable, Hashable {
    var id: Date { start }
    let start: Date
    let label: String
    let volume: Double
}

private struct OverviewExerciseStrings {
    let isJapanese: Bool

    var locale: Locale { isJapanese ? Locale(identifier: "ja_JP") : Locale(identifier: "en_US") }
    var totalVolumeSectionTitle: String { isJapanese ? "総ボリューム" : "Total Volume" }
    var periodPickerTitle: String { isJapanese ? "期間" : "Period" }
    var weeklyRecordsTitle: String { isJapanese ? "週ごとの記録" : "Weekly Records" }
    var noHistoryText: String { isJapanese ? "期間内の記録がありません" : "No records in this period." }
    var weekRangeDateFormat: String { isJapanese ? "yyyy年MM月dd日" : "MMM d, yyyy" }
    var dayAxisDateFormat: String { "M/d" }
    var weekAxisDateFormat: String { isJapanese ? "M/d" : "MMM d" }
    var monthAxisDateFormat: String { isJapanese ? "M月" : "MMM" }
    func weekRangeLabel(base: String) -> String {
        isJapanese ? "\(base)週" : "Week of \(base)"
    }
    func weekAxisLabel(base: String) -> String {
        isJapanese ? "\(base)週" : "\(base) W"
    }
    func volumeLabel(unit: String) -> String {
        isJapanese ? "ボリューム(\(unit))" : "Volume (\(unit))"
    }
}
