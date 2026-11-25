import SwiftUI

/// 疊在一起的相片卡：最上面那張可以拖曳，後面兩張露出一點邊。
struct DeckView: View {
    @EnvironmentObject private var session: SessionModel
    let box: CGSize

    var body: some View {
        ZStack {
            ForEach(Array(session.visible.enumerated()), id: \.element.id) { depth, item in
                card(item, depth: depth)
            }
            ForEach(session.departing) { flying in
                DepartingCard(flying: flying, box: box, travel: session.travel)
                    .zIndex(100)
            }
        }
        .frame(width: box.width, height: box.height)
    }

    @ViewBuilder
    private func card(_ item: PhotoItem, depth: Int) -> some View {
        let isTop = depth == 0
        let x = isTop ? session.dragX : 0
        let insertion: AnyTransition = session.arrivalX == 0 ? .opacity : .offset(x: session.arrivalX)
        PhotoCard(item: item, box: box, swipe: x)
            .brightness(isTop ? 0 : -0.07 * Double(depth))
            .scaleEffect(isTop ? 1 : 1 - 0.06 * CGFloat(depth), anchor: .bottom)
            .offset(y: isTop ? 0 : CGFloat(depth) * 22)
            .rotationEffect(.degrees(Double(x / 26)), anchor: .bottom)
            .offset(x: x, y: abs(x) * 0.04)
            .zIndex(Double(10 - depth))
            .transition(.asymmetric(insertion: insertion, removal: .identity))
            .gesture(dragGesture, including: isTop ? .all : .none)
            .allowsHitTesting(isTop)
            .accessibilityHidden(!isTop)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("相片 \(item.displayName)")
            .accessibilityHint("向右滑儲存，向左滑略過")
            .accessibilityAction(named: "儲存") { session.decide(.save) }
            .accessibilityAction(named: "略過") { session.decide(.skip) }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { value in session.dragX = value.translation.width }
            .onEnded { value in
                session.endDrag(x: value.translation.width, predictedX: value.predictedEndTranslation.width)
            }
    }
}

/// 一張相片卡。swipe 是目前水平拖曳的距離，用來顯示「儲存」「略過」標記。
struct PhotoCard: View {
    let item: PhotoItem
    let box: CGSize
    let swipe: CGFloat

    @State private var image: UIImage?
    @Environment(\.colorScheme) private var scheme

    init(item: PhotoItem, box: CGSize, swipe: CGFloat) {
        self.item = item
        self.box = box
        self.swipe = swipe
        _image = State(initialValue: ImageLoader.shared.cachedImage(for: item))
    }

    var body: some View {
        let aspect = image.map { $0.size.width / max($0.size.height, 1) } ?? 1.5
        let size = Self.fit(aspect: aspect, in: box)
        let shape = RoundedRectangle(cornerRadius: 28, style: .continuous)
        let saveAmount = min(max(swipe / 120, 0), 1)
        let skipAmount = min(max(-swipe / 120, 0), 1)

        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
            } else {
                Rectangle().fill(Color.primary.opacity(0.08))
                ProgressView()
            }
        }
        .frame(width: size.width, height: size.height)
        .overlay {
            ZStack {
                SwipeMark(symbol: "checkmark", fill: Palette.save)
                    .opacity(saveAmount)
                    .scaleEffect(0.6 + 0.4 * saveAmount)
                SwipeMark(symbol: "xmark", fill: Palette.skip)
                    .opacity(skipAmount)
                    .scaleEffect(0.6 + 0.4 * skipAmount)
            }
        }
        .clipShape(shape)
        .overlay(shape.strokeBorder(Color.primary.opacity(scheme == .dark ? 0.12 : 0.06), lineWidth: 1))
        .shadow(color: .black.opacity(scheme == .dark ? 0.6 : 0.18), radius: 30, x: 0, y: 16)
        .task(id: item.id) {
            guard image == nil else { return }
            let loaded = await ImageLoader.shared.image(for: item)
            withAnimation(.easeOut(duration: 0.2)) { image = loaded }
        }
    }

    static func fit(aspect: CGFloat, in box: CGSize) -> CGSize {
        let a = min(max(aspect, 0.2), 5)
        var width = box.width
        var height = width / a
        if height > box.height {
            height = box.height
            width = height * a
        }
        return CGSize(width: width, height: height)
    }
}

/// 滑動時出現在卡片正中央的圓形圖示：綠色勾勾＝儲存，灰色叉叉＝略過。
private struct SwipeMark: View {
    let symbol: String
    let fill: Color

    var body: some View {
        ZStack {
            Circle().fill(fill)
            Image(systemName: symbol)
                .font(.system(size: 50, weight: .bold))
                .foregroundColor(.white)
        }
        .frame(width: 120, height: 120)
        .shadow(color: .black.opacity(0.3), radius: 16, x: 0, y: 8)
        .accessibilityHidden(true)
    }
}

/// 被滑走的卡片：從放手的位置繼續飛出畫面。
private struct DepartingCard: View {
    let flying: SessionModel.Departing
    let box: CGSize
    let travel: CGFloat
    @State private var x: CGFloat

    init(flying: SessionModel.Departing, box: CGSize, travel: CGFloat) {
        self.flying = flying
        self.box = box
        self.travel = travel
        _x = State(initialValue: flying.startX)
    }

    var body: some View {
        PhotoCard(item: flying.item, box: box, swipe: flying.direction * 200)
            .rotationEffect(.degrees(Double(x / 26)), anchor: .bottom)
            .offset(x: x, y: abs(x) * 0.04)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .onAppear {
                withAnimation(.easeIn(duration: 0.3)) { x = flying.direction * travel }
            }
    }
}
