import SwiftUI

// 種目一覧画面

struct ExerciseListView: View {
    let title: String
    let exercises: [ExerciseCatalog]

    @EnvironmentObject private var favoritesStore: ExerciseFavoritesStore
    private var isJapaneseLocale: Bool {
        Locale.preferredLanguages.first?.hasPrefix("ja") ?? false
    }
    private var strings: ExerciseListStrings {
        ExerciseListStrings(isJapanese: isJapaneseLocale)
    }

    var body: some View {
        List {
            ForEach(exercises, id: \.id) { exercise in
                NavigationLink(value: ExerciseRoute.detail(exercise)) {
                    ExerciseRow(
                        exercise: exercise,
                        isFavorite: favoritesStore.isFavorite(exercise.id)
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button {
                        favoritesStore.toggle(id: exercise.id)
                    } label: {
                        Label(
                            favoritesStore.isFavorite(exercise.id)
                                ? strings.removeFavoriteLabel
                                : strings.addFavoriteLabel,
                            systemImage: favoritesStore.isFavorite(exercise.id) ? "star.slash" : "star"
                        )
                    }
                    .tint(favoritesStore.isFavorite(exercise.id) ? .gray : .yellow)
                }
            }
            if exercises.isEmpty {
                VStack(alignment: .center, spacing: 12) {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.tertiary)
                        .imageScale(.large)
                        .font(.system(size: 32, weight: .semibold))
                    Text(strings.emptyTitle)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                    Text(strings.emptyMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .contentMargins(.top, 4, for: .scrollContent)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ExerciseRow: View {
    let exercise: ExerciseCatalog
    let isFavorite: Bool
    private var isJapaneseLocale: Bool {
        Locale.preferredLanguages.first?.hasPrefix("ja") ?? false
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.displayName(isJapanese: isJapaneseLocale))
                    .font(.body)
            }
            Spacer()
            if isFavorite {
                Image(systemName: "star.fill")
                    .foregroundStyle(.yellow)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct ExerciseListStrings {
    let isJapanese: Bool

    var addFavoriteLabel: String { isJapanese ? "お気に入り" : "Add Favorite" }
    var removeFavoriteLabel: String { isJapanese ? "お気に入り解除" : "Remove Favorite" }
    var emptyTitle: String { isJapanese ? "お気に入り種目なし" : "No Favorites" }
    var emptyMessage: String {
        isJapanese
            ? "お気に入り登録すると、メモ入力のときに種目を簡単に選べます。カテゴリから選んで登録しましょう。"
            : "Add favorites to quickly pick exercises when logging. Choose from categories to save them."
    }
}


#Preview {
    NavigationStack {
        ExerciseTabView()
            .environmentObject(ExerciseFavoritesStore())

    }
}
