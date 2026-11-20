import SwiftUI

/// Insights' cards (April, Nov 20): on the Menus look, Home's flat card (white on the paper, 22 pt corners),
/// no Liquid Glass. Other looks keep their glass.
struct InsightCard: ViewModifier {
    var tint: Color? = nil
    func body(content: Content) -> some View {
        if Crit.AppLook.current == .menus {
            content.background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color(uiColor: .secondarySystemGroupedBackground)))
        } else if let tint {
            content.glassEffect(.regular.tint(tint), in: .rect(cornerRadius: 22))
        } else {
            content.glassEffect(.regular, in: .rect(cornerRadius: 22))
        }
    }
}

extension View {
    func insightCard(tint: Color? = nil) -> some View { modifier(InsightCard(tint: tint)) }
}
