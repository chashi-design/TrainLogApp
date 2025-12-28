import SwiftUI

// アプリ全体のタブをまとめるエントリーポイント
struct ContentView: View {
    @State private var selectedTab: Tab = .summary
    @State private var tabHapticTrigger = 0
    @StateObject private var favoritesStore = ExerciseFavoritesStore()
    @AppStorage(WeightUnit.storageKey) private var weightUnitRaw = WeightUnit.kg.rawValue

    private var isJapaneseLocale: Bool {
        Locale.preferredLanguages.first?.hasPrefix("ja") ?? false
    }

    private var strings: ContentStrings {
        ContentStrings(isJapanese: isJapaneseLocale)
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            OverviewTabView()
                .tag(Tab.summary)
                .tabItem {
                    Label(strings.activityTabTitle, systemImage: "chart.bar.fill")
                }

            LogView()
                .tag(Tab.memo)
                .tabItem {
                    Label(strings.logTabTitle, systemImage: "calendar.badge.plus")
                }
            
            ExerciseTabView()
                .tag(Tab.exercises)
                .tabItem {
                    Label(strings.exercisesTabTitle, systemImage: "list.bullet")
                }
        }
        .onChange(of: selectedTab) { _, _ in
            tabHapticTrigger += 1
        }
        .sensoryFeedback(.impact(weight: .light), trigger: tabHapticTrigger)
        .environmentObject(favoritesStore)
        .environment(\.weightUnit, WeightUnit(rawValue: weightUnitRaw) ?? .kg)
    }
}

private enum Tab {
    case summary
    case memo
    case exercises
}

private struct ContentStrings {
    let isJapanese: Bool

    var activityTabTitle: String { isJapanese ? "アクティビティ" : "Activity" }
    var logTabTitle: String { isJapanese ? "メモ" : "Log" }
    var exercisesTabTitle: String { isJapanese ? "種目" : "Exercises" }
}

#Preview {
    ContentView()
}
