import SwiftUI

struct GalleryEditorView: View {
    let image: UIImage
    let url: URL
    let onSaved: (UIImage) -> Void
    @Environment(\.dismiss) var dismiss

    @State private var shapes: [DrawnShape] = []
    @State private var selectedTool: DrawingTool = .arrow
    @State private var selectedColor: Color = .red
    @State private var canvasSize: CGSize = .zero

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                GeometryReader { geo in
                    ZStack {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(width: geo.size.width, height: geo.size.height)
                        DrawingCanvas(shapes: $shapes,
                                      selectedTool: selectedTool,
                                      selectedColor: selectedColor)
                            .frame(width: geo.size.width, height: geo.size.height)
                    }
                    .onAppear { canvasSize = geo.size }
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Отмена") { dismiss() }
                        .foregroundColor(.red)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Сохранить") {
                        onSaved(image)
                        dismiss()
                        DispatchQueue.global(qos: .background).async {
                            save()
                        }
                    }
                    .foregroundColor(.orange)
                }
                ToolbarItemGroup(placement: .bottomBar) {
                    toolButton("arrow.up.right", tool: .arrow)
                    toolButton("oval", tool: .oval)
                    Spacer()
                    colorButton(.red)
                    colorButton(.yellow)
                    Spacer()
                    Button {
                        if !shapes.isEmpty { shapes.removeLast() }
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                            .foregroundColor(shapes.isEmpty ? .gray : .white)
                    }
                    .disabled(shapes.isEmpty)
                }
            }
        }
    }

    @ViewBuilder
    private func toolButton(_ icon: String, tool: DrawingTool) -> some View {
        Button { selectedTool = tool } label: {
            Image(systemName: icon)
                .foregroundColor(selectedTool == tool ? .orange : .white)
                .font(.title2)
        }
    }

    @ViewBuilder
    private func colorButton(_ color: Color) -> some View {
        Circle()
            .fill(color)
            .frame(width: 28, height: 28)
            .overlay(selectedColor == color
                     ? Circle().stroke(Color.white, lineWidth: 2) : nil)
            .onTapGesture { selectedColor = color }
    }

    private func save() {
        // Уменьшаем фото до 1920px максимум
        let maxSize: CGFloat = 1920
        let scale = min(maxSize / image.size.width, maxSize / image.size.height, 1.0)
        let imageSize = CGSize(
            width: image.size.width * scale,
            height: image.size.height * scale
        )

        let scaleX = canvasSize.width / imageSize.width
        let scaleY = canvasSize.height / imageSize.height
        let fitScale = min(scaleX, scaleY)
        let displayedSize = CGSize(width: imageSize.width * fitScale,
                                   height: imageSize.height * fitScale)
        let offsetX = (canvasSize.width - displayedSize.width) / 2
        let offsetY = (canvasSize.height - displayedSize.height) / 2
        let toImageX = imageSize.width / displayedSize.width
        let toImageY = imageSize.height / displayedSize.height
        let shapesCopy = shapes
        let savingURL = url

        let renderer = UIGraphicsImageRenderer(size: imageSize)
        let result = renderer.image { ctx in
            image.draw(in: CGRect(origin: .zero, size: imageSize))
            for shape in shapesCopy {
                let start = CGPoint(
                    x: (shape.start.x - offsetX) * toImageX,
                    y: (shape.start.y - offsetY) * toImageY)
                let end = CGPoint(
                    x: (shape.end.x - offsetX) * toImageX,
                    y: (shape.end.y - offsetY) * toImageY)
                let uiColor = UIColor(shape.color)
                let lineWidth: CGFloat = 2.5 * toImageX
                switch shape.tool {
                case .arrow:
                    drawArrow(ctx: ctx.cgContext, from: start, to: end,
                              color: uiColor, lineWidth: lineWidth)
                case .oval:
                    let rect = CGRect(
                        x: min(start.x, end.x), y: min(start.y, end.y),
                        width: abs(end.x - start.x), height: abs(end.y - start.y))
                    ctx.cgContext.setStrokeColor(uiColor.cgColor)
                    ctx.cgContext.setLineWidth(lineWidth)
                    ctx.cgContext.strokeEllipse(in: rect)
                case .text: break
                }
            }
        }

        FileStorageManager.shared.overwrite(image: result, at: savingURL)
    }

    private func drawArrow(ctx: CGContext, from start: CGPoint, to end: CGPoint,
                           color: UIColor, lineWidth: CGFloat) {
        ctx.setStrokeColor(color.cgColor)
        ctx.setLineWidth(lineWidth)
        ctx.move(to: start)
        ctx.addLine(to: end)
        ctx.strokePath()
        let angle = atan2(end.y - start.y, end.x - start.x)
        let headLen: CGFloat = 14 * lineWidth / 2.5
        let headAngle: CGFloat = .pi / 6
        ctx.move(to: end)
        ctx.addLine(to: CGPoint(x: end.x - headLen * cos(angle - headAngle),
                                y: end.y - headLen * sin(angle - headAngle)))
        ctx.move(to: end)
        ctx.addLine(to: CGPoint(x: end.x - headLen * cos(angle + headAngle),
                                y: end.y - headLen * sin(angle + headAngle)))
        ctx.strokePath()
    }
}
