import SwiftUI
import UIKit

struct ImageCropView: View {
    enum CropMode: String, CaseIterable, Identifiable {
        case rectangle
        case square
        case ellipse
        case circle
        case freeform

        var id: String { rawValue }

        var title: String {
            switch self {
            case .rectangle:
                return "矩形"
            case .square:
                return "正方形"
            case .ellipse:
                return "楕円"
            case .circle:
                return "円"
            case .freeform:
                return "フリーハンド"
            }
        }
    }

    let image: UIImage
    let onCancel: () -> Void
    let onApply: (UIImage) -> Void

    @State private var cropMode: CropMode = .rectangle
    @State private var cropRect: CGRect = .zero
    @State private var dragStartRect: CGRect = .zero
    @State private var magnificationStartRect: CGRect = .zero
    @State private var freeformPoints: [CGPoint] = []
    @State private var displayRect: CGRect = .zero

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                let rect = aspectFitRect(for: image.size, in: proxy.size)

                ZStack {
                    Color.black.opacity(0.92).ignoresSafeArea()

                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)

                    if cropMode == .freeform {
                        FreeformOverlayView(points: $freeformPoints, size: rect.size)
                            .frame(width: rect.width, height: rect.height)
                            .position(x: rect.midX, y: rect.midY)
                    } else {
                        cropOverlay(in: rect)
                    }
                }
                .onAppear {
                    displayRect = rect
                    if cropRect == .zero {
                        cropRect = defaultCropRect(in: rect)
                    }
                }
                .onChange(of: rect) { _, newRect in
                    displayRect = newRect
                }
                .onChange(of: cropMode) { _, _ in
                    freeformPoints = []
                    cropRect = defaultCropRect(in: rect)
                }
            }
            .navigationTitle("トリミング")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        onCancel()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("適用") {
                        if let cropped = renderCroppedImage() {
                            onApply(cropped)
                        }
                    }
                }
                ToolbarItem(placement: .bottomBar) {
                    Picker("Crop Mode", selection: $cropMode) {
                        ForEach(CropMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
        }
    }

    private func cropOverlay(in displayRect: CGRect) -> some View {
        let maskPath = cropMaskPath(in: displayRect)

        return ZStack {
            Path { path in
                path.addRect(displayRect)
                path.addPath(maskPath)
            }
            .fill(Color.black.opacity(0.55), style: FillStyle(eoFill: true))

            maskPath
                .stroke(Color.white, lineWidth: 2)
        }
        .gesture(dragGesture(in: displayRect))
        .gesture(magnificationGesture(in: displayRect))
    }

    private func dragGesture(in displayRect: CGRect) -> some Gesture {
        DragGesture()
            .onChanged { value in
                if dragStartRect == .zero {
                    dragStartRect = cropRect
                }
                let proposed = cropRectOffset(from: dragStartRect, translation: value.translation, in: displayRect)
                cropRect = proposed
            }
            .onEnded { _ in
                dragStartRect = .zero
            }
    }

    private func magnificationGesture(in displayRect: CGRect) -> some Gesture {
        MagnificationGesture()
            .onChanged { value in
                if magnificationStartRect == .zero {
                    magnificationStartRect = cropRect
                }
                let scaled = cropRectScaled(from: magnificationStartRect, scale: value, in: displayRect)
                cropRect = scaled
            }
            .onEnded { _ in
                magnificationStartRect = .zero
            }
    }

    private func cropMaskPath(in displayRect: CGRect) -> Path {
        let rect = cropRect.isEmpty ? defaultCropRect(in: displayRect) : cropRect
        switch cropMode {
        case .rectangle, .square:
            return Path(rect)
        case .ellipse, .circle:
            return Path(ellipseIn: rect)
        case .freeform:
            return Path(rect)
        }
    }

    private func cropRectOffset(from start: CGRect, translation: CGSize, in displayRect: CGRect) -> CGRect {
        var rect = start
        rect.origin.x += translation.width
        rect.origin.y += translation.height
        rect.origin.x = max(displayRect.minX, min(rect.origin.x, displayRect.maxX - rect.width))
        rect.origin.y = max(displayRect.minY, min(rect.origin.y, displayRect.maxY - rect.height))
        return rect
    }

    private func cropRectScaled(from start: CGRect, scale: CGFloat, in displayRect: CGRect) -> CGRect {
        let minSize: CGFloat = 60
        var target = start
        var newWidth = max(minSize, start.width * scale)
        var newHeight = max(minSize, start.height * scale)

        if cropMode == .square || cropMode == .circle {
            let side = max(minSize, min(newWidth, newHeight))
            newWidth = side
            newHeight = side
        }

        target.size = CGSize(width: newWidth, height: newHeight)
        target.origin.x = max(displayRect.minX, min(target.midX - newWidth * 0.5, displayRect.maxX - newWidth))
        target.origin.y = max(displayRect.minY, min(target.midY - newHeight * 0.5, displayRect.maxY - newHeight))
        return target
    }

    private func defaultCropRect(in displayRect: CGRect) -> CGRect {
        let insetX = displayRect.width * 0.15
        let insetY = displayRect.height * 0.15
        var rect = displayRect.insetBy(dx: insetX, dy: insetY)
        if cropMode == .square || cropMode == .circle {
            let side = min(rect.width, rect.height)
            rect.size = CGSize(width: side, height: side)
            rect.origin.x = displayRect.midX - side * 0.5
            rect.origin.y = displayRect.midY - side * 0.5
        }
        return rect
    }

    private func aspectFitRect(for imageSize: CGSize, in containerSize: CGSize) -> CGRect {
        let scale = min(containerSize.width / max(imageSize.width, 1),
                        containerSize.height / max(imageSize.height, 1))
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let origin = CGPoint(x: (containerSize.width - size.width) * 0.5,
                             y: (containerSize.height - size.height) * 0.5)
        return CGRect(origin: origin, size: size)
    }

    private func renderCroppedImage() -> UIImage? {
        let rect = displayRect == .zero ? aspectFitRect(for: image.size, in: UIScreen.main.bounds.size) : displayRect
        switch cropMode {
        case .freeform:
            return applyFreeformCrop(displayRect: rect)
        case .rectangle, .square, .ellipse, .circle:
            return applyShapeCrop(displayRect: rect)
        }
    }

    private func applyShapeCrop(displayRect: CGRect) -> UIImage? {
        let rect = cropRect.isEmpty ? defaultCropRect(in: displayRect) : cropRect
        let scaleX = image.size.width / displayRect.width
        let scaleY = image.size.height / displayRect.height
        let imageRect = CGRect(
            x: (rect.minX - displayRect.minX) * scaleX,
            y: (rect.minY - displayRect.minY) * scaleY,
            width: rect.width * scaleX,
            height: rect.height * scaleY
        )

        guard let cgImage = image.cgImage,
              let croppedCG = cgImage.cropping(to: imageRect) else { return nil }

        let croppedImage = UIImage(cgImage: croppedCG, scale: image.scale, orientation: image.imageOrientation)

        if cropMode == .rectangle || cropMode == .square {
            return croppedImage
        }

        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        let renderer = UIGraphicsImageRenderer(size: croppedImage.size, format: format)
        return renderer.image { context in
            let rect = CGRect(origin: .zero, size: croppedImage.size)
            context.cgContext.addEllipse(in: rect)
            context.cgContext.clip()
            croppedImage.draw(in: rect)
        }
    }

    private func applyFreeformCrop(displayRect: CGRect) -> UIImage? {
        guard freeformPoints.count >= 3 else { return image }

        let scaleX = image.size.width / displayRect.width
        let scaleY = image.size.height / displayRect.height
        let mappedPoints = freeformPoints.map { point in
            CGPoint(x: point.x * scaleX, y: point.y * scaleY)
        }

        let path = CGMutablePath()
        if let first = mappedPoints.first {
            path.move(to: first)
            for point in mappedPoints.dropFirst() {
                path.addLine(to: point)
            }
            path.closeSubpath()
        }

        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        return renderer.image { context in
            context.cgContext.addPath(path)
            context.cgContext.clip()
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }

}

struct FreeformOverlayView: View {
    @Binding var points: [CGPoint]
    let size: CGSize

    @State private var isDrawing = false

    var body: some View {
        ZStack {
            Color.clear

            if points.count >= 3 {
                Path { path in
                    path.addLines(points)
                    path.closeSubpath()
                }
                .fill(Color.white.opacity(0.2))
            }

            if points.count >= 2 {
                Path { path in
                    path.addLines(points)
                }
                .stroke(Color.blue, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round, dash: [6, 4]))
            } else if let first = points.first {
                Path(ellipseIn: CGRect(x: first.x - 3, y: first.y - 3, width: 6, height: 6))
                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round, dash: [6, 4]))
            }
        }
        .contentShape(Rectangle())
        .allowsHitTesting(true)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if !isDrawing {
                        if !points.isEmpty {
                            points = []
                        }
                        isDrawing = true
                    }
                    let clamped = clamp(point: value.location, in: size)
                    if let last = points.last {
                        let dx = clamped.x - last.x
                        let dy = clamped.y - last.y
                        if sqrt(dx * dx + dy * dy) < 2 {
                            return
                        }
                    }
                    points.append(clamped)
                }
                .onEnded { _ in
                    isDrawing = false
                }
        )
    }

    private func clamp(point: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(
            x: min(max(0, point.x), size.width),
            y: min(max(0, point.y), size.height)
        )
    }
}

