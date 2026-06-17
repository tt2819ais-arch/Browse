import SwiftUI

struct PrivacyView: View {
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var browser: BrowserStore
    @State private var info: InfoItem?

    private func apply() { browser.reapplyConfig(reload: false) }

    var body: some View {
        ZStack {
            SheetBackground()
            ScrollView {
                VStack(spacing: 22) {
                    // Intro
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "info.circle.fill").foregroundStyle(AeroColor.accent)
                        Text("Каждая защита включается отдельно. Нажмите «?», чтобы узнать, что она делает и стоит ли её включать. Изменения применяются при следующем обновлении страницы.")
                            .font(.system(size: 13)).foregroundStyle(AeroColor.textSecondary).fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(AeroColor.accentSoft))
                    .padding(.horizontal, 16)

                    GroupCard(title: "Отпечаток браузера") {
                        toggle("paintbrush.pointed.fill", "Защита Canvas", $settings.pCanvas, Self.canvasInfo)
                        RowDivider()
                        toggle("cube.transparent", "Защита WebGL", $settings.pWebGL, Self.webglInfo)
                        RowDivider()
                        toggle("waveform", "Защита Audio", $settings.pAudio, Self.audioInfo)
                        RowDivider()
                        toggle("rectangle.on.rectangle", "Маскировать экран", $settings.pScreen, Self.screenInfo)
                        RowDivider()
                        toggle("cpu", "Маскировать систему", $settings.pNavigator, Self.navInfo)
                    }

                    GroupCard(title: "Сеть и местоположение") {
                        toggle("location.slash.fill", settings.geoDeny ? "Запрет геолокации" : "Подмена геолокации", $settings.pGeo, Self.geoInfo)
                        if settings.pGeo {
                            RowDivider()
                            HStack(spacing: 12) {
                                Image(systemName: "mappin.and.ellipse").font(.system(size: 16)).foregroundStyle(AeroColor.accent).frame(width: 26)
                                Text("Режим").font(.system(size: 15, weight: .medium)).foregroundStyle(AeroColor.textPrimary)
                                Spacer()
                                Picker("", selection: Binding(get: { settings.geoDeny }, set: { settings.geoDeny = $0; apply() })) {
                                    Text("Запрет").tag(true); Text("Подмена").tag(false)
                                }.pickerStyle(.segmented).frame(width: 160)
                            }
                            .padding(.vertical, 6).padding(.horizontal, 14)
                        }
                        RowDivider()
                        toggle("network.slash", "Блок WebRTC (анти-IP-утечка)", $settings.pWebRTC, Self.rtcInfo)
                    }

                    GroupCard(title: "Язык и время") {
                        toggle("globe", "Подмена языка сайтов", $settings.pLanguage, Self.langInfo)
                        if settings.pLanguage {
                            RowDivider()
                            pickerRow("character.bubble", "Язык", Binding(get: { settings.language }, set: { settings.language = $0; apply() }), SettingsStore.languageOptions)
                        }
                        RowDivider()
                        toggle("clock", "Подмена часового пояса", $settings.pTimezone, Self.tzInfo)
                        if settings.pTimezone {
                            RowDivider()
                            pickerRow("globe.americas", "Пояс", Binding(get: { settings.timezone }, set: { settings.timezone = $0; apply() }), SettingsStore.timezoneOptions)
                        }
                    }

                    Spacer().frame(height: 30)
                }
                .padding(.top, 8)
            }
        }
        .navigationTitle("Приватность")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $info) { InfoSheet(item: $0) }
    }

    private func toggle(_ symbol: String, _ title: String, _ binding: Binding<Bool>, _ help: InfoItem) -> some View {
        ToggleRow(symbol: symbol, title: title, isOn: Binding(get: { binding.wrappedValue }, set: { binding.wrappedValue = $0; apply() }),
                  help: help, onHelp: { info = $0 })
    }

    private func pickerRow(_ symbol: String, _ title: String, _ binding: Binding<String>, _ options: [String]) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).font(.system(size: 16)).foregroundStyle(AeroColor.accent).frame(width: 26)
            Text(title).font(.system(size: 15, weight: .medium)).foregroundStyle(AeroColor.textPrimary)
            Spacer()
            Picker("", selection: binding) { ForEach(options, id: \.self) { Text($0).tag($0) } }
                .pickerStyle(.menu).tint(AeroColor.accent)
        }
        .padding(.vertical, 4).padding(.horizontal, 14)
    }

    // MARK: - Help texts
    static let canvasInfo = InfoItem(title: "Защита Canvas", text: "Сайты могут «рисовать» невидимую картинку и по мельчайшим отличиям рендеринга вычислять ваше устройство — это canvas-отпечаток. Защита добавляет незаметный шум, чтобы отпечаток менялся.", recommend: "Рекомендуем включить — почти не влияет на сайты.")
    static let webglInfo = InfoItem(title: "Защита WebGL", text: "WebGL выдаёт модель видеокарты и драйвера. Защита подменяет эти данные на нейтральные (Apple GPU).", recommend: "Рекомендуем включить.")
    static let audioInfo = InfoItem(title: "Защита Audio", text: "Аудио-движок браузера тоже уникален и используется для слежки. Защита добавляет микрошум в аудио-отпечаток.", recommend: "Рекомендуем включить.")
    static let screenInfo = InfoItem(title: "Маскировать экран", text: "Размер и плотность экрана помогают вас отличить. Защита сообщает сайтам стандартные значения вместо реальных.", recommend: "Можно включить для большей анонимности.")
    static let navInfo = InfoItem(title: "Маскировать систему", text: "Скрывает признаки автоматизации и нормализует число ядер, память и список плагинов, чтобы устройство выглядело типовым.", recommend: "Рекомендуем включить.")
    static let geoInfo = InfoItem(title: "Геолокация", text: "Контролирует доступ сайтов к вашему местоположению. «Запрет» — сайты получают отказ. «Подмена» — отдаётся выбранная точка вместо реальной.", recommend: "Запрет — самый приватный вариант.")
    static let rtcInfo = InfoItem(title: "Блокировка WebRTC", text: "WebRTC может раскрыть ваш реальный IP даже через VPN. Блокировка закрывает эту утечку. Важно: реальный IP полностью скрывает только VPN/прокси — браузер сам IP не меняет.", recommend: "Включите, если не пользуетесь видеозвонками в браузере.")
    static let langInfo = InfoItem(title: "Подмена языка сайтов", text: "Сайты видят выбранный язык (например, English), а интерфейс приложения остаётся на вашем родном языке. Полезно, чтобы не выдавать страну по языку.", recommend: "Включайте по желанию.")
    static let tzInfo = InfoItem(title: "Подмена часового пояса", text: "Часовой пояс косвенно выдаёт ваш регион. Защита сообщает сайтам выбранный пояс вместо реального.", recommend: "Включайте по желанию.")
}
