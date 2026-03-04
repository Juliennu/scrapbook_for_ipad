import SwiftUI

struct RootSplitView: View {
    @EnvironmentObject private var store: NotebookStore
    @State private var selectedNotebookID: UUID?
    @State private var selectedPageID: UUID?

    var body: some View {
        NavigationSplitView {
            NotebookListView(selectedNotebookID: $selectedNotebookID, selectedPageID: $selectedPageID)
        } content: {
            PageGridView(selectedNotebookID: $selectedNotebookID, selectedPageID: $selectedPageID)
        } detail: {
            DrawingEditorView(selectedNotebookID: $selectedNotebookID, selectedPageID: $selectedPageID)
        }
        .onAppear {
            guard selectedNotebookID == nil, let firstNotebook = store.notebooks.first else { return }
            selectedNotebookID = firstNotebook.id
            selectedPageID = firstNotebook.pages.first?.id
        }
    }
}
