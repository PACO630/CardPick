import SwiftUI

/// 卡片畫面與「看完了」畫面，上方有記憶卡名稱、相片資訊與進度。
struct WorkspaceView: View {
    @EnvironmentObject private var session: SessionModel
    let size: CGSize

    private let topReserve: CGFloat = 84
    private let bottomReserve: CGFloat = 112
    private let peek: CGFloat = 44

    var body: some View {
        let box = CGSize(width: max(200, size.width - 80),
                         height: max(200, size.height - topReserve - bottomReserve - peek))
        ZStack(alignment: .top) {
            if session.phase == .deck {
                DeckView(box: box)
                    .position(x: size.width / 2, y: topReserve + box.height / 2 + 4)
            } else {
                DoneView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.opacity)
            }
            TopBar(width: size.width)
                .padding(.horizontal, 24)
                .padding(.top, 20)
        }
        .frame(width: size.width, height: size.height)
    }
}

struct TopBar: View {
    @EnvironmentObject private var session: SessionModel
    let width: CGFloat

    var body: some View {
        ZStack {
            HStack {
                Button { session.goStart() } label: {
                    Label(session.sourceName, systemImage: "sdcard")
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .frame(maxWidth: 260, alignment: .leading)
                        .frame(height: 44)
                }
                .buttonStyle(BareButtonStyle(shape: Capsule()))
                .accessibilityHint("回到開始畫面，換一張記憶卡")

                Spacer()

                if session.phase == .deck {
                    ProgressPill(position: session.position, total: session.queue.count)
                }
            }

            if let toast = session.toast {
                Label(toast, systemImage: "checkmark")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .padding(.horizontal, 20)
                    .frame(height: 44)
                    .glass(Capsule())
                    .frame(maxWidth: max(200, width - 560))
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
                    .id(toast)
            } else if width >= 640, session.phase == .deck, let item = session.current {
                MetaView(item: item)
                    .frame(maxWidth: max(200, width - 560))
            }
        }
        .frame(height: 44)
    }
}

private struct ProgressPill: View {
    let position: Int
    let total: Int

    var body: some View {
        let shown = min(position + 1, total)
        let fraction = total > 0 ? CGFloat(position) / CGFloat(total) : 0
        HStack(spacing: 12) {
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.15))
                Capsule().fill(Color.primary).frame(width: 72 * fraction)
            }
            .frame(width: 72, height: 6)
            .animation(.easeOut(duration: 0.3), value: fraction)

            Text("\(shown.formatted()) / \(total.formatted())")
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
        }
        .frame(height: 44)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("第 \(shown) 張，共 \(total) 張")
    }
}

private struct MetaView: View {
    let item: PhotoItem
    @State private var meta: PhotoMeta?

    var body: some View {
        VStack(spacing: 1) {
            HStack(spacing: 6) {
                Text(item.displayName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                if let kind = item.kindLabel {
                    Text(kind)
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.primary.opacity(0.1)))
                }
            }
            Text(meta?.dateText ?? " ")
                .font(.footnote)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .task(id: item.id) {
            meta = ImageLoader.shared.meta(for: item)
            if meta == nil {
                _ = await ImageLoader.shared.image(for: item)
                meta = ImageLoader.shared.meta(for: item)
            }
        }
    }
}

struct DoneView: View {
    @EnvironmentObject private var session: SessionModel

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle().fill(Palette.save)
                Image(systemName: "checkmark")
                    .font(.system(size: 42, weight: .bold))
                    .foregroundColor(.white)
            }
            .frame(width: 96, height: 96)
            .accessibilityHidden(true)

            Text("搞定！")
                .font(.system(size: 34, weight: .bold))
                .padding(.top, 28)

            Text("已儲存 \(session.savedCount.formatted()) 張，略過 \(session.skippedCount.formatted()) 張")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 480)
                .padding(.top, 10)

            HStack(spacing: 12) {
                if session.skippedCount > 0 {
                    Button { session.reviewSkipped() } label: {
                        Text("再看一次略過的相片").capsuleLabel().frame(maxWidth: .infinity)
                    }
                    .buttonStyle(GlassButtonStyle(shape: Capsule()))
                }
                Button { session.chooseSource() } label: {
                    Text("換一張記憶卡")
                        .capsuleLabel()
                        .frame(maxWidth: .infinity)
                        .filledCapsule(.primary, text: Color(uiColor: .systemBackground))
                }
                .buttonStyle(PressButtonStyle())
                .hoverEffect(.highlight)
            }
            .fixedSize(horizontal: true, vertical: false)
            .padding(.top, 32)
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 40)
    }
}
