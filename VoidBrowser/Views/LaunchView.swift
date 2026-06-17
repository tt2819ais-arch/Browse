import SwiftUI

struct LaunchView: View {
    @State private var ring = false
    @State private var glow = false

    var body: some View {
        ZStack {
            VoidColor.bg.ignoresSafeArea()
            RadialGradient(colors: [VoidColor.accent.opacity(0.18), .clear],
                           center: .center, startRadius: 10, endRadius: 320)
                .ignoresSafeArea()
                .opacity(glow ? 1 : 0.4)

            VStack(spacing: 22) {
                ZStack {
                    Circle()
                        .strokeBorder(VoidColor.accent.opacity(0.9), lineWidth: 2.5)
                        .frame(width: 92, height: 92)
                        .scaleEffect(ring ? 1 : 0.7)
                        .opacity(ring ? 1 : 0)
                    Circle()
                        .strokeBorder(VoidColor.accent.opacity(0.25), lineWidth: 1)
                        .frame(width: 124, height: 124)
                        .scaleEffect(ring ? 1 : 0.6)
                        .opacity(ring ? 1 : 0)
                    Image(systemName: "globe")
                        .font(.system(size: 34, weight: .light))
                        .foregroundStyle(VoidColor.textPrimary)
                        .opacity(ring ? 1 : 0)
                }
                Text("VOID BROWSER")
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .tracking(4)
                    .foregroundStyle(VoidColor.textSecondary)
                    .opacity(ring ? 1 : 0)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) { ring = true }
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) { glow = true }
        }
    }
}
