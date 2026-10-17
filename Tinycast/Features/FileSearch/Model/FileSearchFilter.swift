import Foundation
import UniformTypeIdentifiers

/// The Search Files header filter. See docs/features/file-search.md#type-filter.
enum FileSearchFilter: String, CaseIterable, Sendable {
    case useful
    case all
    case folders
    case documents
    case images
    case audio
    case video
    case archives

    var title: String {
        switch self {
        case .useful: return "Useful Files"
        case .all: return "Everything"
        case .folders: return "Folders"
        case .documents: return "Documents"
        case .images: return "Images"
        case .audio: return "Audio"
        case .video: return "Videos"
        case .archives: return "Archives"
        }
    }

    /// Also the header button's glyph, so it states the active filter without opening the menu.
    var systemImage: String {
        switch self {
        case .useful: return "doc.text.magnifyingglass"
        case .all: return "list.bullet"
        case .folders: return "folder"
        case .documents: return "doc.text"
        case .images: return "photo"
        case .audio: return "waveform"
        case .video: return "film"
        case .archives: return "archivebox"
        }
    }

    /// What an empty list says, so a filter hiding every match explains itself.
    var emptyMessage: String {
        switch self {
        case .useful: return "No useful files found. Try Everything."
        case .all: return "No files found"
        case .folders: return "No folders found"
        case .documents: return "No documents found"
        case .images: return "No images found"
        case .audio: return "No audio found"
        case .video: return "No videos found"
        case .archives: return "No archives found"
        }
    }

    /// The types a case admits; `all` names none, which is what keeps an unfiltered search free.
    var contentTypes: [UTType] {
        switch self {
        case .useful:
            return [.folder, .text, .compositeContent, .spreadsheet, .presentation, .pdf,
                    .image, .audio, .movie, .archive, .sourceCode, .json, .xml]
        case .all: return []
        case .folders: return [.folder]
        case .documents: return [.text, .compositeContent, .spreadsheet, .presentation, .pdf]
        case .images: return [.image]
        case .audio: return [.audio]
        case .video: return [.movie]
        case .archives: return [.archive]
        }
    }

    /// Filtering in the predicate keeps the rejected types from consuming the candidate cap.
    var spotlightClause: String? {
        var clauses = contentTypes.map { "kMDItemContentTypeTree == \"\($0.identifier)\"" }
        if self == .useful {
            clauses += Self.projectExtensions.map { "kMDItemFSName == \"*.\($0)\"cd" }
            clauses += Self.projectNames.map { "kMDItemFSName == \"\($0)\"cd" }
        }
        guard let first = clauses.first else { return nil }
        guard clauses.count > 1 else { return first }
        return "(" + clauses.joined(separator: " || ") + ")"
    }

    static let projectExtensions = [
        "swift", "m", "mm", "h", "c", "cpp", "rs", "go", "py", "js", "jsx", "ts", "tsx",
        "sh", "rb", "php", "java", "kt", "cs", "html", "css", "scss", "sql", "graphql",
        "md", "mdx", "json", "yaml", "yml", "toml", "ini", "cfg", "conf", "xml", "plist",
        "xcodeproj", "xcworkspace", "pbxproj", "xcconfig", "ipynb", "vue", "svelte"
    ]
    static let projectNames = ["makefile", "dockerfile", "gemfile", "rakefile", "license", "readme"]

    /// The home-root branch never reaches Spotlight, so it answers the same question locally.
    func accepts(contentType: UTType?, isDirectory: Bool, filename: String = "") -> Bool {
        guard self != .all else { return true }
        if self == .useful {
            let name = filename.lowercased()
            if isDirectory || Self.projectNames.contains(name)
                || Self.projectExtensions.contains((name as NSString).pathExtension) { return true }
        }
        // An unresolved type is only ever a plain directory: everything else carries one.
        guard let contentType else { return self == .folders && isDirectory }
        return contentTypes.contains { contentType.conforms(to: $0) }
    }
}
