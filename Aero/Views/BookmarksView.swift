import SwiftUI

struct BookmarksView: View {
    @EnvironmentObject var bookmarks: BookmarkStore
    let onOpen: (String) -> Void

    var body: some View {
        ZStack {
            SheetBackground()
            VStack(spacing: 0) {
                SheetHeader(title: "Закладки",
                            trailing: bookmarks.items.isEmpty ? nil : AnyView(
                                Button { Haptics.tap(); bookmarks.clear() } label: {
                                    Text("Очистить").font(.system(size: 14)).foregroundStyle(AeroColor.danger)
                                }))
                if bookmarks.items.isEmpty {
                    EmptyStateView(symbol: "star", text: "Пока нет закладок")
                    Spacer()
                } else {
                    List {
                        ForEach(bookmarks.items) { bm in
                            row(title: bm.title, url: bm.url)
                                .listRowBackground(Color.clear)
                                .listRowSeparatorTint(AeroColor.stroke)
                                .onTapGesture { Haptics.tap(); onOpen(bm.url) }
                        }
                        .onDelete { bookmarks.remove(at: $0) }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
        }
    }

    private func row(title: String, url: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(AeroColor.accentSoft).frame(width: 38, height: 38)
                Image(systemName: "globe").font(.system(size: 16)).foregroundStyle(AeroColor.accent)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 15, weight: .medium))
                    .foregroundStyle(AeroColor.textPrimary).lineLimit(1)
                Text(URLBuilder.prettyHost(url)).font(.system(size: 12))
                    .foregroundStyle(AeroColor.textSecondary).lineLimit(1)
            }
            Spacer()
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}
