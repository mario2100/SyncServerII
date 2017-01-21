//
//  UploadFile.swift
//  Server
//
//  Created by Christopher Prince on 1/15/17.
//
//

import Foundation
import PerfectLib
import Gloss
import Kitura

class UploadFileRequest : NSObject, RequestMessage {
    var data = Data()
    var sizeOfDataInBytes:Int!
    
    static let fileUUIDKey = "fileUUID"
    var fileUUID:String!
    
    static let mimeTypeKey = "mimeType"
    var mimeType:String!
    
    // A root-level folder in the cloud file service.
    static let cloudFolderNameKey = "cloudFolderName"
    var cloudFolderName:String!
    
    static let deviceUUIDKey = "deviceUUID"
    var deviceUUID:String!
    
    static let versionKey = "version"
    
    // Using a String here because (a) value(forKey: name) doesn't play well with Int's, and (b) because that's how it will arrive in JSON.
    var version:String!
    
    var versionNumber:Int {
        return Int(version)!
    }
    
    func keys() -> [String] {
        return [UploadFileRequest.fileUUIDKey, UploadFileRequest.mimeTypeKey, UploadFileRequest.cloudFolderNameKey, UploadFileRequest.deviceUUIDKey, UploadFileRequest.versionKey]
    }
    
    required init?(json: JSON) {
        super.init()
        
        self.fileUUID = UploadFileRequest.fileUUIDKey <~~ json
        self.mimeType = UploadFileRequest.mimeTypeKey <~~ json
        self.cloudFolderName = UploadFileRequest.cloudFolderNameKey <~~ json
        self.deviceUUID = UploadFileRequest.deviceUUIDKey <~~ json
        self.version = UploadFileRequest.versionKey <~~ json

        if !self.propertiesHaveValues(propertyNames: self.keys()) {
            return nil
        }
        
        guard let _ = NSUUID(uuidString: self.fileUUID),
            let _ = NSUUID(uuidString: self.deviceUUID) else {
            return nil
        }
    }
    
    required convenience init?(request: RouterRequest) {
        self.init(json: request.queryParameters)
        do {
            // TODO: Eventually this needs to be converted into stream processing where a stream from client is passed along to Google Drive or some other cloud service-- so not all of the file has to be read onto the server. For big files this will crash the server.
            self.sizeOfDataInBytes = try request.read(into: &self.data)
        } catch (let error) {
            Log.error(message: "Could not upload file: \(error)")
            return nil
        }
    }
}

class UploadFileResponse : ResponseMessage {
    static let resultKey = "result"
    var result: PerfectLib.JSONConvertible?
    static let sizeKey = "sizeInBytes"
    var size:Int64?
    
    // MARK: - Serialization
    func toJSON() -> JSON? {
        return jsonify([
            UploadFileResponse.resultKey ~~> self.result,
            UploadFileResponse.sizeKey ~~> self.size
        ])
    }
}