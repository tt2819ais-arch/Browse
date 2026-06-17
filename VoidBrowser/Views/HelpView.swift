import SwiftUI

struct HelpView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var text: String = ""

    var body: some View {
        ZStack {
            SheetBackground()
            VStack(spacing: 0) {
                HStack {
                    Text("Справка")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(VoidColor.textPrimary)
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(VoidColor.textTertiary)
                    }
                }
                .padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 12)

                ScrollView {
                    Text(attributed)
                        .font(.system(size: 15))
                        .foregroundStyle(VoidColor.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(20)
                }
            }
        }
        .onAppear(perform: load)
    }

    private var attributed: AttributedString {
        (try? AttributedString(markdown: text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
            ?? AttributedString(text)
    }

    private func load() {
        if let url = Bundle.main.url(forResource: "guide", withExtension: "md", subdirectory: "Help"),
           let s = try? String(contentsOf: url, encoding: .utf8) {
            text = s
        } else {
            text = "Руководство недоступно."
        }
    }
}
