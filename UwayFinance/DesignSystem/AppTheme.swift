import SwiftUI

enum AppTheme {
    static let pageBackground = Color(uiColor: .systemGroupedBackground)
    static let surface = Color(uiColor: .secondarySystemGroupedBackground)
    static let elevatedSurface = Color(uiColor: .systemBackground)
    static let separator = Color(uiColor: .separator)
    static let brand = Color("BrandGreen")
    static let warning = Color.orange
    static let danger = Color.red

    static let cardRadius: CGFloat = 14
    static let compactRadius: CGFloat = 10
}

enum MotionToken {
    static let fast = Animation.easeOut(duration: 0.18)
    static let normal = Animation.snappy(duration: 0.24, extraBounce: 0.02)
    static let enter = Animation.smooth(duration: 0.34)
}

extension View {
    func appCard(padding: CGFloat = 16) -> some View {
        self
            .padding(padding)
            .background(AppTheme.elevatedSurface, in: RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
                    .stroke(AppTheme.separator.opacity(0.55), lineWidth: 0.5)
            }
    }
}

