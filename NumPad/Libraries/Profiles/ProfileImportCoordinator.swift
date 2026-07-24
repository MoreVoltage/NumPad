import Foundation
import UIKit
import UniformTypeIdentifiers

enum ProfileImportCoordinatorError: Error, Equatable, CustomStringConvertible {
    case persistence(String)
    case export(String)

    var description: String {
        switch self {
        case .persistence:
            return NSLocalizedString(
                "The profile could not be saved.",
                comment: "Profile import persistence error"
            )
        case .export:
            return NSLocalizedString(
                "The profile document could not be created.",
                comment: "Profile document export error"
            )
        }
    }
}

/// App-only boundary for profile documents. It is deliberately the only import path used by
/// `ProfilesViewController`: bytes are size/shape validated before the profile store is touched,
/// and imported profiles are always editable custom profiles.
struct ProfileImportCoordinator {
    let store: KeyboardProfileStore
    var makeUUID: () -> UUID = UUID.init
    var startSecurityScope: (URL) -> Bool = { $0.startAccessingSecurityScopedResource() }
    var stopSecurityScope: (URL) -> Void = { $0.stopAccessingSecurityScopedResource() }
    var loadData: (URL) throws -> Data = {
        try Data(contentsOf: $0, options: [.mappedIfSafe])
    }

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
        let fileURL = try makeExportFile(for: profile, in: directory)
        let controller = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
        controller.completionWithItemsHandler = { _, _, _, _ in
            try? FileManager.default.removeItem(at: directory)
        }
        return controller
    }

    func exportData(for profile: KeyboardProfile) throws -> Data {
        try KeyboardProfileDocument.encode(profile)
    }

    func makeExportFile(for profile: KeyboardProfile, in directory: URL) throws -> URL {
        let data = try exportData(for: profile)
        do {
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
            throw ProfileImportCoordinatorError.export(String(describing: error))
        }
    }

    @discardableResult
    func importProfile(at url: URL) throws -> KeyboardProfile {
        try storePreparedProfile(prepareImport(at: url))
    }

    /// Reads and fully validates an external document without mutating the store. The UI uses
    /// this to present a safe summary before the user confirms import.
    func prepareImport(at url: URL) throws -> KeyboardProfile {
        let scoped = startSecurityScope(url)
        defer {
            if scoped {
                stopSecurityScope(url)
            }
        }
        // A copied document inside our own container can legitimately return false from
        // `startAccessingSecurityScopedResource`; the data read remains sandbox-safe.
        if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize,
           size > KeyboardProfileDocument.maxBytes {
            throw KeyboardProfileDocument.DocumentError.tooLarge
        }
        let data = try loadData(url)
        return try prepareImport(data: data)
    }

    @discardableResult
    func importProfile(data: Data) throws -> KeyboardProfile {
        try storePreparedProfile(prepareImport(data: data))
    }

    func prepareImport(data: Data) throws -> KeyboardProfile {
        var imported = try KeyboardProfileDocument.decodeAndValidate(data)
        let snapshot = store.load()

        // Non-custom kinds are factory-owned and re-created on each load. Imported documents
        // become custom profiles so they remain stored and editable.
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
    }

    @discardableResult
    func storePreparedProfile(_ imported: KeyboardProfile) throws -> KeyboardProfile {
        let validated = try imported.validated()
        if let custom = validated.configuration.customKeyboardConfig {
            try CustomKeyboardProfileValidation.validate(custom)
        }
        var snapshot = store.load()
        guard !snapshot.profiles.contains(where: { $0.id == validated.id }) else {
            // The UI normally resolves this during preparation. Re-resolve a race between the
            // confirmation alert and commit rather than overwriting a profile.
            var collisionCopy = validated
            collisionCopy.id = uniqueID(existing: Set(snapshot.profiles.map(\.id)))
            collisionCopy.name = copiedName(collisionCopy.name)
            return try storePreparedProfile(collisionCopy)
        }
        snapshot.profiles.append(validated)
        do {
            try store.save(snapshot)
        } catch {
            throw ProfileImportCoordinatorError.persistence(String(describing: error))
        }
        return validated
    }

    private func uniqueID(existing: Set<UUID>) -> UUID {
        var candidate = makeUUID()
        while existing.contains(candidate) {
            candidate = UUID()
        }
        return candidate
    }

    private func copiedName(_ name: String) -> String {
        let suffix = NSLocalizedString(" Copy", comment: "Imported profile collision name suffix")
        let allowedBaseCount = max(1, 80 - suffix.count)
        return String(name.prefix(allowedBaseCount)) + suffix
    }
}
