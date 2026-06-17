import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var history: HistoryStore
    let onOpen: (String) -> Void

    var body: some View {
        ZStack {
            SheetBackground()
            VStack(spacing: 0) {
                SheetHeader(title: "История",
                            trailing: history.items.isEmpty ? nil : AnyView(
                                Button { Haptics.tap(); history.clear() } label: {
                                    Text("Очистить").font(.system(size: 14)).foregroundStyle(AeroColor.danger)
                                }))
                if history.items.isEmpty {
                    EmptyStateView(symbol: "clock", text: "История пуста")
                    Spacer()
                } else {
                    List {
                        ForEach(history.items) { item in
                            row(item)
                                .listRowBackground(Color.clear)
                                .listRowSeparatorTint(AeroColor.stroke)
                                .onTapGesture { Haptics.tap(); onOpen(item.url) }
                        }
                        .onDelete { history.remove(at: $0) }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
        }
    }

    private func row(_ item: HistoryItem) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(AeroColor.card).frame(width: 38, height: 38)
                Image(systemName: "clock").font(.system(size: 15)).foregroundStyle(AeroColor.textSecondary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title).font(.system(size: 15, weight: .medium))
                    .foregroundStyle(AeroColor.textPrimary).lineLimit(1)
                Text(URLBuilder.prettyHost(item.url)).font(.system(size: 12))
                    .foregroundStyle(AeroColor.textSecondary).lineLimit(1)
            }
            Spacer()
            Text(item.date, style: .time).font(.system(size: 11)).foregroundStyle(AeroColor.textTertiary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}
