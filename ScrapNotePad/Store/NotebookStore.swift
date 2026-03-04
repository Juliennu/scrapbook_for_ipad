import Foundation

@MainActor
final class NotebookStore: ObservableObject {
    @Published private(set) var notebooks: [ScrapNotebook] = []

    private let saveURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init() {
        let baseURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        self.saveURL = baseURL.appendingPathComponent("scrap_notebooks.json")
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        load()
        if notebooks.isEmpty {
            seed()
        }
    }

    func notebook(by id: UUID?) -> ScrapNotebook? {
        guard let id else { return nil }
        return notebooks.first(where: { $0.id == id })
    }

    func page(notebookID: UUID?, pageID: UUID?) -> ScrapPage? {
        guard let notebookID, let pageID,
              let notebook = notebook(by: notebookID) else { return nil }
        return notebook.pages.first(where: { $0.id == pageID })
    }

    func nextPageID(notebookID: UUID, currentPageID: UUID) -> UUID? {
        adjacentPageID(notebookID: notebookID, currentPageID: currentPageID, offset: 1)
    }

    func previousPageID(notebookID: UUID, currentPageID: UUID) -> UUID? {
        adjacentPageID(notebookID: notebookID, currentPageID: currentPageID, offset: -1)
    }

    func addNotebook(title: String) -> UUID {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = trimmed.isEmpty ? "Untitled Notebook" : trimmed
        let now = Date()
        let notebook = ScrapNotebook(title: name, createdAt: now, updatedAt: now, pages: [ScrapPage(title: "Page 1")])
        notebooks.insert(notebook, at: 0)
        save()
        return notebook.id
    }

    func deleteNotebooks(at offsets: IndexSet) {
        notebooks.remove(atOffsets: offsets)
        save()
    }

    func addPage(to notebookID: UUID) -> UUID? {
        guard let index = notebooks.firstIndex(where: { $0.id == notebookID }) else { return nil }
        var notebook = notebooks[index]
        let page = ScrapPage(title: "Page \(notebook.pages.count + 1)")
        notebook.pages.append(page)
        notebook.updatedAt = .now
        notebooks[index] = notebook
        save()
        return page.id
    }

    func deletePage(notebookID: UUID, pageID: UUID) {
        guard let index = notebooks.firstIndex(where: { $0.id == notebookID }) else { return }
        var notebook = notebooks[index]
        notebook.pages.removeAll { $0.id == pageID }
        notebook.updatedAt = .now
        notebooks[index] = notebook
        save()
    }

    func updateDrawing(notebookID: UUID, pageID: UUID, drawingData: Data) {
        guard let notebookIndex = notebooks.firstIndex(where: { $0.id == notebookID }) else { return }
        guard let pageIndex = notebooks[notebookIndex].pages.firstIndex(where: { $0.id == pageID }) else { return }
        notebooks[notebookIndex].pages[pageIndex].drawingData = drawingData
        notebooks[notebookIndex].pages[pageIndex].updatedAt = .now
        notebooks[notebookIndex].updatedAt = .now
        save()
    }

    func updateBackgroundImage(notebookID: UUID, pageID: UUID, imageData: Data?) {
        guard let notebookIndex = notebooks.firstIndex(where: { $0.id == notebookID }) else { return }
        guard let pageIndex = notebooks[notebookIndex].pages.firstIndex(where: { $0.id == pageID }) else { return }
        notebooks[notebookIndex].pages[pageIndex].backgroundImageData = imageData
        notebooks[notebookIndex].pages[pageIndex].updatedAt = .now
        notebooks[notebookIndex].updatedAt = .now
        save()
    }

    func updateImageItems(notebookID: UUID, pageID: UUID, imageItems: [ScrapImageItem]) {
        guard let notebookIndex = notebooks.firstIndex(where: { $0.id == notebookID }) else { return }
        guard let pageIndex = notebooks[notebookIndex].pages.firstIndex(where: { $0.id == pageID }) else { return }
        notebooks[notebookIndex].pages[pageIndex].imageItems = imageItems
        notebooks[notebookIndex].pages[pageIndex].updatedAt = .now
        notebooks[notebookIndex].updatedAt = .now
        save()
    }

    private func adjacentPageID(notebookID: UUID, currentPageID: UUID, offset: Int) -> UUID? {
        guard let notebookIndex = notebooks.firstIndex(where: { $0.id == notebookID }) else { return nil }
        let pages = notebooks[notebookIndex].pages
        guard let currentIndex = pages.firstIndex(where: { $0.id == currentPageID }) else { return nil }
        let nextIndex = currentIndex + offset
        guard nextIndex >= 0, nextIndex < pages.count else { return nil }
        return pages[nextIndex].id
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: saveURL.path) else { return }
        do {
            let data = try Data(contentsOf: saveURL)
            notebooks = try decoder.decode([ScrapNotebook].self, from: data)
        } catch {
            notebooks = []
        }
    }

    private func save() {
        do {
            let data = try encoder.encode(notebooks)
            try data.write(to: saveURL, options: .atomic)
        } catch {
            print("Save error: \(error.localizedDescription)")
        }
    }

    private func seed() {
        let id = addNotebook(title: "My Scrapbook")
        guard let notebookIndex = notebooks.firstIndex(where: { $0.id == id }) else { return }
        let introPage = ScrapPage(title: "Ideas")
        notebooks[notebookIndex].pages = [introPage]
        save()
    }
}
