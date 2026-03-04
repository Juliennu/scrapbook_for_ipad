import PhotosUI
import PencilKit
import SwiftUI

struct DrawingEditorView: View {
    @EnvironmentObject private var store: NotebookStore
    @Binding var selectedNotebookID: UUID?
    @Binding var selectedPageID: UUID?

    @State private var drawingData = Data()
    @State private var canvasView: PKCanvasView?
    @State private var allowsFingerDrawing = true
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var pageTurnForward = true

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
                        canvasViewRef: $canvasView,
                        allowsFingerDrawing: allowsFingerDrawing
                    )
                    .padding(20)
                    .id(page.id)
                    .transition(.pageTurn(forward: pageTurnForward))
                }
                .navigationTitle(page.title)
                .navigationBarTitleDisplayMode(.inline)
                .onAppear {
                    drawingData = page.drawingData
                }
                .onChange(of: page.id) { _, _ in
                    drawingData = page.drawingData
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
                .onChange(of: selectedPhotoItem) { _, item in
                    guard let item else { return }
                    Task {
                        if let data = try? await item.loadTransferable(type: Data.self) {
                            await MainActor.run {
                                store.updateBackgroundImage(notebookID: notebookID, pageID: pageID, imageData: data)
                            }
                        }
                    }
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

                        PhotosPicker(selection: $selectedPhotoItem, matching: .images, photoLibrary: .shared()) {
                            Label("Image", systemImage: "photo")
                        }

                        Button {
                            store.updateBackgroundImage(notebookID: notebookID, pageID: pageID, imageData: nil)
                        } label: {
                            Label("Remove Image", systemImage: "photo.badge.minus")
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

                        Toggle(isOn: $allowsFingerDrawing) {
                            Label("Finger", systemImage: "hand.draw")
                        }
                        .toggleStyle(.button)
                    }
                }
            } else {
                ContentUnavailableView("Pageを選択", systemImage: "scribble", description: Text("中央カラムからページを選ぶとここで編集できます"))
            }
        }
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
