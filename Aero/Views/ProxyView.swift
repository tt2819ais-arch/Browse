import SwiftUI

struct ProxyView: View {
    @EnvironmentObject var proxies: ProxyStore
    @EnvironmentObject var browser: BrowserStore

    @State private var importText = ""
    @State private var testing: Set<UUID> = []
    @State private var results: [UUID: ProxyManager.TestResult] = [:]
    @State private var showAdd = false
    @State private var toast: String?

    var body: some View {
        ZStack {
            SheetBackground()
            ScrollView {
                VStack(spacing: 22) {
                    if !ProxyManager.isSupported { unsupportedBanner }

                    // Master switch
                    GroupCard(title: "Прокси") {
                        ToggleRow(symbol: "network", title: "Использовать прокси",
                                  subtitle: proxies.active.map { "Активен: \($0.name)" } ?? "Не выбран",
                                  isOn: Binding(get: { proxies.enabled },
                                                set: { proxies.enabled = $0; browser.applyProxyToAll(reload: true) }),
                                  help: Self.proxyInfo, onHelp: { showInfo($0) })
                        .disabled(!ProxyManager.isSupported)
                        if let a = proxies.active {
                            RowDivider()
                            HStack(spacing: 12) {
                                Image(systemName: "checkmark.circle.fill").font(.system(size: 15)).foregroundStyle(AeroColor.success).frame(width: 26)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(a.display).font(.system(size: 14, weight: .medium)).foregroundStyle(AeroColor.textPrimary).lineLimit(1)
                                    if let r = results[a.id] { Text(resultLine(r)).font(.system(size: 12)).foregroundStyle(r.ok ? AeroColor.success : AeroColor.danger) }
                                }
                                Spacer()
                                testButton(a)
                            }.padding(.vertical, 10).padding(.horizontal, 14)
                        }
                    }

                    // Proxy list
                    if proxies.items.isEmpty {
                        GroupCard {
                            HStack(spacing: 10) {
                                Image(systemName: "tray").foregroundStyle(AeroColor.textTertiary)
                                Text("Список пуст. Импортируй или добавь прокси ниже.")
                                    .font(.system(size: 13)).foregroundStyle(AeroColor.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer()
                            }.padding(14)
                        }
                    } else {
                        GroupCard(title: "Мои прокси (\(proxies.items.count))") {
                            ForEach(Array(proxies.items.enumerated()), id: \.element.id) { idx, p in
                                proxyRow(p)
                                if idx < proxies.items.count - 1 { RowDivider() }
                            }
                        }
                        Button { Haptics.warning(); proxies.clear(); browser.applyProxyToAll(reload: true) } label: {
                            Text("Удалить все").font(.system(size: 14, weight: .medium)).foregroundStyle(AeroColor.danger)
                        }
                    }

                    // Import
                    GroupCard(title: "Импорт списка") {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("По одному в строке. Форматы:\nscheme://user:pass@host:port  ·  host:port:user:pass  ·  host:port")
                                .font(.system(size: 11)).foregroundStyle(AeroColor.textTertiary)
                            ZStack(alignment: .topLeading) {
                                RoundedRectangle(cornerRadius: 12).fill(AeroColor.field)
                                if importText.isEmpty {
                                    Text("socks5://user:pass@1.2.3.4:1080\n8.8.8.8:8080")
                                        .font(.system(size: 13, design: .monospaced)).foregroundStyle(AeroColor.textTertiary)
                                        .padding(.horizontal, 12).padding(.vertical, 12)
                                }
                                TextEditor(text: $importText)
                                    .font(.system(size: 13, design: .monospaced))
                                    .foregroundStyle(AeroColor.textPrimary)
                                    .scrollContentBackground(.hidden)
                                    .frame(height: 96)
                                    .padding(.horizontal, 8).padding(.vertical, 6)
                                    .autocorrectionDisabled().textInputAutocapitalization(.never)
                            }
                            .frame(height: 96)
                            Button {
                                let n = proxies.importText(importText)
                                importText = ""
                                Haptics.success()
                                showToast(n > 0 ? "Добавлено: \(n)" : "Ничего не распознано")
                                browser.applyProxyToAll(reload: false)
                            } label: {
                                Text("Импортировать").font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                                    .frame(maxWidth: .infinity).frame(height: 46)
                                    .background(RoundedRectangle(cornerRadius: 13).fill(AeroColor.accent))
                            }.buttonStyle(PressableStyle())
                        }
                        .padding(14)
                    }

                    Button { Haptics.tap(); showAdd = true } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                            Text("Добавить вручную").font(.system(size: 15, weight: .semibold))
                        }.foregroundStyle(AeroColor.accent)
                    }

                    Spacer().frame(height: 30)
                }
                .padding(.top, 8)
            }
            if let toast { toastView(toast) }
        }
        .navigationTitle("Прокси")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAdd) {
            ProxyAddView { entry in
                proxies.add(entry)
                browser.applyProxyToAll(reload: false)
            }
        }
        .sheet(item: $infoItem) { InfoSheet(item: $0) }
    }

    private var unsupportedBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(AeroColor.danger)
            Text("Маршрутизация через прокси требует iOS 17 или новее. Можно добавлять и хранить прокси, но они заработают только на iOS 17+.")
                .font(.system(size: 13)).foregroundStyle(AeroColor.textSecondary).fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(AeroColor.danger.opacity(0.1)))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(AeroColor.danger.opacity(0.3), lineWidth: 1))
        .padding(.horizontal, 16)
    }

    private func proxyRow(_ p: ProxyEntry) -> some View {
        HStack(spacing: 12) {
            Button { Haptics.tap(); proxies.select(p); browser.applyProxyToAll(reload: proxies.enabled) } label: {
                Image(systemName: proxies.activeID == p.id ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 20)).foregroundStyle(proxies.activeID == p.id ? AeroColor.accent : AeroColor.textTertiary)
            }.buttonStyle(PressableStyle())
            VStack(alignment: .leading, spacing: 2) {
                Text(p.name).font(.system(size: 15, weight: .medium)).foregroundStyle(AeroColor.textPrimary).lineLimit(1)
                Text(p.display).font(.system(size: 12)).foregroundStyle(AeroColor.textTertiary).lineLimit(1)
                if let r = results[p.id] { Text(resultLine(r)).font(.system(size: 11)).foregroundStyle(r.ok ? AeroColor.success : AeroColor.danger).lineLimit(1) }
            }
            Spacer()
            testButton(p)
            Button { Haptics.tap(); if let i = proxies.items.firstIndex(where: { $0.id == p.id }) { proxies.remove(at: IndexSet(integer: i)); browser.applyProxyToAll(reload: false) } } label: {
                Image(systemName: "trash").font(.system(size: 15)).foregroundStyle(AeroColor.textTertiary)
            }.buttonStyle(PressableStyle())
        }
        .padding(.vertical, 10).padding(.horizontal, 14)
    }

    private func testButton(_ p: ProxyEntry) -> some View {
        Button {
            Haptics.tap()
            testing.insert(p.id)
            Task {
                let r = await ProxyManager.test(p)
                await MainActor.run { results[p.id] = r; testing.remove(p.id) }
            }
        } label: {
            if testing.contains(p.id) {
                ProgressView().controlSize(.small)
            } else {
                Text("Тест").font(.system(size: 13, weight: .semibold)).foregroundStyle(AeroColor.accent)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Capsule().fill(AeroColor.accentSoft))
            }
        }
        .buttonStyle(PressableStyle())
        .disabled(testing.contains(p.id) || !ProxyManager.isSupported)
    }

    private func resultLine(_ r: ProxyManager.TestResult) -> String {
        if r.ok { return "IP: \(r.ip ?? "?")  ·  \(r.ms ?? 0) мс" }
        return "Ошибка: \(r.error ?? "нет ответа")"
    }

    private func showToast(_ t: String) {
        withAnimation { toast = t }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { withAnimation { toast = nil } }
    }

    private func toastView(_ text: String) -> some View {
        VStack { Spacer()
            Text(text).font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                .padding(.horizontal, 18).padding(.vertical, 12)
                .background(Capsule().fill(AeroColor.accent)).padding(.bottom, 36)
        }.transition(.opacity)
    }

    @State private var infoItem: InfoItem?
    private func showInfo(_ i: InfoItem) { infoItem = i }

    static let proxyInfo = InfoItem(
        title: "Прокси",
        text: "На iOS 17+ Aero маршрутизирует весь трафик браузера через выбранный прокси (HTTP/HTTPS/SOCKS5, с логином и паролем) через официальный API Apple. Сайты видят IP прокси, а не твой реальный. Кнопка «Тест» открывает api.ipify.org через прокси и показывает получившийся IP и задержку.",
        recommend: "Хочешь сменить IP — добавь рабочий прокси, выбери его и включи переключатель.")
}

/// Modal form for adding one proxy manually.
struct ProxyAddView: View {
    @Environment(\.dismiss) private var dismiss
    let onAdd: (ProxyEntry) -> Void

    @State private var type: ProxyType = .http
    @State private var host = ""
    @State private var port = ""
    @State private var user = ""
    @State private var pass = ""
    @State private var label = ""

    private var valid: Bool { !host.isEmpty && (Int(port) ?? 0) > 0 && (Int(port) ?? 0) <= 65535 }

    var body: some View {
        NavigationStack {
            ZStack {
                SheetBackground()
                ScrollView {
                    VStack(spacing: 22) {
                        GroupCard(title: "Тип") {
                            Picker("", selection: $type) {
                                ForEach(ProxyType.allCases) { Text($0.title).tag($0) }
                            }.pickerStyle(.segmented).padding(12)
                        }
                        GroupCard(title: "Сервер") {
                            field("Хост / IP", text: $host, keyboard: .URL)
                            RowDivider()
                            field("Порт", text: $port, keyboard: .numberPad)
                            RowDivider()
                            field("Метка (необязательно)", text: $label)
                        }
                        GroupCard(title: "Авторизация (необязательно)") {
                            field("Логин", text: $user)
                            RowDivider()
                            field("Пароль", text: $pass, secure: true)
                        }
                        Button {
                            guard valid else { return }
                            let e = ProxyEntry(label: label, type: type, host: host.trimmingCharacters(in: .whitespaces),
                                               port: Int(port) ?? 0, username: user, password: pass)
                            onAdd(e); Haptics.success(); dismiss()
                        } label: {
                            Text("Добавить").font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
                                .frame(maxWidth: .infinity).frame(height: 52)
                                .background(RoundedRectangle(cornerRadius: 14).fill(valid ? AeroColor.accent : AeroColor.textTertiary))
                        }.buttonStyle(PressableStyle()).disabled(!valid).padding(.horizontal, 16)
                        Spacer().frame(height: 20)
                    }.padding(.top, 10)
                }
                .navigationTitle("Новый прокси")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } } }
            }
        }
    }

    private func field(_ placeholder: String, text: Binding<String>, secure: Bool = false, keyboard: UIKeyboardType = .default) -> some View {
        HStack {
            if secure {
                SecureField(placeholder, text: text).font(.system(size: 15))
            } else {
                TextField(placeholder, text: text).font(.system(size: 15))
                    .keyboardType(keyboard).autocorrectionDisabled().textInputAutocapitalization(.never)
            }
        }
        .foregroundStyle(AeroColor.textPrimary)
        .padding(.vertical, 12).padding(.horizontal, 14)
    }
}
