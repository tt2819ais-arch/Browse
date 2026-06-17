import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct ImportExportView: View {
    @EnvironmentObject var bookmarks: BookmarkStore
    @EnvironmentObject var history: HistoryStore
    @EnvironmentObject var browser: BrowserStore

    @State private var shareItem: ShareItem?
    @State private var showPicker = false
    @State private var pending: ImportResult?
    @State private var toast: String?

    private let maxOpenTabs = 25

    var body: some View {
        ZStack {
            SheetBackground()
            ScrollView {
                VStack(spacing: 22) {
                    // Honest note about Safari
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle.fill").foregroundStyle(AeroColor.accent)
                            Text("Про импорт из Safari").font(.system(size: 15, weight: .semibold)).foregroundStyle(AeroColor.textPrimary)
                        }
                        Text("iOS не разрешает сторонним браузерам напрямую читать вкладки, куки и историю Safari — это запрет песочницы, такого API не существует. Поэтому перенос работает через файл:\n\n• В Safari/на компьютере: «Экспорт закладок» → получите HTML-файл → откройте его здесь кнопкой «Импорт из файла».\n• Список ссылок (.txt) или буфер обмена тоже подойдут.\n• Куки перенести нельзя — на новых сайтах нужно войти заново.")
                            .font(.system(size: 13)).foregroundStyle(AeroColor.textSecondary).fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 16).fill(AeroColor.card))
                    .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(AeroColor.stroke, lineWidth: 1))
                    .padding(.horizontal, 16)

                    // Import
                    GroupCard(title: "Импорт") {
                        NavRow(symbol: "square.and.arrow.down", title: "Импорт из файла", value: "HTML · JSON · TXT") { showPicker = true }
                        RowDivider()
                        NavRow(symbol: "doc.on.clipboard", title: "Импорт ссылок из буфера") {
                            let txt = UIPasteboard.general.string ?? ""
                            let r = ImportExport.parseClipboard(txt)
                            if r.isEmpty { showToast("В буфере нет ссылок") } else { pending = r }
                        }
                    }

                    // Export
                    GroupCard(title: "Экспорт") {
                        NavRow(symbol: "star", title: "Экспорт закладок", value: "\(bookmarks.items.count) · HTML") {
                            let html = ImportExport.bookmarksHTML(bookmarks.items)
                            if let url = ImportExport.writeTemp(name: "aero-bookmarks.html", string: html) { shareItem = ShareItem(url: url) }
                        }
                        RowDivider()
                        NavRow(symbol: "list.bullet", title: "Экспорт открытых вкладок", value: "\(browser.openTabURLs.count) · TXT") {
                            let txt = browser.openTabURLs.joined(separator: "\n")
                            if txt.isEmpty { showToast("Нет открытых вкладок"); return }
                            if let url = ImportExport.writeTemp(name: "aero-tabs.txt", string: txt) { shareItem = ShareItem(url: url) }
                        }
                        RowDivider()
                        NavRow(symbol: "externaldrive", title: "Резервная копия (всё)", value: "JSON") {
                            let data = ImportExport.backupJSON(bookmarks: bookmarks.items, history: history.items, tabs: browser.openTabURLs)
                            if let url = ImportExport.writeTemp(name: "aero-backup.json", data: data) { shareItem = ShareItem(url: url) }
                        }
                    }

                    Text("Экспортированный HTML открывается в Safari, Chrome и других браузерах. Резервную копию (JSON) можно вернуть обратно в Aero через «Импорт из файла».")
                        .font(.system(size: 12)).foregroundStyle(AeroColor.textTertiary)
                        .padding(.horizontal, 22)

                    Spacer().frame(height: 30)
                }
                .padding(.top, 8)
            }
            if let t = toast { toastView(t) }
        }
        .navigationTitle("Импорт и экспорт")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $shareItem) { ShareSheet(items: [$0.url]) }
        .sheet(isPresented: $showPicker) {
            DocumentPicker { url in
                let r = ImportExport.parse(url: url)
                if r.isEmpty { showToast("Не удалось найти ссылки в файле") } else { pending = r }
            }
        }
        .sheet(item: $pending) { result in
            ImportConfirmSheet(result: result, maxOpenTabs: maxOpenTabs,
                onBookmarks: {
                    let n = bookmarks.addMany(result.bookmarks)
                    if result.isBackup { history.addMany(result.history) }
                    pending = nil
                    showToast("Добавлено закладок: \(n)")
                },
                onTabs: {
                    let urls = (result.isBackup ? result.tabs : result.bookmarks.compactMap { URL(string: $0.url) })
                    let n = browser.openURLs(Array(urls.prefix(maxOpenTabs)))
                    pending = nil
                    showToast("Открыто вкладок: \(n)")
                })
        }
    }

    private func showToast(_ s: String) {
        withAnimation { toast = s }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { withAnimation { toast = nil } }
    }
    private func toastView(_ text: String) -> some View {
        VStack { Spacer()
            Text(text).font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                .padding(.horizontal, 18).padding(.vertical, 12)
                .background(Capsule().fill(AeroColor.accent)).padding(.bottom, 40)
        }.transition(.opacity)
    }
}

// MARK: - Import confirmation
private struct ImportConfirmSheet: View {
    let result: ImportResult
    let maxOpenTabs: Int
    let onBookmarks: () -> Void
    let onTabs: () -> Void
    @Environment(\.dismiss) private var dismiss

    var tabCount: Int { result.isBackup ? result.tabs.count : result.bookmarks.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "square.and.arrow.down.fill").foregroundStyle(AeroColor.accent)
                Text("Найдено").font(.system(size: 20, weight: .bold)).foregroundStyle(AeroColor.textPrimary)
                Spacer()
            }
            Text(result.summary).font(.system(size: 14)).foregroundStyle(AeroColor.textSecondary).fixedSize(horizontal: false, vertical: true)

            Button { onBookmarks() } label: {
                actionLabel("star.fill", "Добавить в закладки (\(result.bookmarks.count))", filled: true)
            }.buttonStyle(PressableStyle()).disabled(result.bookmarks.isEmpty && !result.isBackup)

            if tabCount > 0 {
                Button { onTabs() } label: {
                    actionLabel("rectangle.stack.badge.plus", "Открыть как вкладки (\(min(tabCount, maxOpenTabs)))", filled: false)
                }.buttonStyle(PressableStyle())
            }

            Button { dismiss() } label: {
                Text("Отмена").font(.system(size: 15, weight: .medium)).foregroundStyle(AeroColor.textSecondary)
                    .frame(maxWidth: .infinity).frame(height: 44)
            }
        }
        .padding(22)
        .presentationDetents([.height(tabCount > 0 ? 340 : 280)])
        .presentationDragIndicator(.visible)
    }

    private func actionLabel(_ symbol: String, _ title: String, filled: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
            Text(title).font(.system(size: 16, weight: .semibold))
        }
        .foregroundStyle(filled ? .white : AeroColor.accent)
        .frame(maxWidth: .infinity).frame(height: 50)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(filled ? AeroColor.accent : AeroColor.accent.opacity(0.12)))
    }
}

// MARK: - Helpers
extension ImportResult: Identifiable { var id: String { summary + "\(bookmarks.count)-\(tabs.count)" } }

struct DocumentPicker: UIViewControllerRepresentable {
    let onPick: (URL) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let types: [UTType] = [.html, .json, .plainText, .text, .data]
        let p = UIDocumentPickerViewController(forOpeningContentTypes: types)
        p.allowsMultipleSelection = false
        p.delegate = context.coordinator
        return p
    }
    func updateUIViewController(_ vc: UIDocumentPickerViewController, context: Context) {}

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void
        init(onPick: @escaping (URL) -> Void) { self.onPick = onPick }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            // copy to a local temp URL so parsing has guaranteed access
            let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("import-" + url.lastPathComponent)
            try? FileManager.default.removeItem(at: tmp)
            do {
                try FileManager.default.copyItem(at: url, to: tmp)
                onPick(tmp)
            } catch {
                onPick(url)
            }
        }
    }
}
