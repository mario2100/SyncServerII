//
//  CloudStorage.swift
//  Server
//
//  Created by Christopher G Prince on 12/3/17.
//

import Foundation
import SyncServerShared

enum Result<T> {
    case success(T)
    case failure(Swift.Error)
}

// Some cloud services (e.g., Google Drive) need additional file naming options; other's don't (e.g., Dropbox). If you give these options and the method doesn't need it, they are ignored.
struct CloudStorageFileNameOptions {
    let cloudFolderName:String
    let mimeType:String
}

protocol CloudStorage {
    // On success, Int in result gives file size in bytes on server.
    func uploadFile(cloudFileName:String, data:Data, options:CloudStorageFileNameOptions?,
        completion:@escaping (Result<Int>)->())
    
    func downloadFile(cloudFileName:String, options:CloudStorageFileNameOptions?, completion:@escaping (Result<Data>)->())
    
    func deleteFile(cloudFileName:String, options:CloudStorageFileNameOptions?,
        completion:@escaping (Swift.Error?)->())

    // On success, returns true iff the file was found.
    // Used primarily for testing.
    func lookupFile(cloudFileName:String, options:CloudStorageFileNameOptions?,
        completion:@escaping (Result<Bool>)->())
}