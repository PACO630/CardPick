import SwiftUI

enum Palette {
    /// 「儲存」專用的綠色。白字在上面的對比為 4.6:1。
    static let save = Color(red: 0x24 / 255, green: 0x8A / 255, blue: 0x3D / 255)
    /// 「略過」用的灰色。
    static let skip = Color(white: 0.42)
}

/// 毛玻璃：只用系統模糊材質。
/// 「減少透明度」開啟時系統材質會自動變成不透明；「增加對比」時加上邊框。
struct GlassBackground<S: InsettableShape>: ViewModifier {
    let shape: S
    var strong = false

    @Environment(\.colorScheme) private var scheme
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        let dark = scheme == .dark
        return content
            .background(
                Group {
                    if strong {
                        shape.fill(.regularMaterial)
                    } else {
                        shape.fill(.thinMaterial)
                    }
                }
            )
            .overlay(shape.strokeBorder(Color.primary.opacity(contrast == .increased ? 0.45 : 0),
                                        lineWidth: 1))
            .shadow(color: .black.opacity(dark ? 0.35 : 0.08), radius: 14, x: 0, y: 4)
    }
}

extension View {
    func glass<S: InsettableShape>(_ shape: S, strong: Bool = false) -> some View {
        modifier(GlassBackground(shape: shape, strong: strong))
    }
}

/// 毛玻璃按鈕：按下會縮一點，滑鼠移上去會亮起。
struct GlassButtonStyle<S: InsettableShape>: ButtonStyle {
    let shape: S

    func makeBody(configuration: Configuration) -> some View {
        ButtonBody(configuration: configuration, shape: shape, glass: true)
    }
}

/// 沒有底的按鈕，只留內容（滑鼠移上去仍會亮起）。
struct BareButtonStyle<S: InsettableShape>: ButtonStyle {
    let shape: S

    func makeBody(configuration: Configuration) -> some View {
        ButtonBody(configuration: configuration, shape: shape, glass: false)
    }
}

private struct ButtonBody<S: InsettableShape>: View {
    let configuration: ButtonStyleConfiguration
    let shape: S
    let glass: Bool
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        configuration.label
            .foregroundColor(.primary)
            .modifier(OptionalGlass(shape: shape, enabled: glass))
            .contentShape(.hoverEffect, shape)
            .contentShape(shape)
            .hoverEffect(.highlight)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .opacity(isEnabled ? 1 : 0.4)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

private struct OptionalGlass<S: InsettableShape>: ViewModifier {
    let shape: S
    let enabled: Bool

    func body(content: Content) -> some View {
        if enabled {
            content.glass(shape)
        } else {
            content
        }
    }
}

/// 只有按壓縮放效果。
struct PressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// 所有按鈕共用的尺寸：高度、字級、左右留白都一樣，畫面才整齊。
enum Metrics {
    static let buttonHeight: CGFloat = 56
    static let buttonMinWidth: CGFloat = 132
    static let buttonFont = Font.system(size: 18, weight: .semibold)
    static let buttonPadding: CGFloat = 26
}

extension View {
    /// 膠囊按鈕的文字排版。
    func capsuleLabel() -> some View {
        font(Metrics.buttonFont)
            .lineLimit(1)
            .padding(.horizontal, Metrics.buttonPadding)
            .frame(minWidth: Metrics.buttonMinWidth, minHeight: Metrics.buttonHeight)
    }

    /// 實心膠囊（主要動作）：自訂底色，滑鼠移上去會亮起。
    func filledCapsule(_ fill: Color, text: Color) -> some View {
        foregroundColor(text)
            .background(Capsule().fill(fill))
            .contentShape(.hoverEffect, Capsule())
            .contentShape(Capsule())
    }
}
