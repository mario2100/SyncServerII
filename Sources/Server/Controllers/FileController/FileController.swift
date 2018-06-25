//
//  FileController.swift
//  Server
//
//  Created by Christopher Prince on 1/15/17.
//
//

import Foundation
import LoggerAPI
import Credentials
import CredentialsGoogle
import SyncServerShared

class FileController : ControllerProtocol {
    enum CheckError : Error {
        case couldNotConvertModelObject
        case errorLookingUpInFileIndex
    }
    
    // Result is nil if there is no existing file in the FileIndex. Throws an error if there is an error.
    static func checkForExistingFile(params:RequestProcessingParameters, sharingGroupId: SharingGroupId, fileUUID: String) throws -> FileIndex? {
        
        let key = FileIndexRepository.LookupKey.primaryKeys(sharingGroupId: sharingGroupId, fileUUID: fileUUID)

        let lookupResult = params.repos.fileIndex.lookup(key: key, modelInit: FileIndex.init)

        switch lookupResult {
        case .found(let modelObj):
            guard let fileIndexObj = modelObj as? FileIndex else {
                Log.error("Could not convert model object to FileIndex")
                throw CheckError.couldNotConvertModelObject
            }
            
            return fileIndexObj
            
        case .noObjectFound:
            return nil
            
        case .error(let error):
            Log.error("Error looking up file in FileIndex: \(error)")
            throw CheckError.errorLookingUpInFileIndex
        }
    }
    
    // Don't do this setup in init so that database initalizations don't have to be done per endpoint call.
    class func setup(db:Database) -> Bool {
        if case .failure(_) = UploadRepository(db).upcreate() {
            return false
        }
        
        if case .failure(_) = FileIndexRepository(db).upcreate() {
            return false
        }
        
        if case .failure(_) = LockRepository(db).upcreate() {
            return false
        }
        
        return true
    }
    
    init() {
    }
    
    enum GetMasterVersionError : Error {
    case error(String)
    case noObjectFound
    }
    
    // Synchronous callback.
    // Get the master version for a sharing group because the master version reflects the overall version of the data for a sharing group.
    func getMasterVersion(sharingGroupId: SharingGroupId, params:RequestProcessingParameters, completion:(Error?, MasterVersionInt?)->()) {
        
        let key = MasterVersionRepository.LookupKey.sharingGroupId(sharingGroupId)
        let result = params.repos.masterVersion.lookup(key: key, modelInit: MasterVersion.init)
        
        switch result {
        case .error(let error):
            completion(GetMasterVersionError.error(error), nil)
            
        case .found(let model):
            let masterVersionObj = model as! MasterVersion
            completion(nil, masterVersionObj.masterVersion)
            
        case .noObjectFound:
            let errorMessage = "Master version record not found for: \(key)"
            Log.error(errorMessage)
            completion(GetMasterVersionError.noObjectFound, nil)
        }
    }
    
    // OWNER
    func getCreds(forUserId userId: UserId, from db: Database) -> Account? {
        let userKey = UserRepository.LookupKey.userId(userId)
        let userResults = UserRepository(db).lookup(key: userKey, modelInit: User.init)
        guard case .found(let model) = userResults,
            let user = model as? User else {
            Log.error("Could not get user from database.")
            return nil
        }
    
        guard let creds = user.credsObject else {
            Log.error("Could not get user creds.")
            return nil
        }
        
        return creds
    }
            
    func fileIndex(params:RequestProcessingParameters) {
        guard let fileIndexRequest = params.request as? FileIndexRequest else {
            Log.error("Did not receive FileIndexRequest")
            params.completion(nil)
            return
        }
        
        guard sharingGroupSecurityCheck(sharingGroupId: fileIndexRequest.sharingGroupId, params: params) else {
            Log.error("Failed in sharing group security check.")
            params.completion(nil)
            return
        }

#if DEBUG
        if fileIndexRequest.testServerSleep != nil {
            Log.info("Starting sleep (testServerSleep= \(fileIndexRequest.testServerSleep!)).")
            Thread.sleep(forTimeInterval: TimeInterval(fileIndexRequest.testServerSleep!))
            Log.info("Finished sleep (testServerSleep= \(fileIndexRequest.testServerSleep!)).")
        }
#endif
        
        getMasterVersion(sharingGroupId: fileIndexRequest.sharingGroupId, params: params) { (error, masterVersion) in
            if error != nil {
                params.completion(nil)
                return
            }
            
            // Get the file index for the sharing group.
            let fileIndexResult = params.repos.fileIndex.fileIndex(forSharingGroupId: fileIndexRequest.sharingGroupId)

            switch fileIndexResult {
            case .fileIndex(let fileIndex):
                Log.info("Number of entries in FileIndex: \(fileIndex.count)")
                let response = FileIndexResponse()!
                response.fileIndex = fileIndex
                response.masterVersion = masterVersion
                params.completion(response)
                
            case .error(let error):
                Log.error("Error: \(error)")
                params.completion(nil)
                return
            }
        }
    }
    
    func getUploads(params:RequestProcessingParameters) {
        guard params.request is GetUploadsRequest else {
            Log.error("Did not receive GetUploadsRequest")
            params.completion(nil)
            return
        }
        
        let uploadsResult = params.repos.upload.uploadedFiles(forUserId: params.currentSignedInUser!.userId, deviceUUID: params.deviceUUID!)

        switch uploadsResult {
        case .uploads(let uploads):
            let fileInfo = UploadRepository.uploadsToFileInfo(uploads: uploads)
            let response = GetUploadsResponse()!
            response.uploads = fileInfo
            params.completion(response)
            
        case .error(let error):
            Log.error("Error: \(error)")
            params.completion(nil)
            return
        }
    }
}
