import Foundation
import SwiftData

/// Email attachment model with metadata and external content storage.
@Model
final class Attachment {
    /// Unique identifier for the attachment.
    @Attribute(.unique)
    var id: UUID

    /// Original filename of the attachment.
    var filename: String

    /// MIME content type (e.g., "application/pdf").
    var mimeType: String

    /// File size in bytes.
    var size: Int

    /// Content-ID for inline attachments (CID references in HTML).
    var contentId: String?

    /// Content-Disposition: "attachment" or "inline".
    var disposition: AttachmentDisposition

    /// IMAP body section path for fetching (e.g., "1.2").
    var bodySection: String?

    /// Whether the content has been downloaded.
    var isDownloaded: Bool

    /// Binary content stored externally for large files.
    @Attribute(.externalStorage)
    var content: Data?

    /// Message this attachment belongs to.
    var message: Message?

    /// Creates a new attachment.
    init(
        id: UUID = UUID(),
        filename: String,
        mimeType: String,
        size: Int,
        contentId: String? = nil,
        disposition: AttachmentDisposition = .attachment,
        bodySection: String? = nil,
        isDownloaded: Bool = false,
        content: Data? = nil,
        message: Message? = nil
    ) {
        self.id = id
        self.filename = filename
        self.mimeType = mimeType
        self.size = size
        self.contentId = contentId
        self.disposition = disposition
        self.bodySection = bodySection
        self.isDownloaded = isDownloaded
        self.content = content
        self.message = message
    }
}

// MARK: - Computed Properties

extension Attachment {
    /// File extension derived from filename.
    var fileExtension: String {
        (filename as NSString).pathExtension.lowercased()
    }

    /// Human-readable file size.
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
    }

    /// SF Symbol icon based on MIME type.
    var iconName: String {
        let mimeTypeLower = mimeType.lowercased()

        if mimeTypeLower.hasPrefix("image/") {
            return "photo"
        } else if mimeTypeLower.hasPrefix("video/") {
            return "film"
        } else if mimeTypeLower.hasPrefix("audio/") {
            return "waveform"
        } else if mimeTypeLower == "application/pdf" {
            return "doc.richtext"
        } else if mimeTypeLower.contains("zip") || mimeTypeLower.contains("compressed") {
            return "doc.zipper"
        } else if mimeTypeLower.contains("word") || fileExtension == "doc" || fileExtension == "docx" {
            return "doc.text"
        } else if mimeTypeLower.contains("excel") || mimeTypeLower.contains("spreadsheet") || fileExtension == "xls" || fileExtension == "xlsx" {
            return "tablecells"
        } else if mimeTypeLower.contains("powerpoint") || mimeTypeLower.contains("presentation") || fileExtension == "ppt" || fileExtension == "pptx" {
            return "rectangle.on.rectangle"
        } else if mimeTypeLower.hasPrefix("text/") {
            return "doc.plaintext"
        }

        return "doc"
    }

    /// Whether this is an inline image (for HTML email display).
    var isInlineImage: Bool {
        disposition == .inline && mimeType.hasPrefix("image/") && contentId != nil
    }

    /// CID URL for referencing in HTML (cid:content-id).
    var cidURL: String? {
        guard let contentId = contentId else { return nil }
        // Remove angle brackets if present
        let cleanId = contentId.trimmingCharacters(in: CharacterSet(charactersIn: "<>"))
        return "cid:\(cleanId)"
    }
}

// MARK: - Attachment Disposition

/// Content-Disposition type for attachments.
enum AttachmentDisposition: String, Codable {
    case attachment
    case inline

    /// Creates disposition from Content-Disposition header value.
    static func from(header: String?) -> AttachmentDisposition {
        guard let header = header?.lowercased() else {
            return .attachment
        }
        if header.contains("inline") {
            return .inline
        }
        return .attachment
    }
}

// MARK: - Attachment Utilities

extension Attachment {
    /// Suggested location to save this attachment.
    var suggestedSaveURL: URL {
        let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        return downloadsURL.appendingPathComponent(filename)
    }

    /// Writes attachment content to a file URL.
    func write(to url: URL) throws {
        guard let content = content else {
            throw AttachmentError.contentNotDownloaded
        }
        try content.write(to: url)
    }

    /// Gets a unique filename if the suggested one already exists.
    func uniqueSaveURL(in directory: URL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!) -> URL {
        let fileManager = FileManager.default
        var url = directory.appendingPathComponent(filename)

        if !fileManager.fileExists(atPath: url.path) {
            return url
        }

        let name = (filename as NSString).deletingPathExtension
        let ext = (filename as NSString).pathExtension
        var counter = 1

        repeat {
            let newFilename = ext.isEmpty ? "\(name) (\(counter))" : "\(name) (\(counter)).\(ext)"
            url = directory.appendingPathComponent(newFilename)
            counter += 1
        } while fileManager.fileExists(atPath: url.path)

        return url
    }
}

// MARK: - Attachment Errors

/// Errors related to attachment operations.
enum AttachmentError: LocalizedError {
    case contentNotDownloaded
    case writeFailed(Error)

    var errorDescription: String? {
        switch self {
        case .contentNotDownloaded:
            return "Attachment content has not been downloaded yet."
        case .writeFailed(let error):
            return "Failed to write attachment: \(error.localizedDescription)"
        }
    }
}
