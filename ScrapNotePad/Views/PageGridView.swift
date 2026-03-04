import PencilKit
import SwiftUI

struct PageGridView: View {
    @EnvironmentObject private var store: NotebookStore
    @Binding var selectedNotebookID: UUID?
    @Binding var selectedPageID: UUID?

    private let columns = [
        GridItem(.adaptive(minimum: 220, maximum: 280), spacing: 16)
    ]

    var body: some View {
        Group {
            if let notebook = store.notebook(by: selectedNotebookID) {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(notebook.pages) { page in
                            PageCardView(page: page, isSelected: page.id == selectedPageID)
                                .onTapGesture {
                                    withAnimation(.easeInOut(duration: 0.28)) {
                                        selectedPageID = page.id
                                    }
                                }
                                .contextMenu {
                                    Button(role: .destructive) {
                                        store.deletePage(notebookID: notebook.id, pageID: page.id)
                                        if selectedPageID == page.id {
                                            selectedPageID = store.notebook(by: notebook.id)?.pages.first?.id
                                        }
                                    } label: {
                                        Label("Delete Page", systemImage: "trash")
                                    }
                                }
                        }
                    }
                    .padding()
                }
                .navigationTitle(notebook.title)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            withAnimation(.easeInOut(duration: 0.28)) {
                                selectedPageID = store.addPage(to: notebook.id)
                            }
                        } label: {
                            Label("New Page", systemImage: "plus.square")
                        }
                    }
                }
            } else {
                ContentUnavailableView("Notebookを選択", systemImage: "book.closed", description: Text("左側の一覧からノートを選んでください"))
            }
        }
    }
}

private struct PageCardView: View {
    let page: ScrapPage
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.regularMaterial)
                    .frame(height: 180)

                VStack(spacing: 0) {
                    if let backgroundImageData = page.backgroundImageData,
                       let uiImage = UIImage(data: backgroundImageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 180)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }

                    if let drawing = try? PKDrawing(data: page.drawingData) {
                        Image(uiImage: drawing.image(from: CGRect(x: 0, y: 0, width: 1024, height: 768), scale: 0.25))
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 170)
                    }
                }
            }

            Text(page.title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
    }
}
