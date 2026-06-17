import SwiftUI

/// Loads a bundled wallpaper image by name from the Wallpapers resource folder.
struct WallpaperView: View {
    let name: String

    var body: some View {
        Group {
            if let img = WallpaperLibrary.image(name) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
            } else {
                LinearGradient(colors: [VoidColor.bg, VoidColor.bgRaised],
                               startPoint: .top, endPoint: .bottom)
            }
        }
    }
}

enum WallpaperLibrary {
    /// All bundled wallpaper base names (void-01 ... void-NN), discovered at runtime.
    static let names: [String] = {
        guard let urls = Bundle.main.urls(forResourcesWithExtension: "jpg", subdirectory: "Wallpapers") else {
            return []
        }
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

/// A simple section header used across sheets.
struct SheetHeader: View {
    let title: String
    var trailing: AnyView? = nil
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(VoidColor.textPrimary)
            Spacer()
            if let trailing { trailing }
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 6)
    }
}

struct EmptyStateView: View {
    let symbol: String
    let text: String
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 38, weight: .ultraLight))
                .foregroundStyle(VoidColor.textTertiary)
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(VoidColor.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 220)
    }
}

struct SheetBackground: View {
    var body: some View {
        ZStack {
            VoidColor.bg.ignoresSafeArea()
            RadialGradient(colors: [VoidColor.accent.opacity(0.10), .clear],
                           center: .topLeading, startRadius: 10, endRadius: 380)
                .ignoresSafeArea()
        }
    }
}
