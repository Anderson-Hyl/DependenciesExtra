import Dependencies
import DependenciesMacros
import Foundation
import ZIPFoundation

public enum FileSystemError: Error, Sendable {
    case cloudDocsContainerNotFound
    case documentsDirUnreadable
    case deleteFileFailed
    case directoryExisted
    case zipFailed(Error)
}

//private let ICLOUD_SYNCING_IMAGE_NAME = "arrow.clockwise.icloud"
//private let ICLOUD_SYNCED_IMAGE_NAME = "checkmark.icloud"
//private let ICLOUD_OFFLINE = "icloud.slash"
//private let ICLOUD_SYNC_ERRR = "exclamationmark.icloud"
//
//public enum iCloudSyncStatus: Codable, Equatable {
//    case syncing, synced, offline, error
//
//    public var sfSymbol: String {
//        switch self {
//        case .syncing:
//            return ICLOUD_SYNCING_IMAGE_NAME
//        case .synced:
//            return ICLOUD_SYNCED_IMAGE_NAME
//        case .offline:
//            return ICLOUD_OFFLINE
//        case .error:
//            return ICLOUD_SYNC_ERRR
//        }
//    }
//
//    mutating func startSyncAttempt() {
//        self = .syncing
//    }
//}

public struct FileSystemConfig: Sendable {
    public var tempNamespace: @Sendable () -> String
    public var recentlyDeletedDirName: @Sendable () -> String
    public var allowSoftDelete: @Sendable () -> Bool

    public init(
        tempNamespace: @Sendable @escaping @autoclosure () -> String,
        recentlyDeletedDirName: @Sendable @escaping @autoclosure () -> String,
        allowSoftDelete: @Sendable @escaping @autoclosure () -> Bool
    ) {
        self.tempNamespace = tempNamespace
        self.recentlyDeletedDirName = recentlyDeletedDirName
        self.allowSoftDelete = allowSoftDelete
    }
}

extension FileSystemConfig: DependencyKey {
    public static let liveValue = FileSystemConfig(
        tempNamespace: "app",
        recentlyDeletedDirName: "recentlyDeletedDirName",
        allowSoftDelete: true
    )
    public static let testValue = FileSystemConfig(
        tempNamespace: "app.test",
        recentlyDeletedDirName: "test.recentlyDeletedDirName",
        allowSoftDelete: true
    )
    public static let previewValue = FileSystemConfig(
        tempNamespace: "app.preview",
        recentlyDeletedDirName: "preview.recentlyDeletedDirName",
        allowSoftDelete: true
    )
}

extension DependencyValues {
    public var fileSystemConfig: FileSystemConfig {
        get { self[FileSystemConfig.self] }
        set { self[FileSystemConfig.self] = newValue }
    }
}

public struct FileSystemClient: Sendable {
    public var documentsURL: @Sendable () throws -> URL
    public var tempDirectory: @Sendable () -> URL
    public var cloudEnabled: @Sendable () -> Bool

    // File ops
    public var readDirectory: @Sendable (_ url: URL) throws -> [URL]
    public var createDirectory:
        @Sendable (_ url: URL, _ withIntermediates: Bool) throws -> Void
    public var removeItem: @Sendable (_ url: URL) throws -> Void
    public var moveItem: @Sendable (_ from: URL, _ to: URL) throws -> Void
    public var zip: @Sendable (_ from: URL, _ to: URL) throws -> Void
}

extension FileSystemClient: DependencyKey {
    public static let liveValue: FileSystemClient = {
        @Dependency(\.fileSystemConfig) var config
        
        @Sendable func getCloudKitRootURL() throws -> URL {
            guard let url = FileManager.default.url(forUbiquityContainerIdentifier: nil) else {
                throw FileSystemError.cloudDocsContainerNotFound
            }
            return url
        }
                
        @Sendable func getLocalDocumentURL() -> URL {
             let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
             return paths[0]
        }
        
        return FileSystemClient(
            documentsURL: {
                try getCloudKitRootURL()
            },
            tempDirectory: {
                URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
                    .appendingPathComponent(config.tempNamespace(), isDirectory: true)
            },
            cloudEnabled: {
                do {
                    _ = try getCloudKitRootURL()
                    return true
                } catch {
                    return false
                }
            },
            readDirectory: { url in
                try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
            },
            createDirectory: { url, intermediate in
                guard !FileManager.default.fileExists(atPath: url.relativePath) else {
                    throw FileSystemError.directoryExisted
                }
                try FileManager.default.createDirectory(
                    at: url,
                    withIntermediateDirectories: intermediate,
                    attributes: nil
                )
            },
            removeItem: { url in
                do {
                    try FileManager.default.removeItem(at: url)
                } catch {
                    throw FileSystemError.deleteFileFailed
                }
            },
            moveItem: { from, to in
                try FileManager.default.moveItem(at: from, to: to)
            },
            zip: { from, to in
                try FileManager.default.zipItem(at: from, to: to)
            }
        )
    }()
}
