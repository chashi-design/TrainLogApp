import SwiftUI

// 種目別チャートの期間種別を定義するenum
// enumは「決められた選択肢の集合」を型として表すため、想定外の値を防げる
enum ExerciseChartPeriod: CaseIterable {
    case day
    case week
    case month

    var title: String {
        let isJapanese = Locale.preferredLanguages.first?.hasPrefix("ja") ?? false
        switch self {
        case .day: return isJapanese ? "日" : "Day"
        case .week: return isJapanese ? "週" : "Week"
        case .month: return isJapanese ? "月" : "Month"
        }
    }
}
