import SwiftUI

// MARK: - Wallpaper
struct WallpaperView: View {
    let name: String
    var body: some View {
        Group {
            if let img = WallpaperLibrary.image(name) {
                Image(uiImage: img).resizable().scaledToFill()
            } else {
                LinearGradient(colors: [AeroColor.surface, AeroColor.bg], startPoint: .top, endPoint: .bottom)
            }
        }
    }
}

enum WallpaperLibrary {
    static let names: [String] = {
        guard let urls = Bundle.main.urls(forResourcesWithExtension: "jpg", subdirectory: "Wallpapers") else { return [] }
        return urls.map { $0.deletingPathExtension().lastPathComponent }.sorted()
    }()
    private static var cache: [String: UIImage] = [:]
    static func image(_ name: String) -> UIImage? {
        if let c = cache[name] { return c }
        guard let url = Bundle.main.url(forResource: name, withExtension: "jpg", subdirectory: "Wallpapers"),
              let img = UIImage(contentsOfFile: url.path) else { return nil }
        cache[name] = img
        return img
    }
}

// MARK: - Sheet chrome
struct SheetHeader: View {
    let title: String
    var trailing: AnyView? = nil
    var body: some View {
        HStack {
            Text(title).font(.system(size: 24, weight: .bold)).foregroundStyle(AeroColor.textPrimary)
            Spacer()
            if let trailing { trailing }
        }
        .padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 8)
    }
}

struct EmptyStateView: View {
    let symbol: String
    let text: String
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: symbol).font(.system(size: 40, weight: .thin)).foregroundStyle(AeroColor.textTertiary)
            Text(text).font(.system(size: 14)).foregroundStyle(AeroColor.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 220)
    }
}

// MARK: - Info popover (the "?" help)
struct InfoItem: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let text: String
    var recommend: String? = nil
}

struct InfoSheet: View {
    let item: InfoItem
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "info.circle.fill").foregroundStyle(AeroColor.accent)
                Text(item.title).font(.system(size: 20, weight: .bold)).foregroundStyle(AeroColor.textPrimary)
                Spacer()
            }
            Text(item.text).font(.system(size: 15)).foregroundStyle(AeroColor.textSecondary).fixedSize(horizontal: false, vertical: true)
            if let r = item.recommend {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "lightbulb.fill").foregroundStyle(AeroColor.success).font(.system(size: 13))
                    Text(r).font(.system(size: 14, weight: .medium)).foregroundStyle(AeroColor.textPrimary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(AeroColor.success.opacity(0.12)))
            }
            Button { dismiss() } label: {
                Text("Понятно").font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(height: 48)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(AeroColor.accent))
            }
            .buttonStyle(PressableStyle())
        }
        .padding(22)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Toggle row with optional "?" help
struct ToggleRow: View {
    let symbol: String
    let title: String
    var subtitle: String? = nil
    @Binding var isOn: Bool
    var help: InfoItem? = nil
    var onHelp: ((InfoItem) -> Void)? = nil

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).font(.system(size: 16, weight: .medium))
                .foregroundStyle(AeroColor.accent).frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 15, weight: .medium)).foregroundStyle(AeroColor.textPrimary)
                if let subtitle { Text(subtitle).font(.system(size: 12)).foregroundStyle(AeroColor.textTertiary) }
            }
            Spacer(minLength: 8)
            if let help, let onHelp {
                Button { Haptics.tap(); onHelp(help) } label: {
                    Image(systemName: "questionmark.circle").font(.system(size: 18)).foregroundStyle(AeroColor.textSecondary)
                }
                .buttonStyle(PressableStyle())
            }
            Toggle("", isOn: $isOn).labelsHidden().tint(AeroColor.accent)
        }
        .padding(.vertical, 10).padding(.horizontal, 14)
    }
}

// MARK: - Navigation row
struct NavRow: View {
    let symbol: String
    let title: String
    var tint: Color = AeroColor.accent
    var value: String? = nil
    let action: () -> Void
    var body: some View {
        Button { Haptics.tap(); action() } label: {
            HStack(spacing: 12) {
                Image(systemName: symbol).font(.system(size: 16, weight: .medium)).foregroundStyle(tint).frame(width: 26)
                Text(title).font(.system(size: 15, weight: .medium)).foregroundStyle(AeroColor.textPrimary)
                Spacer()
                if let value { Text(value).font(.system(size: 14)).foregroundStyle(AeroColor.textTertiary) }
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(AeroColor.textTertiary)
            }
            .padding(.vertical, 12).padding(.horizontal, 14).contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
    }
}

// MARK: - Grouped card container
struct GroupCard<Content: View>: View {
    var title: String? = nil
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let title {
                Text(title.uppercased()).font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AeroColor.textTertiary).padding(.leading, 16)
            }
            VStack(spacing: 0) { content }
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(AeroColor.card))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(AeroColor.stroke, lineWidth: 1))
        }
        .padding(.horizontal, 16)
    }
}

struct RowDivider: View {
    var body: some View { Rectangle().fill(AeroColor.stroke).frame(height: 1).padding(.leading, 52) }
}

struct SheetBackground: View {
    var body: some View { AeroColor.bg.ignoresSafeArea() }
}
