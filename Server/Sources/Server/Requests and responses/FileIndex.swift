//
//  FileIndex.swift
//  Server
//
//  Created by Christopher Prince on 1/28/17.
//
//

import Foundation
import Gloss

#if SERVER
import Kitura
#endif

// Request an index of all files that have been uploaded with UploadFile and committed using DoneUploads by the user-- queries the meta data on the sync server.

class FileIndexRequest : NSObject, RequestMessage {
    // MARK: Properties for use in request message.
    
    func nonNilKeys() -> [String] {
        return []
    }
    
    func allKeys() -> [String] {
        return self.nonNilKeys()
    }
    
    required init?(json: JSON) {
        super.init()
        
#if SERVER
        if !self.propertiesHaveValues(propertyNames: self.nonNilKeys()) {
            return nil
        }
#endif
    }
    
#if SERVER
    required convenience init?(request: RouterRequest) {
        self.init(json: request.queryParameters)
    }
#endif

    func toJSON() -> JSON? {
        return jsonify([
        ])
    }
}

public class FileInfo : Encodable, Decodable, CustomStringConvertible {
    static let fileUUIDKey = "fileUUID"
    var fileUUID: String!
    
    static let mimeTypeKey = "mimeType"
    var mimeType: String!
    
    static let appMetaDataKey = "appMetaData"
    var appMetaData: String?
    
    static let deletedKey = "deleted"
    var deleted:Bool!
    
    static let fileVersionKey = "fileVersion"
    var fileVersion: FileVersionInt!
    
    static let fileSizeBytesKey = "fileSizeBytes"
    var fileSizeBytes: Int64!
    
    public var description: String {
        return "fileUUID: \(fileUUID!); mimeTypeKey: \(mimeType!); appMetaData: \(appMetaData); deleted: \(deleted!); fileVersion: \(fileVersion!); fileSizeBytes: \(fileSizeBytes!)"
    }
    
    required public init?(json: JSON) {
        self.fileUUID = FileInfo.fileUUIDKey <~~ json
        self.mimeType = FileInfo.mimeTypeKey <~~ json
        self.appMetaData = FileInfo.appMetaDataKey <~~ json
        self.deleted = FileInfo.deletedKey <~~ json
        self.fileVersion = FileInfo.fileVersionKey <~~ json
        self.fileSizeBytes = FileInfo.fileSizeBytesKey <~~ json
    }
    
    convenience init?() {
        self.init(json:[:])
    }
    
    public func toJSON() -> JSON? {
        return jsonify([
            FileInfo.fileUUIDKey ~~> self.fileUUID,
            FileInfo.mimeTypeKey ~~> self.mimeType,
            FileInfo.appMetaDataKey ~~> self.appMetaData,
            FileInfo.deletedKey ~~> self.deleted,
            FileInfo.fileVersionKey ~~> self.fileVersion,
            FileInfo.fileSizeBytesKey ~~> self.fileSizeBytes
        ])
    }
}

class FileIndexResponse : ResponseMessage {
    public var responseType: ResponseType {
        return .json
    }
    
    static let masterVersionKey = "masterVersion"
    var masterVersion:MasterVersionInt!
    
    static let fileIndexKey = "fileIndex"
    var fileIndex:[FileInfo]?
    
    required init?(json: JSON) {
        self.masterVersion = FileIndexResponse.masterVersionKey <~~ json
        self.fileIndex = FileIndexResponse.fileIndexKey <~~ json
    }
    
    convenience init?() {
        self.init(json:[:])
    }
    
    // MARK: - Serialization
    func toJSON() -> JSON? {
        return jsonify([
            FileIndexResponse.masterVersionKey ~~> self.masterVersion,
            FileIndexResponse.fileIndexKey ~~> self.fileIndex
        ])
    }
}