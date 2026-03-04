import PencilKit
import SwiftUI

struct PencilCanvasView: UIViewRepresentable {
    @Binding var drawingData: Data
    var backgroundImageData: Data?
    @Binding var imageItems: [ScrapImageItem]
    @Binding var activeCropImageID: UUID?
    @Binding var clearSelectionToken: Int
    @Binding var canvasViewRef: PKCanvasView?
    var allowsFingerDrawing: Bool = true
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

        let tapRecognizer = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleBackgroundTap(_:)))
        tapRecognizer.cancelsTouchesInView = false
        containerView.addGestureRecognizer(tapRecognizer)

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
            context.coordinator.syncImageViews(items: imageItems)
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

        context.coordinator.syncImageViews(items: imageItems)
        context.coordinator.applyClearSelectionIfNeeded(token: clearSelectionToken)

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

    final class Coordinator: NSObject, PKCanvasViewDelegate, UIScrollViewDelegate, UIEditMenuInteractionDelegate {
        private let parent: PencilCanvasView
        let toolPicker = PKToolPicker()
        weak var canvasView: PKCanvasView?
        weak var imageView: UIImageView?
        weak var containerView: UIView?
        var lastBoundsSize: CGSize = .zero
        private var imageViews: [UUID: ImageLayerView] = [:]
        private var dragStartCenters: [UUID: CGPoint] = [:]
        private var dragStartLocations: [UUID: CGPoint] = [:]
        private var pinchStartScales: [UUID: CGFloat] = [:]
        private var selectedItemID: UUID?
        private var lastClearSelectionToken = 0

        init(_ parent: PencilCanvasView) {
            self.parent = parent
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            parent.drawingData = canvasView.drawing.dataRepresentation()
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            containerView
        }

        func syncImageViews(items: [ScrapImageItem]) {
            guard let containerView else { return }

            let existingIDs = Set(imageViews.keys)
            let incomingIDs = Set(items.map { $0.id })

            for removedID in existingIDs.subtracting(incomingIDs) {
                imageViews[removedID]?.removeFromSuperview()
                imageViews.removeValue(forKey: removedID)
                dragStartCenters.removeValue(forKey: removedID)
                dragStartLocations.removeValue(forKey: removedID)
                pinchStartScales.removeValue(forKey: removedID)
            }

            for item in items {
                let imageLayerView: ImageLayerView
                if let existingView = imageViews[item.id] {
                    imageLayerView = existingView
                } else {
                    let image = UIImage(data: item.imageData)
                    let newView = ImageLayerView(itemID: item.id, image: image)
                    newView.isUserInteractionEnabled = true
                    newView.contentMode = .scaleAspectFill
                    newView.clipsToBounds = false
                    newView.layer.cornerRadius = 10

                    let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
                    longPress.minimumPressDuration = 0.25
                    longPress.allowableMovement = 12
                    newView.addGestureRecognizer(longPress)

                    let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
                    newView.addGestureRecognizer(pinch)

                    let editMenuInteraction = UIEditMenuInteraction(delegate: self)
                    newView.addInteraction(editMenuInteraction)
                    newView.editMenuInteraction = editMenuInteraction

                    containerView.addSubview(newView)
                    imageViews[item.id] = newView
                    imageLayerView = newView
                }

                imageLayerView.image = UIImage(data: item.imageData)
                imageLayerView.layer.zPosition = CGFloat(item.zIndex)
                imageLayerView.setSelected(imageLayerView.itemID == selectedItemID)
                updateFrame(for: imageLayerView, item: item)
            }
        }

        func applyClearSelectionIfNeeded(token: Int) {
            if token != lastClearSelectionToken {
                clearSelection()
                lastClearSelectionToken = token
            }
        }

        @objc func handleBackgroundTap(_ gesture: UITapGestureRecognizer) {
            clearSelection()
        }

        private func clearSelection() {
            if let selectedID = selectedItemID,
               let view = imageViews[selectedID] {
                view.setSelected(false)
            }
            selectedItemID = nil
        }

        private func updateFrame(for view: ImageLayerView, item: ScrapImageItem) {
            let size = CGSize(width: item.baseSize.width * item.scale, height: item.baseSize.height * item.scale)
            view.frame = CGRect(
                x: item.center.x - size.width * 0.5,
                y: item.center.y - size.height * 0.5,
                width: size.width,
                height: size.height
            )
        }

        @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
            guard let view = gesture.view as? ImageLayerView,
                  let containerView else { return }
            let location = gesture.location(in: containerView)

            switch gesture.state {
            case .began:
                selectedItemID = view.itemID
                view.setSelected(true)
                dragStartCenters[view.itemID] = view.center
                dragStartLocations[view.itemID] = location
            case .changed:
                guard let startCenter = dragStartCenters[view.itemID],
                      let startLocation = dragStartLocations[view.itemID] else { return }
                let translation = CGPoint(x: location.x - startLocation.x, y: location.y - startLocation.y)
                let newCenter = CGPoint(x: startCenter.x + translation.x, y: startCenter.y + translation.y)
                updateItem(id: view.itemID) { item in
                    item.center = newCenter
                }
            case .ended, .cancelled:
                let movement = movementDistance(for: view.itemID, currentLocation: location)
                dragStartCenters.removeValue(forKey: view.itemID)
                dragStartLocations.removeValue(forKey: view.itemID)
                if movement < 6 {
                    presentEditMenu(from: view)
                } else {
                    view.setSelected(false)
                    selectedItemID = nil
                }
            default:
                break
            }
        }

        @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
            guard let view = gesture.view as? ImageLayerView else { return }

            switch gesture.state {
            case .began:
                if let item = parent.imageItems.first(where: { $0.id == view.itemID }) {
                    pinchStartScales[view.itemID] = item.scale
                }
            case .changed:
                guard let startScale = pinchStartScales[view.itemID] else { return }
                let newScale = max(0.2, min(5.0, startScale * gesture.scale))
                updateItem(id: view.itemID) { item in
                    item.scale = newScale
                }
            case .ended, .cancelled:
                pinchStartScales.removeValue(forKey: view.itemID)
            default:
                break
            }
        }

        private func movementDistance(for id: UUID, currentLocation: CGPoint) -> CGFloat {
            guard let startLocation = dragStartLocations[id] else { return 0 }
            let dx = currentLocation.x - startLocation.x
            let dy = currentLocation.y - startLocation.y
            return sqrt(dx * dx + dy * dy)
        }

        private func presentEditMenu(from view: ImageLayerView) {
            view.becomeFirstResponder()
            let sourcePoint = CGPoint(x: view.bounds.midX, y: -12)
            let configuration = UIEditMenuConfiguration(identifier: view.itemID.uuidString as NSString, sourcePoint: sourcePoint)
            view.editMenuInteraction?.presentEditMenu(with: configuration)
        }

        func editMenuInteraction(_ interaction: UIEditMenuInteraction, menuFor configuration: UIEditMenuConfiguration, suggestedActions: [UIMenuElement]) -> UIMenu? {
            guard let idString = configuration.identifier as? String,
                  let itemID = UUID(uuidString: idString) else { return nil }

            let bringForward = UIAction(title: "前面へ", image: UIImage(systemName: "arrow.up.to.line")) { [weak self] _ in
                self?.shiftZIndex(for: itemID, direction: 1)
            }
            let sendBackward = UIAction(title: "背面へ", image: UIImage(systemName: "arrow.down.to.line")) { [weak self] _ in
                self?.shiftZIndex(for: itemID, direction: -1)
            }
            let duplicate = UIAction(title: "複製", image: UIImage(systemName: "plus.square.on.square")) { [weak self] _ in
                self?.duplicateItem(id: itemID)
            }
            let crop = UIAction(title: "トリミング", image: UIImage(systemName: "crop")) { [weak self] _ in
                self?.parent.activeCropImageID = itemID
            }
            let delete = UIAction(title: "削除", image: UIImage(systemName: "trash"), attributes: .destructive) { [weak self] _ in
                self?.removeItem(id: itemID)
            }

            return UIMenu(title: "", children: [bringForward, sendBackward, duplicate, crop, delete])
        }

        func editMenuInteraction(_ interaction: UIEditMenuInteraction, willEndFor configuration: UIEditMenuConfiguration, animator: UIEditMenuInteractionAnimating) {
            animator.addCompletion { [weak self] in
                self?.clearSelection()
            }
        }

        private func updateItem(id: UUID, update: (inout ScrapImageItem) -> Void) {
            var items = parent.imageItems
            guard let index = items.firstIndex(where: { $0.id == id }) else { return }
            update(&items[index])
            parent.imageItems = items
        }

        private func removeItem(id: UUID) {
            var items = parent.imageItems
            items.removeAll { $0.id == id }
            parent.imageItems = normalizeZIndices(items)
        }

        private func duplicateItem(id: UUID) {
            guard let source = parent.imageItems.first(where: { $0.id == id }) else { return }
            var items = parent.imageItems
            var duplicated = source
            duplicated.id = UUID()
            duplicated.center = CGPoint(x: source.center.x + 40, y: source.center.y + 40)
            duplicated.zIndex = (items.map { $0.zIndex }.max() ?? -1) + 1
            items.append(duplicated)
            parent.imageItems = normalizeZIndices(items.sorted { $0.zIndex < $1.zIndex })
        }

        private func shiftZIndex(for id: UUID, direction: Int) {
            let sorted = parent.imageItems.sorted { $0.zIndex < $1.zIndex }
            guard let currentIndex = sorted.firstIndex(where: { $0.id == id }) else { return }
            let targetIndex = max(0, min(sorted.count - 1, currentIndex + direction))
            guard currentIndex != targetIndex else { return }

            var reordered = sorted
            reordered.swapAt(currentIndex, targetIndex)
            parent.imageItems = normalizeZIndices(reordered)
        }

        private func normalizeZIndices(_ items: [ScrapImageItem]) -> [ScrapImageItem] {
            items.enumerated().map { index, item in
                var updated = item
                updated.zIndex = Double(index)
                return updated
            }
        }
    }
}

private final class ImageLayerView: UIImageView {
    let itemID: UUID
    var editMenuInteraction: UIEditMenuInteraction?

    init(itemID: UUID, image: UIImage?) {
        self.itemID = itemID
        super.init(image: image)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setSelected(_ selected: Bool) {
        if selected {
            layer.shadowColor = UIColor.black.cgColor
            layer.shadowOpacity = 0.4
            layer.shadowRadius = 18
            layer.shadowOffset = CGSize(width: 0, height: 10)
            startWiggle()
        } else {
            layer.shadowOpacity = 0
            layer.shadowRadius = 0
            layer.shadowOffset = .zero
            stopWiggle()
        }
    }

    override var canBecomeFirstResponder: Bool {
        true
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let path = UIBezierPath(roundedRect: bounds, cornerRadius: layer.cornerRadius).cgPath
        if layer.mask == nil {
            let maskLayer = CAShapeLayer()
            maskLayer.path = path
            layer.mask = maskLayer
        } else if let shapeLayer = layer.mask as? CAShapeLayer {
            shapeLayer.path = path
        }
        layer.shadowPath = path
    }

    private func startWiggle() {
        if layer.animation(forKey: "wiggle") != nil {
            return
        }
        let rotation = CAKeyframeAnimation(keyPath: "transform.rotation.z")
        rotation.values = [-0.02, 0.02, -0.02]
        rotation.duration = 0.35
        rotation.repeatCount = .infinity
        rotation.isAdditive = true
        layer.add(rotation, forKey: "wiggle")

        let position = CAKeyframeAnimation(keyPath: "transform.translation.x")
        position.values = [-1.0, 1.0, -1.0]
        position.duration = 0.35
        position.repeatCount = .infinity
        position.isAdditive = true
        layer.add(position, forKey: "wigglePosition")
    }

    private func stopWiggle() {
        layer.removeAnimation(forKey: "wiggle")
        layer.removeAnimation(forKey: "wigglePosition")
    }
}

private extension CGRect {
    var center: CGPoint {
        CGPoint(x: midX, y: midY)
    }
}
