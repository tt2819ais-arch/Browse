import SwiftUI

struct HelpView: View {
    @State private var text: String = ""

    var body: some View {
        ZStack {
            SheetBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // About card
                    VStack(spacing: 12) {
                        ZStack {
                            Circle().stroke(AeroColor.accent, lineWidth: 5).frame(width: 60, height: 60)
                            Image(systemName: "location.north.fill").font(.system(size: 24, weight: .semibold))
                                .foregroundStyle(AeroColor.accent).rotationEffect(.degrees(45))
                        }
                        Text("Aero").font(.system(size: 24, weight: .bold)).foregroundStyle(AeroColor.textPrimary)
                        Text("Версия 1.3").font(.system(size: 13)).foregroundStyle(AeroColor.textTertiary)
                        Text("Быстрый, минималистичный и приватный браузер на WebKit.")
                            .font(.system(size: 13)).foregroundStyle(AeroColor.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(20)
                    .background(RoundedRectangle(cornerRadius: 18).fill(AeroColor.card))
                    .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(AeroColor.stroke, lineWidth: 1))
                    .padding(.horizontal, 16)

                    Text(attributed)
                        .font(.system(size: 15))
                        .foregroundStyle(AeroColor.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)

                    Spacer().frame(height: 20)
                }
                .padding(.top, 10)
            }
        }
        .navigationTitle("Справка")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: load)
    }

    private var attributed: AttributedString {
        (try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
            ?? AttributedString(text)
    }

    private func load() {
        if let url = Bundle.main.url(forResource: "guide", withExtension: "md", subdirectory: "Help"),
           let s = try? String(contentsOf: url, encoding: .utf8) {
            text = s
        } else { text = "Руководство недоступно." }
    }
}
