import Foundation
import os
import UIKit
import UniformTypeIdentifiers

enum ProfileDocumentUserError: Error, Equatable, LocalizedError {
    case tooLarge
    case invalidDocument
    case unreadableDocument
    case saveFailed
    case exportFailed

    var errorDescription: String? {
        switch self {
        case .tooLarge:
            return NSLocalizedString(
                "This profile document is too large.",
                comment: "Profile document exceeds the supported size"
            )
        case .invalidDocument:
            return NSLocalizedString(
                "This is not a valid NumPad profile document.",
                comment: "Invalid profile document"
            )
        case .unreadableDocument:
            return NSLocalizedString(
                "The profile document could not be read.",
                comment: "Profile document provider read failure"
            )
        case .saveFailed:
            return NSLocalizedString(
                "The profile could not be saved.",
                comment: "Profile import persistence error"
            )
        case .exportFailed:
            return NSLocalizedString(
                "The profile document could not be created.",
                comment: "Profile document export error"
            )
        }
    }
}

/// Owns the exported temporary directory for exactly as long as the share sheet needs it.
/// The share controller retains its activity item, so dismissal, completion, or abandonment
/// releases this object and deterministically removes the directory.
final class ProfileExportArtifact: NSObject, UIActivityItemSource {
    let fileURL: URL
    private let directoryURL: URL
    private let lock = NSLock()
    private var cleaned = false

    init(fileURL: URL, directoryURL: URL) {
        self.fileURL = fileURL
        self.directoryURL = directoryURL
    }

    func cleanup() {
        lock.lock()
        guard !cleaned else {
            lock.unlock()
            return
        }
        cleaned = true
        lock.unlock()
        try? FileManager.default.removeItem(at: directoryURL)
    }

    deinit { cleanup() }

    func activityViewControllerPlaceholderItem(
        _ activityViewController: UIActivityViewController
    ) -> Any {
        fileURL
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        itemForActivityType activityType: UIActivity.ActivityType?
    ) -> Any? {
        fileURL
    }
}

/// App-only boundary for profile documents. Bytes are bounded and shape-validated before the
/// profile store is touched, and imported profiles are always editable custom profiles.
struct ProfileImportCoordinator {
    let store: KeyboardProfileStore
    var makeUUID: () -> UUID = UUID.init
    var startSecurityScope: (URL) -> Bool = { $0.startAccessingSecurityScopedResource() }
    var stopSecurityScope: (URL) -> Void = { $0.stopAccessingSecurityScopedResource() }
    var loadData: (URL) throws -> Data = Self.readBounded

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.morevoltage.NumPad",
        category: "ProfileDocuments"
    )

    static var documentType: UTType {
        UTType(importedAs: "com.morevoltage.numpad.profile", conformingTo: .json)
    }

    func makeImportPicker() -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: [Self.documentType, .json],
            asCopy: true
        )
        picker.allowsMultipleSelection = false
        picker.view.accessibilityIdentifier = "profiles.import.picker"
        return picker
    }

    func makeExportActivityController(for profile: KeyboardProfile) throws -> UIActivityViewController {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("NumPadProfile-\(UUID().uuidString)", isDirectory: true)
        let artifact = try makeExportArtifact(for: profile, in: directory)
        let controller = UIActivityViewController(
            activityItems: [artifact],
            applicationActivities: nil
        )
        controller.completionWithItemsHandler = { _, _, _, _ in artifact.cleanup() }
        return controller
    }

    func exportData(for profile: KeyboardProfile) throws -> Data {
        do {
            return try KeyboardProfileDocument.encode(profile)
        } catch {
            Self.log(error, operation: "encode")
            throw ProfileDocumentUserError.exportFailed
        }
    }

    func makeExportArtifact(
        for profile: KeyboardProfile,
        in directory: URL
    ) throws -> ProfileExportArtifact {
        let fileURL = try makeExportFile(for: profile, in: directory)
        return ProfileExportArtifact(fileURL: fileURL, directoryURL: directory)
    }

    func makeExportFile(for profile: KeyboardProfile, in directory: URL) throws -> URL {
        do {
            let data = try exportData(for: profile)
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
            let base = profile.name
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { !$0.isEmpty }
                .joined(separator: "-")
            let fileName = (base.isEmpty ? "NumPad-Profile" : String(base.prefix(64)))
                + ".numpadprofile"
            let fileURL = directory.appendingPathComponent(fileName, isDirectory: false)
            try data.write(to: fileURL, options: [.atomic])
            return fileURL
        } catch {
            try? FileManager.default.removeItem(at: directory)
            Self.log(error, operation: "write")
            throw (error as? ProfileDocumentUserError) ?? .exportFailed
        }
    }

    @discardableResult
    func importProfile(at url: URL) throws -> KeyboardProfile {
        try storePreparedProfile(prepareImport(at: url))
    }

    func prepareImport(at url: URL) throws -> KeyboardProfile {
        let scoped = startSecurityScope(url)
        defer {
            if scoped { stopSecurityScope(url) }
        }
        do {
            return try prepareImport(data: loadData(url))
        } catch let error as ProfileDocumentUserError {
            throw error
        } catch {
            Self.log(error, operation: "read")
            throw ProfileDocumentUserError.unreadableDocument
        }
    }

    @discardableResult
    func importProfile(data: Data) throws -> KeyboardProfile {
        try storePreparedProfile(prepareImport(data: data))
    }

    func prepareImport(data: Data) throws -> KeyboardProfile {
        guard data.count <= KeyboardProfileDocument.maxBytes else {
            throw ProfileDocumentUserError.tooLarge
        }
        do {
            var imported = try KeyboardProfileDocument.decodeAndValidate(data)
            let snapshot = store.load()
            imported.kind = .custom
            if snapshot.profiles.contains(where: { $0.id == imported.id }) {
                imported.id = uniqueID(existing: Set(snapshot.profiles.map(\.id)))
                imported.name = copiedName(imported.name)
            }
            imported = try imported.validated()
            if let custom = imported.configuration.customKeyboardConfig {
                try CustomKeyboardProfileValidation.validate(custom)
            }
            return imported
        } catch let error as ProfileDocumentUserError {
            throw error
        } catch {
            Self.log(error, operation: "validate")
            throw ProfileDocumentUserError.invalidDocument
        }
    }

    @discardableResult
    func storePreparedProfile(_ imported: KeyboardProfile) throws -> KeyboardProfile {
        do {
            let validated = try imported.validated()
            if let custom = validated.configuration.customKeyboardConfig {
                try CustomKeyboardProfileValidation.validate(custom)
            }
            var snapshot = store.load()
            guard !snapshot.profiles.contains(where: { $0.id == validated.id }) else {
                var collisionCopy = validated
                collisionCopy.id = uniqueID(existing: Set(snapshot.profiles.map(\.id)))
                collisionCopy.name = copiedName(collisionCopy.name)
                return try storePreparedProfile(collisionCopy)
            }
            snapshot.profiles.append(validated)
            try store.save(snapshot)
            return validated
        } catch {
            Self.log(error, operation: "store")
            throw ProfileDocumentUserError.saveFailed
        }
    }

    private func uniqueID(existing: Set<UUID>) -> UUID {
        var candidate = makeUUID()
        while existing.contains(candidate) { candidate = UUID() }
        return candidate
    }

    private func copiedName(_ name: String) -> String {
        let suffix = NSLocalizedString(" Copy", comment: "Imported profile collision name suffix")
        let allowedBaseCount = max(1, 80 - suffix.count)
        return String(name.prefix(allowedBaseCount)) + suffix
    }

    private static func readBounded(_ url: URL) throws -> Data {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        return try handle.read(upToCount: KeyboardProfileDocument.maxBytes + 1) ?? Data()
    }

    private static func log(_ error: Error, operation: String) {
        logger.error(
            "Profile document \(operation, privacy: .public) failed: \(String(describing: error), privacy: .private)"
        )
    }
}
