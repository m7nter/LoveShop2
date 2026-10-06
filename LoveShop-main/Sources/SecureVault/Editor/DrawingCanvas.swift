// DrawingCanvas.swift
import SwiftUI

enum DrawingTool { case arrow, oval, text }

struct DrawnShape: Identifiable {
    let id = UUID()
    var tool: DrawingTool
    var start: CGPoint
    var end: CGPoint
    var color: Color
    var text: String = ""
}

struct DrawingCanvas: View {
    @Binding var shapes: [DrawnShape]
    var selectedTool: DrawingTool
    var selectedColor: Color

    @State private var dragStart: CGPoint = .zero
    @State private var dragCurrent: CGPoint = .zero
    @State private var isDragging = false

    var body: some View {
        Canvas { ctx, size in
            for shape in shapes {
                draw(shape: shape, in: &ctx)
            }
            if isDragging {
                let preview = DrawnShape(tool: selectedTool,
                                        start: dragStart,
                                        end: dragCurrent,
                                        color: selectedColor)
                draw(shape: preview, in: &ctx)
            }
        }
        .gesture(
            DragGesture(minimumDistance: 2)
                .onChanged { v in
                    dragStart = v.startLocation
                    dragCurrent = v.location
                    isDragging = true
                }
                .onEnded { v in
                    shapes.append(DrawnShape(tool: selectedTool,
                                             start: v.startLocation,
                                             end: v.location,
                                             color: selectedColor))
                    isDragging = false
                }
        )
    }

    private func draw(shape: DrawnShape, in ctx: inout GraphicsContext) {
        let stroke = ctx
        stroke.stroke(arrowPath(from: shape.start, to: shape.end),
                      with: .color(shape.color),
                      lineWidth: 0) // overridden below

        switch shape.tool {
        case .arrow:
            drawArrow(from: shape.start, to: shape.end, color: shape.color, in: &ctx)
        case .oval:
            let rect = CGRect(x: min(shape.start.x, shape.end.x),
                              y: min(shape.start.y, shape.end.y),
                              width: abs(shape.end.x - shape.start.x),
                              height: abs(shape.end.y - shape.start.y))
            ctx.stroke(Path(ellipseIn: rect), with: .color(shape.color), lineWidth: 2.5)
        case .text:
            break
        }
    }

    private func drawArrow(from start: CGPoint, to end: CGPoint,
                            color: Color, in ctx: inout GraphicsContext) {
        var path = Path()
        path.move(to: start)
        path.addLine(to: end)
        ctx.stroke(path, with: .color(color), lineWidth: 2.5)

        // Arrowhead
        let angle = atan2(end.y - start.y, end.x - start.x)
        let headLen: CGFloat = 14
        let headAngle: CGFloat = .pi / 6
        var head = Path()
        head.move(to: end)
        head.addLine(to: CGPoint(x: end.x - headLen * cos(angle - headAngle),
                                 y: end.y - headLen * sin(angle - headAngle)))
        head.move(to: end)
        head.addLine(to: CGPoint(x: end.x - headLen * cos(angle + headAngle),
                                 y: end.y - headLen * sin(angle + headAngle)))
        ctx.stroke(head, with: .color(color), lineWidth: 2.5)
    }

    private func arrowPath(from: CGPoint, to: CGPoint) -> Path {
        var p = Path(); p.move(to: from); p.addLine(to: to); return p
    }
}
