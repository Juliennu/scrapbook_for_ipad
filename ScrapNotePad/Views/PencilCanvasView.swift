import PencilKit
import SwiftUI

struct PencilCanvasView: UIViewRepresentable {
    @Binding var drawingData: Data
    var backgroundImageData: Data?
    @Binding var canvasViewRef: PKCanvasView?
    var allowsFingerDrawing: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.minimumZoomScale = 0.6
        scrollView.maximumZoomScale = 4.0
        scrollView.zoomScale = 1.0
        scrollView.bouncesZoom = true
        scrollView.alwaysBounceVertical = true
        scrollView.alwaysBounceHorizontal = true
        scrollView.delegate = context.coordinator

        let containerView = UIView(frame: CGRect(x: 0, y: 0, width: 1600, height: 2200))
        containerView.backgroundColor = UIColor.systemBackground

        let imageView = UIImageView(frame: containerView.bounds)
        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = .clear
        imageView.clipsToBounds = true
        context.coordinator.imageView = imageView

        let canvasView = PKCanvasView(frame: containerView.bounds)
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        canvasView.delegate = context.coordinator
        canvasView.drawingPolicy = allowsFingerDrawing ? .anyInput : .pencilOnly
        canvasView.alwaysBounceVertical = false
        canvasView.alwaysBounceHorizontal = false

        containerView.addSubview(imageView)
        containerView.addSubview(canvasView)
        scrollView.addSubview(containerView)
        scrollView.contentSize = containerView.bounds.size
        scrollView.panGestureRecognizer.minimumNumberOfTouches = 2

        context.coordinator.containerView = containerView
        context.coordinator.canvasView = canvasView

        if let drawing = try? PKDrawing(data: drawingData) {
            canvasView.drawing = drawing
        }
        if let backgroundImageData,
           let image = UIImage(data: backgroundImageData) {
            imageView.image = image
        }

        DispatchQueue.main.async {
            canvasView.becomeFirstResponder()
            context.coordinator.toolPicker.setVisible(true, forFirstResponder: canvasView)
            context.coordinator.toolPicker.addObserver(canvasView)
            canvasViewRef = canvasView
        }

        return scrollView
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {
        guard let canvasView = context.coordinator.canvasView,
              let imageView = context.coordinator.imageView else { return }

        canvasView.drawingPolicy = allowsFingerDrawing ? .anyInput : .pencilOnly

        if let drawing = try? PKDrawing(data: drawingData),
           canvasView.drawing.dataRepresentation() != drawingData {
            canvasView.drawing = drawing
        }

        if let backgroundImageData,
           let image = UIImage(data: backgroundImageData) {
            imageView.image = image
        } else {
            imageView.image = nil
        }

        DispatchQueue.main.async {
            canvasViewRef = canvasView
        }
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate, UIScrollViewDelegate {
        private let parent: PencilCanvasView
        let toolPicker = PKToolPicker()
        weak var canvasView: PKCanvasView?
        weak var imageView: UIImageView?
        weak var containerView: UIView?

        init(_ parent: PencilCanvasView) {
            self.parent = parent
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            parent.drawingData = canvasView.drawing.dataRepresentation()
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            containerView
        }
    }
}
