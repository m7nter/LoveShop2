import SwiftUI
import CoreLocation

// MARK: - Хранилище шаблонов
class LabelTemplatesStore: ObservableObject {
    @Published var templates: [String] {
        didSet { UserDefaults.standard.set(templates, forKey: "labelTemplates") }
    }
    @Published var selected: String {
        didSet { UserDefaults.standard.set(selected, forKey: "selectedTemplate") }
    }

    init() {
        templates = UserDefaults.standard.stringArray(forKey: "labelTemplates") ?? []
        selected = UserDefaults.standard.string(forKey: "selectedTemplate") ?? ""
    }
}

// MARK: - PhotoEditorView
struct PhotoEditorView: View {
    /// Сырое фото без впечатанного водяного знака — он накладывается
    /// здесь, при сохранении, чтобы использовать актуальный выбранный
    /// шаблон подписи, а не тот, что был выбран на момент съёмки.
    let image: UIImage
    let location: CLLocation?
    let heading: CLHeading?
    let onSave: (UIImage) -> Void
    let onDiscard: () -> Void

    @StateObject private var store = LabelTemplatesStore()
    @State private var shapes: [DrawnShape] = []
    @State private var selectedTool: DrawingTool = .arrow
    @State private var selectedColor: Color = .red
    @State private var showLabelSheet = false
    @State private var canvasSize: CGSize = .zero
    @State private var isSaving = false

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

                if isSaving {
                    Color.black.opacity(0.4).ignoresSafeArea()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Удалить") { onDiscard() }
                        .foregroundColor(.red)
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Сохранить") { saveComposed() }
                        .foregroundColor(.orange)
                        .disabled(isSaving)
                }
                ToolbarItemGroup(placement: .bottomBar) {
                    toolButton("arrow.up.right", tool: .arrow)
                    toolButton("oval", tool: .oval)
                    Spacer()
                    colorButton(.red)
                    colorButton(.yellow)
                    Spacer()
                    Button {
                        showLabelSheet = true
                    } label: {
                        Image(systemName: store.selected.isEmpty ? "textformat" : "textformat.alt")
                            .foregroundColor(store.selected.isEmpty ? .white : .orange)
                    }
                    Spacer()
                    Button {
                        if !shapes.isEmpty { shapes.removeLast() }
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                            .foregroundColor(shapes.isEmpty ? .gray : .white)
                    }
                    .disabled(shapes.isEmpty || isSaving)
                }
            }
            .sheet(isPresented: $showLabelSheet) {
                LabelTemplateSheet(store: store)
            }
        }
    }

    @ViewBuilder
    private func toolButton(_ icon: String, tool: DrawingTool) -> some View {
        Button {
            selectedTool = tool
        } label: {
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

    private func saveComposed() {
        guard !isSaving else { return }
        isSaving = true

        let rawImage = image
        let loc = location
        let hdg = heading
        let labelText = store.selected.trimmingCharacters(in: .whitespaces).isEmpty
            ? nil : store.selected
        let shapesCopy = shapes
        let canvasSizeCopy = canvasSize

        DispatchQueue.global(qos: .userInitiated).async {
            // Сначала впечатываем актуальный watermark (координаты, азимут,
            // перекрестие, подпись-шаблон — выбранную только что), затем
            // поверх него рисуем аннотации (стрелки/овалы).
            let baseImage = WatermarkRenderer.apply(
                to: rawImage,
                location: loc,
                heading: hdg,
                labelText: labelText
            )

            let imageSize = baseImage.size
            let scaleX = canvasSizeCopy.width / imageSize.width
            let scaleY = canvasSizeCopy.height / imageSize.height
            let scale = min(scaleX, scaleY)
            let displayedSize = CGSize(width: imageSize.width * scale,
                                       height: imageSize.height * scale)
            let offsetX = (canvasSizeCopy.width - displayedSize.width) / 2
            let offsetY = (canvasSizeCopy.height - displayedSize.height) / 2
            let toImageX = imageSize.width / displayedSize.width
            let toImageY = imageSize.height / displayedSize.height

            let renderer = UIGraphicsImageRenderer(size: imageSize)
            let result = renderer.image { ctx in
                baseImage.draw(at: .zero)

                for shape in shapesCopy {
                    let start = CGPoint(
                        x: (shape.start.x - offsetX) * toImageX,
                        y: (shape.start.y - offsetY) * toImageY
                    )
                    let end = CGPoint(
                        x: (shape.end.x - offsetX) * toImageX,
                        y: (shape.end.y - offsetY) * toImageY
                    )
                    let uiColor = UIColor(shape.color)
                    let lineWidth: CGFloat = 2.5 * toImageX

                    switch shape.tool {
                    case .arrow:
                        drawArrowCG(ctx: ctx.cgContext, from: start, to: end,
                                    color: uiColor, lineWidth: lineWidth)
                    case .oval:
                        let rect = CGRect(
                            x: min(start.x, end.x), y: min(start.y, end.y),
                            width: abs(end.x - start.x), height: abs(end.y - start.y)
                        )
                        ctx.cgContext.setStrokeColor(uiColor.cgColor)
                        ctx.cgContext.setLineWidth(lineWidth)
                        ctx.cgContext.strokeEllipse(in: rect)
                    case .text:
                        break
                    }
                }
            }

            DispatchQueue.main.async {
                isSaving = false
                onSave(result)
            }
        }
    }

    private func drawArrowCG(ctx: CGContext, from start: CGPoint, to end: CGPoint,
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

// MARK: - Шаблоны подписей
struct LabelTemplateSheet: View {
    @ObservedObject var store: LabelTemplatesStore
    @Environment(\.dismiss) var dismiss
    @State private var newTemplate: String = ""
    @State private var showInput = false

    var body: some View {
        NavigationView {
            List {
                if !store.selected.isEmpty {
                    Section("Активный") {
                        HStack {
                            Text(store.selected)
                            Spacer()
                            Image(systemName: "checkmark")
                                .foregroundColor(.orange)
                        }
                        Button("Отключить подпись") {
                            store.selected = ""
                            dismiss()
                        }
                        .foregroundColor(.red)
                    }
                }

                Section("Шаблоны") {
                    ForEach(store.templates, id: \.self) { template in
                        Button {
                            store.selected = template
                            dismiss()
                        } label: {
                            HStack {
                                Text(template)
                                    .foregroundColor(.primary)
                                Spacer()
                                if store.selected == template {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.orange)
                                }
                            }
                        }
                    }
                    .onDelete { idx in
                        store.templates.remove(atOffsets: idx)
                        if !store.templates.contains(store.selected) {
                            store.selected = ""
                        }
                    }
                }

                Section {
                    if showInput {
                        HStack {
                            TextField("Введите подпись...", text: $newTemplate)
                            Button("Добавить") {
                                let t = newTemplate.trimmingCharacters(in: .whitespaces)
                                if !t.isEmpty {
                                    store.templates.append(t)
                                    store.selected = t
                                    newTemplate = ""
                                    showInput = false
                                    dismiss()
                                }
                            }
                            .foregroundColor(.orange)
                        }
                    } else {
                        Button {
                            showInput = true
                        } label: {
                            Label("Добавить шаблон", systemImage: "plus")
                        }
                    }
                }
            }
            .navigationTitle("Подписи")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") { dismiss() }
                }
            }
        }
    }
}
