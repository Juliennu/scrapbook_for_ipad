import SwiftUI

struct NotebookListView: View {
    @EnvironmentObject private var store: NotebookStore
    @Binding var selectedNotebookID: UUID?
    @Binding var selectedPageID: UUID?

    @State private var newNotebookTitle = ""

    var body: some View {
        List(selection: $selectedNotebookID) {
            ForEach(store.notebooks) { notebook in
                VStack(alignment: .leading, spacing: 4) {
                    Text(notebook.title)
                        .font(.headline)
                    Text("\(notebook.pages.count) pages")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .tag(notebook.id)
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedNotebookID = notebook.id
                    selectedPageID = notebook.pages.first?.id
                }
            }
            .onDelete(perform: store.deleteNotebooks)
        }
        .navigationTitle("Notebooks")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    let id = store.addNotebook(title: newNotebookTitle)
                    selectedNotebookID = id
                    selectedPageID = store.notebook(by: id)?.pages.first?.id
                    newNotebookTitle = ""
                } label: {
                    Label("New Notebook", systemImage: "plus")
                }
            }
        }
    }
}
