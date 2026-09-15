import AppKit

/* 앱 아이콘 생성: 파란 배경 위에 체크리스트 카드 (1024×1024 PNG) */
let size: CGFloat = 1024
let img = NSImage(size: NSSize(width: size, height: size))
img.lockFocus()

let ctx = NSGraphicsContext.current!.cgContext

// macOS 스타일 라운드 사각형 배경 (파란 그라데이션)
let inset: CGFloat = 100
let rect = CGRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
let bgPath = CGPath(roundedRect: rect, cornerWidth: 185, cornerHeight: 185, transform: nil)
ctx.saveGState()
ctx.addPath(bgPath)
ctx.clip()
let gradColors = [
    CGColor(red: 0.19, green: 0.51, blue: 0.96, alpha: 1),
    CGColor(red: 0.30, green: 0.61, blue: 1.00, alpha: 1)
] as CFArray
let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: gradColors, locations: [0, 1])!
ctx.drawLinearGradient(grad,
                       start: CGPoint(x: inset, y: size - inset),
                       end: CGPoint(x: size - inset, y: inset), options: [])
ctx.restoreGState()

// 흰색 카드
let card = CGRect(x: 232, y: 212, width: 560, height: 600)
ctx.addPath(CGPath(roundedRect: card, cornerWidth: 64, cornerHeight: 64, transform: nil))
ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
ctx.fillPath()

// 체크 항목 3줄 (위 두 줄 완료, 마지막 줄 미완료)
let white = CGColor(red: 1, green: 1, blue: 1, alpha: 1)
let green = CGColor(red: 0.08, green: 0.72, blue: 0.53, alpha: 1)
let lightGray = CGColor(red: 0.80, green: 0.82, blue: 0.85, alpha: 1)
let doneText = CGColor(red: 0.55, green: 0.58, blue: 0.63, alpha: 1)
let todoText = CGColor(red: 0.20, green: 0.22, blue: 0.25, alpha: 1)
let rows: [CGFloat] = [690, 540, 390]
for (i, y) in rows.enumerated() {
    let done = i < 2
    let circle = CGRect(x: 292, y: y - 34, width: 68, height: 68)
    if done {
        ctx.setFillColor(green)
        ctx.addEllipse(in: circle)
        ctx.fillPath()
        ctx.setStrokeColor(white)
        ctx.setLineWidth(11)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        ctx.move(to: CGPoint(x: 310, y: y))
        ctx.addLine(to: CGPoint(x: 322, y: y - 13))
        ctx.addLine(to: CGPoint(x: 345, y: y + 15))
        ctx.strokePath()
    } else {
        ctx.setStrokeColor(lightGray)
        ctx.setLineWidth(8)
        ctx.strokeEllipse(in: circle.insetBy(dx: 4, dy: 4))
    }
    ctx.setFillColor(done ? doneText : todoText)
    let line = CGRect(x: 392, y: y - 16, width: done ? 300 : 340, height: 32)
    ctx.addPath(CGPath(roundedRect: line, cornerWidth: 16, cornerHeight: 16, transform: nil))
    ctx.fillPath()
}

img.unlockFocus()

let tiff = img.tiffRepresentation!
let rep = NSBitmapImageRep(data: tiff)!
let png = rep.representation(using: .png, properties: [:])!
try! png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
print("icon written")
