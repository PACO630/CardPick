import SwiftUI
import UIKit

struct RootView: View {
    @EnvironmentObject private var session: SessionModel
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        GeometryReader { geo in
            ZStack {
                InputCatcher(commands: commands,
                             scrollEnabled: session.phase == .deck && !session.showDestinations,
                             onScroll: { x in session.dragX = x },
                             onScrollEnd: { x, velocity in session.endDrag(x: x, predictedX: x + velocity) })
                    .frame(width: 1, height: 1)
                    .accessibilityHidden(true)

                switch session.phase {
                case .start:
                    StartView().transition(.opacity)
                case .loading:
                    LoadingView().transition(.opacity)
                case .deck, .done:
                    WorkspaceView(size: geo.size).transition(.opacity)
                }

                if session.phase != .loading {
                    BottomControls(width: geo.size.width)
                }

                if session.showDestinations {
                    DestinationPanel(compact: geo.size.width < 640)
                        .zIndex(50)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .onAppear { session.travel = geo.size.width * 1.15 }
            .onChange(of: geo.size) { size in session.travel = size.width * 1.15 }
        }
        // 底色：深色模式純黑、淺色模式純白，跟著系統外觀自動切換。
        .background((scheme == .dark ? Color.black : Color.white).ignoresSafeArea())
        .statusBarHidden(true)
        .alert(session.alert?.title ?? "", isPresented: Binding(
            get: { session.alert != nil },
            set: { if !$0 { session.alert = nil } }
        )) {
            Button("好") { session.alert = nil }
        } message: {
            Text(session.alert?.message ?? "")
        }
    }

    private var commands: [KeyCommandItem] {
        if session.showDestinations {
            return [KeyCommandItem(title: "關閉", input: UIKeyCommand.inputEscape) {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) { session.showDestinations = false }
            }]
        }
        var list: [KeyCommandItem] = []
        if session.phase == .deck {
            list.append(KeyCommandItem(title: "略過", input: UIKeyCommand.inputLeftArrow) { session.decide(.skip) })
            list.append(KeyCommandItem(title: "儲存", input: UIKeyCommand.inputRightArrow) { session.decide(.save) })
        }
        if session.canUndo {
            list.append(KeyCommandItem(title: "復原", input: "z", modifiers: .command) { session.undo() })
        }
        if session.phase != .loading {
            list.append(KeyCommandItem(title: "選擇記憶卡", input: "o", modifiers: .command) { session.chooseSource() })
            list.append(KeyCommandItem(title: "選擇儲存位置", input: "d", modifiers: .command) {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) { session.showDestinations = true }
            })
        }
        return list
    }
}
