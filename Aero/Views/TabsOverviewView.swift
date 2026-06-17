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
                    Text("\(browser.tabs.count) вкладок").font(.system(size: 20, weight: .bold)).foregroundStyle(AeroColor.textPrimary)
                    if browser.incognito {
                        HStack(spacing: 4) { Image(systemName: "eyeglasses"); Text("инкогнито") }
                            .font(.system(size: 11, weight: .semibold)).foregroundStyle(AeroColor.accent)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Capsule().fill(AeroColor.accentSoft))
                    }
                    Spacer()
                    Button { Haptics.tap(); withAnimation(AeroAnim.spring) { browser.closeAll() } } label: {
                        Text("Закрыть все").font(.system(size: 14, weight: .medium)).foregroundStyle(AeroColor.danger)
                    }
                }
                .padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 14)

                ScrollView {
                    LazyVGrid(columns: cols, spacing: 14) {
                        ForEach(browser.tabs) { tab in tabCard(tab) }
                    }
                    .padding(.horizontal, 16).padding(.bottom, 100)
                }
            }

            VStack {
                Spacer()
                Button { Haptics.tap(); onNew() } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                        Text("Новая вкладка").font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundStyle(.white).frame(maxWidth: .infinity).frame(height: 54)
                    .background(Capsule().fill(AeroColor.accent))
                    .shadow(color: AeroColor.accent.opacity(0.3), radius: 12, y: 4)
                }
                .buttonStyle(PressableStyle())
                .padding(.horizontal, 24).padding(.bottom, 28)
            }
        }
    }

    private func tabCard(_ tab: WebTab) -> some View {
        Button { Haptics.tap(); browser.select(tab); dismiss() } label: {
            VStack(alignment: .leading, spacing: 0) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14).fill(AeroColor.surface)
                    if let snap = tab.snapshot {
                        Image(uiImage: snap).resizable().scaledToFill().clipShape(RoundedRectangle(cornerRadius: 14))
                    } else {
                        Image(systemName: tab.isHome ? "location.north.fill" : "doc.text")
                            .font(.system(size: 28, weight: .light)).foregroundStyle(AeroColor.textTertiary)
                    }
                    VStack {
                        HStack {
                            Spacer()
                            Button { Haptics.tap(); withAnimation(AeroAnim.snappy) { browser.close(tab) } } label: {
                                Image(systemName: "xmark.circle.fill").font(.system(size: 22)).foregroundStyle(.white, .black.opacity(0.35))
                            }
                            .padding(8)
                        }
                        Spacer()
                    }
                }
                .frame(height: 180)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(tab.id == browser.currentID ? AeroColor.accent : AeroColor.stroke,
                                      lineWidth: tab.id == browser.currentID ? 2 : 1)
                )

                Text(tab.isHome ? "Новая вкладка" : tab.title)
                    .font(.system(size: 12, weight: .medium)).foregroundStyle(AeroColor.textPrimary)
                    .lineLimit(1).padding(.top, 8).padding(.horizontal, 4)
            }
        }
        .buttonStyle(PressableStyle(scale: 0.97))
    }
}
