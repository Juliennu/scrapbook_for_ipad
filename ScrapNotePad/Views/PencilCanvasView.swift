import PencilKit
import SwiftUI

struct PencilCanvasView: UIViewRepresentable {
    @Binding var drawingData: Data
    var backgroundImageData: Data?
    @Binding var canvasViewRef: PKCanvasView?
    var allowsFingerDrawing: Bool
    private let pageSize = CGSize(width: 1600, height: 2200)

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
        scrollView.contentInsetAdjustmentBehavior = .never

        let containerView = UIView(frame: CGRect(origin: .zero, size: pageSize))
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
            updateLayout(for: scrollView, coordinator: context.coordinator)
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
            updateLayout(for: uiView, coordinator: context.coordinator)
        }
    }

    private func updateLayout(for scrollView: UIScrollView, coordinator: Coordinator) {
        guard let containerView = coordinator.containerView else { return }

        let boundsSize = scrollView.bounds.size
        guard boundsSize.width > 0, boundsSize.height > 0 else { return }

        if coordinator.lastBoundsSize != boundsSize, !scrollView.isZooming {
            let fitScale = min(boundsSize.width / containerView.bounds.width,
                               boundsSize.height / containerView.bounds.height)
            scrollView.minimumZoomScale = fitScale
            scrollView.maximumZoomScale = 4.0

            UIView.performWithoutAnimation {
                scrollView.setZoomScale(fitScale, animated: false)
                scrollView.layoutIfNeeded()
            }

            coordinator.lastBoundsSize = boundsSize
        }

        let contentSize = CGSize(width: containerView.bounds.width * scrollView.zoomScale,
                                 height: containerView.bounds.height * scrollView.zoomScale)
        let insetX = max(0, (boundsSize.width - contentSize.width) * 0.5)
        let insetY = max(0, (boundsSize.height - contentSize.height) * 0.5)
        scrollView.contentInset = UIEdgeInsets(top: insetY, left: insetX, bottom: insetY, right: insetX)
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate, UIScrollViewDelegate {
        private let parent: PencilCanvasView
        let toolPicker = PKToolPicker()
        weak var canvasView: PKCanvasView?
        weak var imageView: UIImageView?
        weak var containerView: UIView?
        var lastBoundsSize: CGSize = .zero

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
