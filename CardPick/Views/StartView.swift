import SwiftUI

struct StartView: View {
    @EnvironmentObject private var session: SessionModel

    var body: some View {
        VStack(spacing: 0) {
            Text("CardPick")
                .font(.system(size: 64, weight: .bold))

            // 兩顆按鈕寬度一致。
            VStack(spacing: 12) {
                Button { session.chooseSource() } label: {
                    Label("選擇記憶卡", systemImage: "sdcard")
                        .capsuleLabel()
                        .frame(maxWidth: .infinity)
                        .filledCapsule(.primary, text: Color(uiColor: .systemBackground))
                }
                .buttonStyle(PressButtonStyle())
                .hoverEffect(.highlight)

                if let last = session.lastSource {
                    Button { session.resumeLast() } label: {
                        Label("繼續挑選「\(last.name)」", systemImage: "clock.arrow.circlepath")
                            .capsuleLabel()
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(GlassButtonStyle(shape: Capsule()))
                }
            }
            .fixedSize(horizontal: true, vertical: false)
            .padding(.top, 32)
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 60)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct LoadingView: View {
    @EnvironmentObject private var session: SessionModel

    var body: some View {
        VStack(spacing: 14) {
            ProgressView().controlSize(.large)
            Text("正在讀取「\(session.sourceName)」…")
                .font(.headline)
            Text("已找到 \(session.loadingCount.formatted()) 張相片")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
