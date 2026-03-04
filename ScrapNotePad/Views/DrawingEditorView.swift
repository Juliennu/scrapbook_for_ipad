import PhotosUI
import PencilKit
import SwiftUI

struct DrawingEditorView: View {
    @EnvironmentObject private var store: NotebookStore
    @Binding var selectedNotebookID: UUID?
    @Binding var selectedPageID: UUID?

    @State private var drawingData = Data()
    @State private var imageItems: [ScrapImageItem] = []
    @State private var canvasView: PKCanvasView?
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var pageTurnForward = true
    @State private var activeCropImageID: UUID?
    @State private var cropTarget: ScrapImageItem?
    @State private var clearSelectionToken = 0

    private let pageSize = CGSize(width: 1600, height: 2200)

    var body: some View {
        Group {
            if let notebookID = selectedNotebookID,
               let pageID = selectedPageID,
               let page = store.page(notebookID: notebookID, pageID: pageID) {
                ZStack {
                    RoundedRectangle(cornerRadius: 0)
                        .fill(Color(uiColor: .secondarySystemBackground))

                    PencilCanvasView(
                        drawingData: $drawingData,
                        backgroundImageData: page.backgroundImageData,
                        imageItems: $imageItems,
                        activeCropImageID: $activeCropImageID,
                        clearSelectionToken: $clearSelectionToken,
                        canvasViewRef: $canvasView,
                    )
                    .padding(20)
                    .id(page.id)
                    .transition(.pageTurn(forward: pageTurnForward))
                }
                .navigationTitle(page.title)
                .navigationBarTitleDisplayMode(.inline)
                .onAppear {
                    drawingData = page.drawingData
                    imageItems = page.imageItems
                }
                .onChange(of: page.id) { _, _ in
                    drawingData = page.drawingData
                    imageItems = page.imageItems
                }
                .onChange(of: selectedPageID) { oldValue, newValue in
                    guard let oldID = oldValue,
                          let newID = newValue,
                          oldID != newID,
                          let notebook = store.notebook(by: notebookID),
                          let oldIndex = notebook.pages.firstIndex(where: { $0.id == oldID }),
                          let newIndex = notebook.pages.firstIndex(where: { $0.id == newID }) else { return }

                    pageTurnForward = newIndex > oldIndex
                    withAnimation(.easeInOut(duration: 0.28)) { }
                }
                .onChange(of: drawingData) { _, newData in
                    store.updateDrawing(notebookID: notebookID, pageID: pageID, drawingData: newData)
                }
                .onChange(of: imageItems) { _, newItems in
                    store.updateImageItems(notebookID: notebookID, pageID: pageID, imageItems: newItems)
                }
                .onChange(of: selectedPhotoItems) { _, items in
                    guard !items.isEmpty else { return }
                    Task {
                        let loadedItems = await loadImageItems(from: items)
                        await MainActor.run {
                            imageItems.append(contentsOf: loadedItems)
                            selectedPhotoItems = []
                        }
                    }
                }
                .onChange(of: activeCropImageID) { _, newID in
                    guard let newID,
                          let item = imageItems.first(where: { $0.id == newID }) else { return }
                    cropTarget = item
                }
                .fullScreenCover(item: $cropTarget) { item in
                    ImageCropView(
                        image: UIImage(data: item.imageData) ?? UIImage(),
                        onCancel: {
                            cropTarget = nil
                            activeCropImageID = nil
                            clearSelectionToken += 1
                        },
                        onApply: { croppedImage in
                            applyCropResult(for: item.id, croppedImage: croppedImage)
                            cropTarget = nil
                            activeCropImageID = nil
                            clearSelectionToken += 1
                        }
                    )
                }
                .gesture(
                    DragGesture(minimumDistance: 30)
                        .onEnded { value in
                            if value.translation.width < -80 {
                                goToNextPage(notebookID: notebookID, pageID: pageID)
                            } else if value.translation.width > 80 {
                                goToPreviousPage(notebookID: notebookID, pageID: pageID)
                            }
                        }
                )
                .toolbar {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Button {
                            goToPreviousPage(notebookID: notebookID, pageID: pageID)
                        } label: {
                            Label("Previous", systemImage: "chevron.left")
                        }

                        Button {
                            goToNextPage(notebookID: notebookID, pageID: pageID)
                        } label: {
                            Label("Next", systemImage: "chevron.right")
                        }

                        PhotosPicker(selection: $selectedPhotoItems, matching: .images, photoLibrary: .shared()) {
                            Label("Image", systemImage: "photo")
                        }

                        Button {
                            canvasView?.undoManager?.undo()
                        } label: {
                            Label("Undo", systemImage: "arrow.uturn.backward")
                        }

                        Button {
                            canvasView?.undoManager?.redo()
                        } label: {
                            Label("Redo", systemImage: "arrow.uturn.forward")
                        }
                    }
                }
            } else {
                ContentUnavailableView("Pageを選択", systemImage: "scribble", description: Text("中央カラムからページを選ぶとここで編集できます"))
            }
        }
    }

    private func applyCropResult(for id: UUID, croppedImage: UIImage) {
        guard let data = croppedImage.pngData() else { return }
        var items = imageItems
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        let currentDisplaySize = CGSize(
            width: items[index].baseSize.width * items[index].scale,
            height: items[index].baseSize.height * items[index].scale
        )
        let newBaseSize = croppedImage.size
        let scaleX = currentDisplaySize.width / max(newBaseSize.width, 1)
        let scaleY = currentDisplaySize.height / max(newBaseSize.height, 1)
        let newScale = min(scaleX, scaleY)

        items[index].imageData = data
        items[index].baseSize = newBaseSize
        items[index].scale = max(newScale, 0.1)
        imageItems = items
    }

    private func loadImageItems(from items: [PhotosPickerItem]) async -> [ScrapImageItem] {
        var results: [ScrapImageItem] = []
        var nextIndex = nextZIndex()
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else { continue }
            let baseSize = fittedBaseSize(for: image.size)
            let newItem = ScrapImageItem(
                imageData: data,
                center: CGPoint(x: pageSize.width * 0.5, y: pageSize.height * 0.5),
                baseSize: baseSize,
                scale: 1.0,
                zIndex: nextIndex
            )
            nextIndex += 1
            results.append(newItem)
        }
        return results
    }

    private func fittedBaseSize(for imageSize: CGSize) -> CGSize {
        let maxDimension: CGFloat = 700
        let widthScale = maxDimension / max(imageSize.width, 1)
        let heightScale = maxDimension / max(imageSize.height, 1)
        let scale = min(1, min(widthScale, heightScale))
        return CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
    }

    private func nextZIndex() -> Double {
        (imageItems.map { $0.zIndex }.max() ?? -1) + 1
    }

    private func goToNextPage(notebookID: UUID, pageID: UUID) {
        guard let nextID = store.nextPageID(notebookID: notebookID, currentPageID: pageID) else { return }
        pageTurnForward = true
        withAnimation(.easeInOut(duration: 0.28)) {
            selectedPageID = nextID
        }
    }

    private func goToPreviousPage(notebookID: UUID, pageID: UUID) {
        guard let previousID = store.previousPageID(notebookID: notebookID, currentPageID: pageID) else { return }
        pageTurnForward = false
        withAnimation(.easeInOut(duration: 0.28)) {
            selectedPageID = previousID
        }
    }
}

private struct PageTurnModifier: ViewModifier {
    var angle: Double
    var anchor: UnitPoint

    func body(content: Content) -> some View {
        content
            .rotation3DEffect(
                .degrees(angle),
                axis: (x: 0, y: 1, z: 0),
                anchor: anchor,
                perspective: 0.7
            )
            .opacity(abs(angle) > 80 ? 0.25 : 1)
    }
}

private extension AnyTransition {
    static func pageTurn(forward: Bool) -> AnyTransition {
        let insertion = AnyTransition.modifier(
            active: PageTurnModifier(angle: forward ? -85 : 85, anchor: forward ? .leading : .trailing),
            identity: PageTurnModifier(angle: 0, anchor: .center)
        )
        let removal = AnyTransition.modifier(
            active: PageTurnModifier(angle: forward ? 85 : -85, anchor: forward ? .trailing : .leading),
            identity: PageTurnModifier(angle: 0, anchor: .center)
        )
        return .asymmetric(insertion: insertion.combined(with: .opacity), removal: removal.combined(with: .opacity))
    }
}
