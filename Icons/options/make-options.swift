import AppKit
import CoreGraphics

// 產生「相片挑選」的 App 圖示候選（1024×1024，不含圓角，由系統套用遮罩）。
// 用法：swift make-options.swift <輸出資料夾>

let S: CGFloat = 1024
let cs = CGColorSpace(name: CGColorSpace.sRGB)!
func rgb(_ h: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: cs, components: [CGFloat((h >> 16) & 255) / 255, CGFloat((h >> 8) & 255) / 255,
                                         CGFloat(h & 255) / 255, a])!
}
func newCtx() -> CGContext {
    let c = CGContext(data: nil, width: 1024, height: 1024, bitsPerComponent: 8, bytesPerRow: 0, space: cs,
                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    c.translateBy(x: 0, y: S); c.scaleBy(x: 1, y: -1)   // 原點在左上
    return c
}
func save(_ c: CGContext, _ path: String) {
    let rep = NSBitmapImageRep(cgImage: c.makeImage()!)
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
}
func bg(_ c: CGContext, _ col: UInt32) { c.setFillColor(rgb(col)); c.fill(CGRect(x: 0, y: 0, width: S, height: S)) }

/// 以中心點與角度畫圓角矩形，body 內的座標以卡片左上角為原點。
func card(_ c: CGContext, center: CGPoint, size: CGSize, radius: CGFloat, angle: CGFloat,
          fill: CGColor, body: ((CGContext, CGRect) -> Void)? = nil) {
    c.saveGState()
    c.translateBy(x: center.x, y: center.y)
    c.rotate(by: angle * .pi / 180)
    let r = CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height)
    let p = CGPath(roundedRect: r, cornerWidth: radius, cornerHeight: radius, transform: nil)
    c.addPath(p); c.setFillColor(fill); c.fillPath()
    if let body {
        c.addPath(p); c.clip()
        body(c, r)
    }
    c.restoreGState()
}
func circle(_ c: CGContext, _ p: CGPoint, _ r: CGFloat, _ col: CGColor) {
    c.setFillColor(col); c.fillEllipse(in: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2))
}
func check(_ c: CGContext, _ p: CGPoint, _ size: CGFloat, _ w: CGFloat, _ col: CGColor) {
    c.setLineCap(.round); c.setLineJoin(.round); c.setLineWidth(w); c.setStrokeColor(col)
    c.move(to: CGPoint(x: p.x - size * 0.42, y: p.y + size * 0.02))
    c.addLine(to: CGPoint(x: p.x - size * 0.12, y: p.y + size * 0.32))
    c.addLine(to: CGPoint(x: p.x + size * 0.45, y: p.y - size * 0.30))
    c.strokePath()
}
func cross(_ c: CGContext, _ p: CGPoint, _ size: CGFloat, _ w: CGFloat, _ col: CGColor) {
    c.setLineCap(.round); c.setLineWidth(w); c.setStrokeColor(col)
    let d = size * 0.34
    c.move(to: CGPoint(x: p.x - d, y: p.y - d)); c.addLine(to: CGPoint(x: p.x + d, y: p.y + d))
    c.move(to: CGPoint(x: p.x + d, y: p.y - d)); c.addLine(to: CGPoint(x: p.x - d, y: p.y + d))
    c.strokePath()
}
/// 卡片裡的簡單風景：山與太陽（扁平色塊）。
func landscape(_ c: CGContext, _ r: CGRect, sky: UInt32, sun: UInt32, far: UInt32, near: UInt32) {
    c.setFillColor(rgb(sky)); c.fill(r)
    circle(c, CGPoint(x: r.maxX - r.width * 0.26, y: r.minY + r.height * 0.30), r.width * 0.09, rgb(sun))
    func ridge(_ pts: [CGFloat], _ base: CGFloat, _ col: UInt32) {
        c.move(to: CGPoint(x: r.minX, y: r.maxY))
        for (i, h) in pts.enumerated() {
            c.addLine(to: CGPoint(x: r.minX + r.width * CGFloat(i) / CGFloat(pts.count - 1), y: r.minY + r.height * (base - h)))
        }
        c.addLine(to: CGPoint(x: r.maxX, y: r.maxY)); c.closePath()
        c.setFillColor(rgb(col)); c.fillPath()
    }
    ridge([0.0, 0.22, 0.08, 0.30, 0.12], 0.78, far)
    ridge([0.0, 0.10, 0.18, 0.06, 0.14], 0.95, near)
}

let out = CommandLine.arguments[1]
let green: UInt32 = 0x248A3D, brightGreen: UInt32 = 0x34C759

// 1. 綠勾相片：綠底，一張白框相片，右下角疊一個綠色勾勾圓章。
do {
    let c = newCtx(); bg(c, brightGreen)
    card(c, center: CGPoint(x: 492, y: 492), size: CGSize(width: 560, height: 440), radius: 70, angle: -6,
         fill: rgb(0xFFFFFF)) { c, r in
        landscape(c, r.insetBy(dx: 36, dy: 36), sky: 0xE9F9EE, sun: brightGreen, far: 0xA8E4B9, near: green)
    }
    circle(c, CGPoint(x: 712, y: 704), 150, rgb(0xFFFFFF))
    circle(c, CGPoint(x: 712, y: 704), 122, rgb(green))
    check(c, CGPoint(x: 712, y: 704), 150, 34, rgb(0xFFFFFF))
    save(c, out + "/1.png")
}

// 2. 滑動中的一疊卡：白底，後面兩張半透明卡，最前面一張往右傾、帶綠勾。
do {
    let c = newCtx(); bg(c, 0xFFFFFF)
    card(c, center: CGPoint(x: 462, y: 548), size: CGSize(width: 600, height: 460), radius: 74, angle: -10, fill: rgb(0x1C1C1E, 0.10))
    card(c, center: CGPoint(x: 496, y: 526), size: CGSize(width: 600, height: 460), radius: 74, angle: -3, fill: rgb(0x1C1C1E, 0.18))
    card(c, center: CGPoint(x: 552, y: 486), size: CGSize(width: 600, height: 460), radius: 74, angle: 9, fill: rgb(green)) { c, r in
        check(c, CGPoint(x: r.midX, y: r.midY), 260, 52, rgb(0xFFFFFF))
    }
    save(c, out + "/2.png")
}

// 3. 記憶卡：深藍底，白色記憶卡，右下角綠色勾勾。
do {
    let c = newCtx(); bg(c, 0x1C2A4A)
    c.saveGState()
    let body = CGMutablePath()
    let x0: CGFloat = 322, y0: CGFloat = 214, w: CGFloat = 380, h: CGFloat = 520, cut: CGFloat = 110, rr: CGFloat = 46
    body.move(to: CGPoint(x: x0 + rr, y: y0))
    body.addLine(to: CGPoint(x: x0 + w - cut, y: y0))
    body.addLine(to: CGPoint(x: x0 + w, y: y0 + cut))
    body.addArc(tangent1End: CGPoint(x: x0 + w, y: y0 + h), tangent2End: CGPoint(x: x0, y: y0 + h), radius: rr)
    body.addArc(tangent1End: CGPoint(x: x0, y: y0 + h), tangent2End: CGPoint(x: x0, y: y0), radius: rr)
    body.addArc(tangent1End: CGPoint(x: x0, y: y0), tangent2End: CGPoint(x: x0 + w, y: y0), radius: rr)
    body.closeSubpath()
    c.addPath(body); c.setFillColor(rgb(0xFFFFFF)); c.fillPath()
    // 金屬接點
    for i in 0..<4 {
        let r = CGRect(x: x0 + 64 + CGFloat(i) * 52, y: y0 + 52, width: 30, height: 96)
        c.addPath(CGPath(roundedRect: r, cornerWidth: 12, cornerHeight: 12, transform: nil))
        c.setFillColor(rgb(0x1C2A4A, 0.85)); c.fillPath()
    }
    c.restoreGState()
    circle(c, CGPoint(x: 690, y: 716), 140, rgb(0x1C2A4A))
    circle(c, CGPoint(x: 690, y: 716), 116, rgb(brightGreen))
    check(c, CGPoint(x: 690, y: 716), 140, 32, rgb(0xFFFFFF))
    save(c, out + "/3.png")
}

// 4. 叉與勾：黑底，灰色叉叉圓與綠色勾勾圓重疊（就是 App 裡滑動時的兩個圖示）。
do {
    let c = newCtx(); bg(c, 0x000000)
    circle(c, CGPoint(x: 390, y: 512), 230, rgb(0x8E8E93, 0.55))
    cross(c, CGPoint(x: 340, y: 512), 200, 40, rgb(0xFFFFFF, 0.85))
    circle(c, CGPoint(x: 634, y: 512), 230, rgb(brightGreen))
    check(c, CGPoint(x: 650, y: 512), 220, 44, rgb(0xFFFFFF))
    save(c, out + "/4.png")
}

// 5. 藍天相片疊：藍底，三張不同色相片扇形疊放，最上面那張有黃色太陽。
do {
    let c = newCtx(); bg(c, 0x0A84FF)
    card(c, center: CGPoint(x: 430, y: 560), size: CGSize(width: 440, height: 340), radius: 56, angle: -14, fill: rgb(0xFFFFFF, 0.35))
    card(c, center: CGPoint(x: 512, y: 520), size: CGSize(width: 440, height: 340), radius: 56, angle: -4, fill: rgb(0xFFFFFF, 0.6))
    card(c, center: CGPoint(x: 590, y: 480), size: CGSize(width: 440, height: 340), radius: 56, angle: 8, fill: rgb(0xFFFFFF)) { c, r in
        landscape(c, r.insetBy(dx: 28, dy: 28), sky: 0xDCEBFF, sun: 0xFFCC00, far: 0x7DB7FF, near: 0x0A60D0)
    }
    save(c, out + "/5.png")
}

// 6. 篩選：橘底，三張相片往下落，只有一張白色相片進到底下的托盤（挑出好照片）。
do {
    let c = newCtx(); bg(c, 0xFF9F0A)
    card(c, center: CGPoint(x: 330, y: 300), size: CGSize(width: 230, height: 180), radius: 36, angle: -16, fill: rgb(0xFFFFFF, 0.4))
    card(c, center: CGPoint(x: 700, y: 290), size: CGSize(width: 230, height: 180), radius: 36, angle: 14, fill: rgb(0xFFFFFF, 0.4))
    card(c, center: CGPoint(x: 512, y: 470), size: CGSize(width: 330, height: 250), radius: 46, angle: 0, fill: rgb(0xFFFFFF)) { c, r in
        landscape(c, r.insetBy(dx: 22, dy: 22), sky: 0xFFF2DC, sun: 0xFF9F0A, far: 0xFFC56B, near: 0xC2410C)
    }
    // 托盤
    let tray = CGMutablePath()
    tray.move(to: CGPoint(x: 250, y: 640))
    tray.addLine(to: CGPoint(x: 250, y: 740))
    tray.addArc(tangent1End: CGPoint(x: 250, y: 810), tangent2End: CGPoint(x: 320, y: 810), radius: 70)
    tray.addLine(to: CGPoint(x: 704, y: 810))
    tray.addArc(tangent1End: CGPoint(x: 774, y: 810), tangent2End: CGPoint(x: 774, y: 740), radius: 70)
    tray.addLine(to: CGPoint(x: 774, y: 640))
    c.addPath(tray); c.setLineWidth(52); c.setLineCap(.round); c.setLineJoin(.round)
    c.setStrokeColor(rgb(0xFFFFFF)); c.strokePath()
    save(c, out + "/6.png")
}

// 對照表：套上 iOS 圓角，淺色、深色背景各一列，加上編號（全程用 CoreGraphics，顏色不失真）。
do {
    let labels = ["目前"] + (1...6).map { "\($0)" }
    var files = (1...6).map { "\(out)/\($0).png" }
    files.insert(out + "/../../CardPick/Assets.xcassets/AppIcon.appiconset/icon.png", at: 0)
    let tile: CGFloat = 240, gap: CGFloat = 64, pad: CGFloat = 64, labelH: CGFloat = 64
    let band = pad + tile + labelH
    let W = pad * 2 + CGFloat(files.count) * tile + CGFloat(files.count - 1) * gap
    let H = band * 2
    let c = CGContext(data: nil, width: Int(W), height: Int(H), bitsPerComponent: 8, bytesPerRow: 0, space: cs,
                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    // CoreGraphics 原點在左下：上半是淺色列，下半是深色列。
    for (row, bgc) in [(0, rgb(0xFFFFFF)), (1, rgb(0x000000))] {
        c.setFillColor(bgc)
        c.fill(CGRect(x: 0, y: H - band * CGFloat(row + 1), width: W, height: band))
    }
    for row in 0..<2 {
        let bandBottom = H - band * CGFloat(row + 1)
        let textColor = row == 0 ? NSColor.black : NSColor.white
        for (i, f) in files.enumerated() {
            guard let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: f) as CFURL, nil),
                  let image = CGImageSourceCreateImageAtIndex(src, 0, nil) else { continue }
            let x = pad + CGFloat(i) * (tile + gap)
            let rect = CGRect(x: x, y: bandBottom + labelH, width: tile, height: tile)
            c.saveGState()
            c.addPath(CGPath(roundedRect: rect, cornerWidth: tile * 0.2237, cornerHeight: tile * 0.2237, transform: nil))
            c.clip(); c.draw(image, in: rect)
            c.restoreGState()
            let attr = NSAttributedString(string: labels[i], attributes: [
                .font: NSFont.systemFont(ofSize: 30, weight: .semibold), .foregroundColor: textColor])
            let line = CTLineCreateWithAttributedString(attr)
            let w = CTLineGetTypographicBounds(line, nil, nil, nil)
            c.textPosition = CGPoint(x: x + tile / 2 - CGFloat(w) / 2, y: bandBottom + 18)
            CTLineDraw(line, c)
        }
    }
    let rep = NSBitmapImageRep(cgImage: c.makeImage()!)
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out + "/sheet.png"))
}
