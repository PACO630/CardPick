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
                    // 離開 App 前把還在等待的儲存全部寫入，避免遺失。
                    if phase != .active { session.flushSaves() }
                }
        }
    }
}
