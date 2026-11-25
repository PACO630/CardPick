import SwiftUI
import Photos

/// 右下角按鈕叫出的玻璃面板：選擇「照片」相簿或「檔案」資料夾。
struct DestinationPanel: View {
    @EnvironmentObject private var session: SessionModel
    @EnvironmentObject private var library: PhotoLibraryService
    let compact: Bool

    @State private var askingName = false
    @State private var newName = ""

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color.black.opacity(0.18)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { close() }
                .accessibilityLabel("關閉")
                .accessibilityAddTraits(.isButton)
                .transition(.opacity)

            VStack(alignment: .leading, spacing: 0) {
                Text("儲存到")
                    .font(.title3.weight(.bold))
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 10)

                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        SectionTitle("照片")
                        photosSection
                        SectionTitle("檔案").padding(.top, 6)
                        filesSection
                    }
                    .padding(.bottom, 4)
                }
                .frame(maxHeight: 440)
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(10)
            .frame(width: compact ? 320 : 380)
            .glass(RoundedRectangle(cornerRadius: 30, style: .continuous), strong: true)
            .padding(.trailing, 24)
            .padding(.bottom, 24 + 64 + 14)
            .transition(.scale(scale: 0.92, anchor: .bottomTrailing).combined(with: .opacity))
            .accessibilityAddTraits(.isModal)
        }
        .onAppear { library.reload() }
        .alert("新增相簿", isPresented: $askingName) {
            TextField("相簿名稱", text: $newName)
            Button("取消", role: .cancel) { newName = "" }
            Button("建立") { createAlbum() }
        }
    }

    @ViewBuilder
    private var photosSection: some View {
        switch library.status {
        case .notDetermined:
            Row(title: "允許取用「照片」", subtitle: nil, selected: false) {
                IconTile(symbol: "photo.on.rectangle", tint: nil)
            } action: {
                Task { await library.requestAccess() }
            }
        case .denied, .restricted:
            Row(title: "到「設定」允許取用照片", subtitle: nil, selected: false) {
                IconTile(symbol: "gear", tint: nil)
            } action: {
                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
            }
        default:
            Row(title: "照片圖庫", subtitle: nil, selected: session.destination == .library) {
                IconTile(symbol: "photo.on.rectangle", tint: nil)
            } action: {
                session.setDestination(.library)
            }
            ForEach(library.albums) { album in
                let value = Destination.album(id: album.id, name: album.name)
                Row(title: album.name, subtitle: nil, selected: session.destination == value) {
                    AlbumThumb(assetID: album.keyAssetID)
                } action: {
                    session.setDestination(value)
                }
            }
            Row(title: "新增相簿…", subtitle: nil, selected: false) {
                IconTile(symbol: "plus", tint: nil)
            } action: {
                newName = ""
                askingName = true
            }
        }
    }

    @ViewBuilder
    private var filesSection: some View {
        ForEach(session.recentFolders) { folder in
            let value = Destination.folder(bookmark: folder.bookmark, name: folder.name)
            Row(title: folder.name, subtitle: nil, selected: session.destination == value) {
                IconTile(symbol: "folder.fill", tint: .blue)
            } action: {
                session.setDestination(value)
            }
        }
        Row(title: "選擇資料夾…", subtitle: nil, selected: false) {
            IconTile(symbol: "folder.badge.plus", tint: nil)
        } action: {
            session.chooseFolderDestination()
        }
    }

    private func close() {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) { session.showDestinations = false }
    }

    private func createAlbum() {
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        newName = ""
        guard !name.isEmpty else { return }
        Task {
            do {
                let album = try await library.createAlbum(named: name)
                session.setDestination(.album(id: album.id, name: album.name))
            } catch {
                session.alert = AlertInfo(title: "無法建立相簿", message: error.localizedDescription)
            }
        }
    }
}

private struct SectionTitle: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.footnote.weight(.semibold))
            .foregroundColor(.secondary)
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 4)
            .accessibilityAddTraits(.isHeader)
    }
}

private struct Row<Icon: View>: View {
    let title: String
    let subtitle: String?
    let selected: Bool
    @ViewBuilder let icon: () -> Icon
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                icon()
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.body)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    if let subtitle {
                        Text(subtitle)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 8)
                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.primary)
                }
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 56)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.primary.opacity(selected ? 0.1 : 0)))
            .contentShape(.hoverEffect, RoundedRectangle(cornerRadius: 18, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressButtonStyle())
        .hoverEffect(.highlight)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private struct IconTile: View {
    let symbol: String
    let tint: Color?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(tint ?? Color.primary.opacity(0.1))
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(tint == nil ? .primary : .white)
        }
        .frame(width: 40, height: 40)
        .accessibilityHidden(true)
    }
}

private struct AlbumThumb: View {
    let assetID: String?
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Color.primary.opacity(0.1))
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Image(systemName: "photo.on.rectangle")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 40, height: 40)
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .accessibilityHidden(true)
        .onAppear(perform: load)
    }

    private func load() {
        guard image == nil, let assetID,
              let asset = PHAsset.fetchAssets(withLocalIdentifiers: [assetID], options: nil).firstObject else { return }
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.isNetworkAccessAllowed = true
        PHImageManager.default().requestImage(for: asset, targetSize: CGSize(width: 120, height: 120),
                                              contentMode: .aspectFill, options: options) { result, _ in
            DispatchQueue.main.async { if let result { image = result } }
        }
    }
}
