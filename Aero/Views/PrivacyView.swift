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

                    // Master "max protection" card
                    VStack(spacing: 12) {
                        HStack(spacing: 10) {
                            Image(systemName: "shield.lefthalf.filled").font(.system(size: 18)).foregroundStyle(AeroColor.accent)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Максимальная защита").font(.system(size: 15, weight: .semibold)).foregroundStyle(AeroColor.textPrimary)
                                Text("Включено \(settings.privacyOnCount) из \(SettingsStore.privacyTotal)").font(.system(size: 12)).foregroundStyle(AeroColor.textSecondary)
                            }
                            Spacer()
                        }
                        HStack(spacing: 10) {
                            Button { Haptics.success(); settings.setAllPrivacy(true, includeRects: true); apply() } label: {
                                Text("Включить всё").font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                                    .frame(maxWidth: .infinity).frame(height: 42)
                                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(AeroColor.accent))
                            }.buttonStyle(PressableStyle())
                            Button { Haptics.tap(); settings.setAllPrivacy(false); apply() } label: {
                                Text("Сбросить").font(.system(size: 14, weight: .semibold)).foregroundStyle(AeroColor.textPrimary)
                                    .frame(maxWidth: .infinity).frame(height: 42)
                                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(AeroColor.field))
                            }.buttonStyle(PressableStyle())
                        }
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(AeroColor.card))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(AeroColor.stroke, lineWidth: 1))
                    .padding(.horizontal, 16)

                    GroupCard(title: "Отпечаток браузера") {
                        toggle("paintbrush.pointed.fill", "Защита Canvas", $settings.pCanvas, Self.canvasInfo)
                        RowDivider()
                        toggle("cube.transparent", "Защита WebGL / WebGPU", $settings.pWebGL, Self.webglInfo)
                        RowDivider()
                        toggle("waveform", "Защита Audio", $settings.pAudio, Self.audioInfo)
                        RowDivider()
                        toggle("textformat", "Защита шрифтов", $settings.pFonts, Self.fontsInfo)
                        RowDivider()
                        toggle("rectangle.on.rectangle", "Маскировать экран", $settings.pScreen, Self.screenInfo)
                        RowDivider()
                        toggle("cpu", "Маскировать систему", $settings.pNavigator, Self.navInfo)
                    }

                    GroupCard(title: "Дополнительно") {
                        toggle("timer", "Снижать точность таймеров", $settings.pTiming, Self.timingInfo)
                        RowDivider()
                        toggle("ruler", "Защита геометрии элементов", $settings.pRects, Self.rectsInfo)
                        RowDivider()
                        toggle("mic.slash", "Скрыть медиаустройства", $settings.pMedia, Self.mediaInfo)
                        RowDivider()
                        toggle("battery.25", "Скрыть статус батареи", $settings.pBattery, Self.batteryInfo)
                        RowDivider()
                        toggle("gyroscope", "Блок датчиков движения", $settings.pSensors, Self.sensorsInfo)
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
    static let webglInfo = InfoItem(title: "Защита WebGL / WebGPU", text: "WebGL и WebGPU выдают модель видеокарты, драйвер и поддерживаемые расширения. Защита подменяет вендора/рендерер на нейтральные (Apple GPU), скрывает debug-расширение, добавляет шум в readPixels и отключает navigator.gpu.", recommend: "Рекомендуем включить.")
    static let audioInfo = InfoItem(title: "Защита Audio", text: "Аудио-движок браузера уникален и используется для слежки. Защита добавляет микрошум в частотные и временные данные AnalyserNode и в AudioBuffer.", recommend: "Рекомендуем включить.")
    static let fontsInfo = InfoItem(title: "Защита шрифтов", text: "Сайты определяют набор установленных шрифтов по ширине отрисованного текста (measureText) и проверкам document.fonts. Защита добавляет микрошум в измерения и ограничивает проверки системными шрифтами.", recommend: "Рекомендуем включить — на вид сайтов не влияет.")
    static let timingInfo = InfoItem(title: "Снижение точности таймеров", text: "Высокоточные таймеры (performance.now, Date.now) позволяют замерять микрозадержки и строить отпечаток. Защита округляет время, снижая точность таких замеров.", recommend: "Безопасно, можно включить.")
    static let rectsInfo = InfoItem(title: "Защита геометрии элементов", text: "getBoundingClientRect/getClientRects возвращают суб-пиксельные размеры, по которым тоже строят отпечаток. Защита добавляет крошечный шум.", recommend: "Может слегка влиять на сложные сайты — включайте при необходимости.")
    static let mediaInfo = InfoItem(title: "Скрыть медиаустройства", text: "enumerateDevices() показывает камеры/микрофоны и их идентификаторы. Защита возвращает пустой список и блокирует захват экрана.", recommend: "Включите, если не пользуетесь камерой/микрофоном в браузере.")
    static let batteryInfo = InfoItem(title: "Скрыть статус батареи", text: "Battery API сообщает уровень заряда и состояние — это редкий, но рабочий признак слежки. Защита делает API недоступным.", recommend: "Рекомендуем включить.")
    static let sensorsInfo = InfoItem(title: "Блок датчиков движения", text: "Гироскоп, акселерометр и магнитометр выдают модель устройства и микродвижения. Защита отключает эти датчики и события движения.", recommend: "Включите, если сайтам не нужен наклон/движение устройства.")
    static let screenInfo = InfoItem(title: "Маскировать экран", text: "Размер и плотность экрана помогают вас отличить. Защита сообщает сайтам стандартные значения вместо реальных.", recommend: "Можно включить для большей анонимности.")
    static let navInfo = InfoItem(title: "Маскировать систему", text: "Нормализует navigator: число ядер, память, vendor/platform, productSub, doNotTrack, скрывает userAgentData, плагины, mimeTypes, нормализует тип сети и геймпады, убирает признак автоматизации (webdriver).", recommend: "Рекомендуем включить.")
    static let geoInfo = InfoItem(title: "Геолокация", text: "Контролирует доступ сайтов к вашему местоположению. «Запрет» — сайты получают отказ. «Подмена» — отдаётся выбранная точка вместо реальной.", recommend: "Запрет — самый приватный вариант.")
    static let rtcInfo = InfoItem(title: "Блокировка WebRTC", text: "WebRTC может раскрыть ваш реальный IP даже через VPN. Блокировка закрывает эту утечку. Важно: реальный IP полностью скрывает только VPN/прокси — браузер сам IP не меняет.", recommend: "Включите, если не пользуетесь видеозвонками в браузере.")
    static let langInfo = InfoItem(title: "Подмена языка сайтов", text: "Сайты видят выбранный язык (например, English), а интерфейс приложения остаётся на вашем родном языке. Полезно, чтобы не выдавать страну по языку.", recommend: "Включайте по желанию.")
    static let tzInfo = InfoItem(title: "Подмена часового пояса", text: "Часовой пояс косвенно выдаёт ваш регион. Защита сообщает сайтам выбранный пояс вместо реального.", recommend: "Включайте по желанию.")
}
