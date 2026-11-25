import SwiftUI

@main
struct CardPickApp: App {
    @StateObject private var session = SessionModel()
    @StateObject private var library = PhotoLibraryService()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .environmentObject(library)
                .onAppear { DemoData.startIfRequested(session) }
                .onChange(of: scenePhase) { phase in
                    // 切到別的 App 時，把右滑的相片全部寫入，避免遺失。
                    if phase == .background { session.flushSaves() }
                }
        }
    }
}
