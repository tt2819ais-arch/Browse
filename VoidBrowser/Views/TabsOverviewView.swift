import SwiftUI

struct TabsOverviewView: View {
    @EnvironmentObject var browser: BrowserStore
    @Environment(\.dismiss) private var dismiss
    let onNew: () -> Void

    private let cols = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        ZStack {
            SheetBackground()
            VStack(spacing: 0) {
                HStack {
                    Text("\(browser.tabs.count) вкладок")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(VoidColor.textPrimary)
                    Spacer()
                    Button { Haptics.tap(); browser.closeAll() } label: {
                        Text("Закрыть все")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(VoidColor.danger)
                    }
                }
                .padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 14)

                ScrollView {
                    LazyVGrid(columns: cols, spacing: 14) {
                        ForEach(browser.tabs) { tab in
                            tabCard(tab)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 100)
                }
            }

            VStack {
                Spacer()
                Button { Haptics.tap(); onNew() } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                        Text("Новая вкладка").font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundStyle(VoidColor.bg)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Capsule().fill(VoidColor.accent))
                }
                .buttonStyle(PressableStyle())
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
            }
        }
    }

    private func tabCard(_ tab: WebTab) -> some View {
        Button {
            Haptics.tap()
            browser.select(tab)
            dismiss()
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(VoidColor.bgRaised)
                    if let snap = tab.snapshot {
                        Image(uiImage: snap)
                            .resizable()
                            .scaledToFill()
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    } else {
                        Image(systemName: tab.isHome ? "globe" : "doc.text")
                            .font(.system(size: 30, weight: .ultraLight))
                            .foregroundStyle(VoidColor.textTertiary)
                    }
                    VStack {
                        HStack {
                            Spacer()
                            Button {
                                Haptics.tap()
                                withAnimation { browser.close(tab) }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 22))
                                    .foregroundStyle(.white, .black.opacity(0.4))
                            }
                            .padding(8)
                        }
                        Spacer()
                    }
                }
                .frame(height: 180)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(tab.id == browser.currentID ? VoidColor.accent : VoidColor.stroke,
                                      lineWidth: tab.id == browser.currentID ? 2 : 1)
                )

                Text(tab.isHome ? "Новая вкладка" : tab.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(VoidColor.textPrimary)
                    .lineLimit(1)
                    .padding(.top, 8)
                    .padding(.horizontal, 4)
            }
        }
        .buttonStyle(PressableStyle(scale: 0.97))
    }
}
