import SwiftUI

struct AdBlockView: View {
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var adblock: AdBlockStore
    @EnvironmentObject var browser: BrowserStore
    @State private var info: InfoItem?

    private func fmt(_ n: Int) -> String {
        let f = NumberFormatter(); f.numberStyle = .decimal; f.groupingSeparator = " "
        return f.string(from: NSNumber(value: n)) ?? "\(n)"
    }

    var body: some View {
        ZStack {
            SheetBackground()
            ScrollView {
                VStack(spacing: 22) {
                    GroupCard(title: "Защита") {
                        ToggleRow(symbol: "shield.lefthalf.filled", title: "Блокировать рекламу и трекеры",
                                  subtitle: "\(fmt(adblock.totalRules)) правил в фильтрах",
                                  isOn: Binding(get: { settings.adBlockEnabled }, set: { settings.adBlockEnabled = $0; browser.recompileAndReconfigure(reload: true) }),
                                  help: Self.blockInfo, onHelp: { info = $0 })
                        RowDivider()
                        ToggleRow(symbol: "eye.slash", title: "Скрывать рекламные блоки",
                                  subtitle: "Косметическая фильтрация",
                                  isOn: Binding(get: { settings.cosmeticEnabled }, set: { settings.cosmeticEnabled = $0; browser.reapplyConfig(reload: true) }),
                                  help: Self.cosmeticInfo, onHelp: { info = $0 })
                        if adblock.compiling {
                            RowDivider()
                            HStack(spacing: 12) {
                                ProgressView().controlSize(.small)
                                Text("Компиляция фильтров…").font(.system(size: 14)).foregroundStyle(AeroColor.textSecondary)
                                Spacer()
                            }.padding(.vertical, 11).padding(.horizontal, 14)
                        } else if settings.adBlockEnabled {
                            RowDivider()
                            HStack(spacing: 12) {
                                Image(systemName: "checkmark.shield.fill").font(.system(size: 15)).foregroundStyle(AeroColor.success).frame(width: 26)
                                Text("Активно: \(fmt(adblock.activeRules)) правил").font(.system(size: 14, weight: .medium)).foregroundStyle(AeroColor.textPrimary)
                                Spacer()
                            }.padding(.vertical, 11).padding(.horizontal, 14)
                        }
                    }

                    // Filter lists (per-list toggles)
                    if !adblock.groups.isEmpty {
                        GroupCard(title: "Списки фильтров") {
                            ForEach(Array(adblock.groups.enumerated()), id: \.element.id) { idx, g in
                                ToggleRow(symbol: "list.bullet.rectangle", title: g.title,
                                          subtitle: "\(g.desc) · \(fmt(g.rules))",
                                          isOn: Binding(
                                            get: { settings.enabledLists.contains(g.id) },
                                            set: { on in
                                                if on { settings.enabledLists.insert(g.id) } else { settings.enabledLists.remove(g.id) }
                                                browser.recompileAndReconfigure(reload: false)
                                            }))
                                if idx < adblock.groups.count - 1 { RowDivider() }
                            }
                        }
                    }

                    // Reported ads
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("ВЫ ПОЖАЛОВАЛИСЬ".uppercased()).font(.system(size: 12, weight: .semibold)).foregroundStyle(AeroColor.textTertiary)
                            Spacer()
                            if !adblock.reported.isEmpty {
                                Button { Haptics.tap(); adblock.clearReported(); browser.reapplyConfig(reload: false) } label: {
                                    Text("Очистить").font(.system(size: 12, weight: .medium)).foregroundStyle(AeroColor.danger)
                                }
                            }
                        }.padding(.horizontal, 16)

                        if adblock.reported.isEmpty {
                            HStack(spacing: 10) {
                                Image(systemName: "flag").foregroundStyle(AeroColor.textTertiary)
                                Text("Пока нет жалоб. Откройте сайт, нажмите «···» → «Пожаловаться на рекламу» и коснитесь ненужного блока.")
                                    .font(.system(size: 13)).foregroundStyle(AeroColor.textSecondary).fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 14).fill(AeroColor.card))
                            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(AeroColor.stroke, lineWidth: 1))
                            .padding(.horizontal, 16)
                        } else {
                            VStack(spacing: 0) {
                                ForEach(Array(adblock.reported.enumerated()), id: \.element.id) { idx, r in
                                    HStack(spacing: 12) {
                                        Image(systemName: "flag.fill").font(.system(size: 14)).foregroundStyle(AeroColor.danger).frame(width: 26)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(r.host == "*" ? "Все сайты" : r.host).font(.system(size: 14, weight: .medium)).foregroundStyle(AeroColor.textPrimary).lineLimit(1)
                                            Text(r.note.isEmpty ? r.selector : r.note).font(.system(size: 11)).foregroundStyle(AeroColor.textTertiary).lineLimit(1)
                                        }
                                        Spacer()
                                        Button { Haptics.tap(); adblock.removeReported(at: IndexSet(integer: idx)); browser.reapplyConfig(reload: false) } label: {
                                            Image(systemName: "xmark.circle.fill").font(.system(size: 18)).foregroundStyle(AeroColor.textTertiary)
                                        }
                                    }
                                    .padding(.vertical, 11).padding(.horizontal, 14)
                                    if idx < adblock.reported.count - 1 { RowDivider() }
                                }
                            }
                            .background(RoundedRectangle(cornerRadius: 16).fill(AeroColor.card))
                            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(AeroColor.stroke, lineWidth: 1))
                            .padding(.horizontal, 16)
                        }
                    }

                    Spacer().frame(height: 30)
                }
                .padding(.top, 8)
            }
        }
        .navigationTitle("Блокировка рекламы")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $info) { InfoSheet(item: $0) }
    }

    static let blockInfo = InfoItem(title: "Блокировка рекламы и трекеров", text: "Aero использует полноценные фильтр-листы (EasyList, EasyPrivacy, RU AdList и список против раздражителей) — это сотни тысяч правил, как в AdGuard или uBlock. Запросы к рекламным и следящим доменам блокируются на сетевом уровне нативным механизмом WebKit, что ускоряет загрузку и экономит трафик.", recommend: "Рекомендуем держать включённым.")
    static let cosmeticInfo = InfoItem(title: "Косметическая фильтрация", text: "Прячет рекламные блоки, которые остались на странице (баннеры, вставки) с помощью CSS. Дополняет сетевую блокировку.", recommend: "Рекомендуем включить.")
}
