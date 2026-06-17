# Void Browser

Минималистичный нативный iOS-браузер на SwiftUI + WKWebView. Тёмная «void»-эстетика: почти чёрный фон, лавандовый акцент, стеклянные карточки, аккуратные SF Symbols-иконки.

## Возможности (MVP)

- 🔎 Умная адресная строка (URL или поиск; авто-определение)
- 🌐 Полноценный движок WebKit (WKWebView)
- ◀️ ▶️ 🔄 ⏹️ Навигация: назад / вперёд / обновить / стоп
- 📊 Индикатор загрузки
- 🏠 Домашний экран с быстрыми ссылками и обоями
- 🗂️ Мультивкладки с превью
- ⭐ Закладки
- 🕘 История
- ⬇️ Pull-to-refresh
- 🔗 Системный Share Sheet
- ⚙️ Настройки: поисковик (Google / DuckDuckGo / Яндекс / Bing), версия для ПК, обои, очистка данных
- 📖 Встроенная справка

## Поисковые системы
Google · DuckDuckGo · Яндекс · Bing

## Сборка `.ipa` (без подписи)

Проект собирается через **XcodeGen + GitHub Actions**.

> ⚠️ GitHub App не может пушить файлы в `.github/workflows/`. Поэтому workflow лежит в репозитории как текст — `ci/ios-ipa.yml.txt`. Создайте файл `.github/workflows/ios-ipa.yml` вручную через веб-интерфейс GitHub («Add file → Create new file»), вставив содержимое из `ci/ios-ipa.yml.txt`.

После пуша в `main` Actions соберёт неподписанный `VoidBrowser-unsigned.ipa` (артефакт). Устанавливается через AltStore / Sideloadly / Xcode; подпись — в Esign.

## Локальная сборка

```bash
brew install xcodegen
xcodegen generate
open VoidBrowser.xcodeproj
```

## Бандл-ресурсы
- `Resources/Wallpapers/` — HD-обои для домашнего экрана (генерируются, void-стиль)
- `Resources/Fonts/` — офлайн-библиотека шрифтов (OFL, для режима чтения и типографики)
- `Resources/Help/` — встроенное руководство

## Структура
- `App.swift` — точка входа, состояние приложения
- `Web/WebTab.swift` — обёртка WKWebView, одна на вкладку (KVO: прогресс, заголовок, навигация)
- `Stores/` — состояние (вкладки, закладки, история, настройки)
- `Views/` — UI (RootView, HomeView, вкладки, закладки, история, настройки, меню, справка)
- `Theme/Theme.swift` — палитра, фон, компоненты
