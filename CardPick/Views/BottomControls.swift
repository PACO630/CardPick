import SwiftUI

/// 下方浮動控制列：左下復原、中間略過／儲存、右下儲存位置。
struct BottomControls: View {
    @EnvironmentObject private var session: SessionModel
    let width: CGFloat

    private var compact: Bool { width < 640 }

    var body: some View {
        ZStack(alignment: .bottom) {
            HStack(alignment: .bottom) {
                if session.phase == .deck || session.phase == .done {
                    Button { session.undo() } label: {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 22, weight: .semibold))
                            .frame(width: Metrics.buttonHeight, height: Metrics.buttonHeight)
                    }
                    .buttonStyle(GlassButtonStyle(shape: Circle()))
                    .disabled(!session.canUndo)
                    .accessibilityLabel("復原上一步")
                    .transition(.scale.combined(with: .opacity))
                }
                Spacer(minLength: 12)
                DestinationButton(compact: compact)
            }

            if session.phase == .deck {
                DecisionButtons(compact: compact)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }
}

private struct DecisionButtons: View {
    @EnvironmentObject private var session: SessionModel
    let compact: Bool

    var body: some View {
        HStack(spacing: 12) {
            Button { session.decide(.skip) } label: {
                Text("略過").capsuleLabel()
            }
            .buttonStyle(GlassButtonStyle(shape: Capsule()))

            Button { session.decide(.save) } label: {
                Text("儲存").capsuleLabel().filledCapsule(Palette.save, text: .white)
            }
            .buttonStyle(PressButtonStyle())
            .hoverEffect(.highlight)
        }
    }
}

private struct DestinationButton: View {
    @EnvironmentObject private var session: SessionModel
    let compact: Bool

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) { session.showDestinations.toggle() }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(Color.primary.opacity(0.1))
                    Image(systemName: "folder")
                        .font(.system(size: 18, weight: .medium))
                }
                .frame(width: 40, height: 40)

                if !compact {
                    Text(shortTitle)
                        .font(Metrics.buttonFont)
                        .lineLimit(1)
                }

                Image(systemName: "chevron.up")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.secondary)
                    .rotationEffect(.degrees(session.showDestinations ? 180 : 0))
            }
            .padding(.leading, 8)
            .padding(.trailing, 22)
            .frame(height: Metrics.buttonHeight)
            .fixedSize()
        }
        .buttonStyle(GlassButtonStyle(shape: Capsule()))
        .accessibilityLabel("儲存位置：\(session.destination.title)")
    }

    /// 名稱太長時截短，膠囊才不會撐得太寬。
    private var shortTitle: String {
        let title = session.destination.title
        return title.count > 16 ? String(title.prefix(15)) + "…" : title
    }
}
