//
//  SharingGroupsControllerTests.swift
//  ServerTests
//
//  Created by Christopher G Prince on 7/15/18.
//

import XCTest
@testable import Server
import LoggerAPI
import Foundation
import SyncServerShared

class SharingGroupsControllerTests: ServerTestCase, LinuxTestable {
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testCreateSharingGroupWorks() {
        let deviceUUID = Foundation.UUID().uuidString
        guard let _ = self.addNewUser(deviceUUID:deviceUUID) else {
            XCTFail()
            return
        }
        
        let sharingGroup = SyncServerShared.SharingGroup()!
        sharingGroup.sharingGroupName = "Louisiana Guys"
        
        guard let sharingGroupId2 = createSharingGroup(deviceUUID:deviceUUID, sharingGroup: sharingGroup) else {
            XCTFail()
            return
        }
        
        guard let (_, sharingGroups) = getIndex() else {
            XCTFail()
            return
        }
        
        let filtered = sharingGroups.filter {$0.sharingGroupId == sharingGroupId2}
        guard filtered.count == 1 else {
            XCTFail()
            return
        }
        
        XCTAssert(filtered[0].sharingGroupName == sharingGroup.sharingGroupName)
    }
    
    func testThatNonOwningUserCannotCreateASharingGroup() {
        let deviceUUID = Foundation.UUID().uuidString
        
        guard let addUserResponse = self.addNewUser(deviceUUID:deviceUUID),
            let sharingGroupId = addUserResponse.sharingGroupId else {
            XCTFail()
            return
        }
        
        var sharingInvitationUUID:String!
        
        createSharingInvitation(permission: .read, sharingGroupId:sharingGroupId) { expectation, invitationUUID in
            sharingInvitationUUID = invitationUUID
            expectation.fulfill()
        }
        
        let testAccount:TestAccount = .nonOwningSharingAccount
        redeemSharingInvitation(sharingUser: testAccount, sharingInvitationUUID: sharingInvitationUUID) { _, expectation in
            expectation.fulfill()
        }
        
        let deviceUUID2 = Foundation.UUID().uuidString
        createSharingGroup(testAccount: testAccount, deviceUUID:deviceUUID2, errorExpected: true)
    }
    
    func testNewlyCreatedSharingGroupHasNoFiles() {
        let deviceUUID = Foundation.UUID().uuidString
        guard let _ = self.addNewUser(deviceUUID:deviceUUID) else {
            XCTFail()
            return
        }
        
        let sharingGroup = SyncServerShared.SharingGroup()!
        sharingGroup.sharingGroupName = "Louisiana Guys"
        
        guard let sharingGroupId = createSharingGroup(deviceUUID:deviceUUID, sharingGroup: sharingGroup) else {
            XCTFail()
            return
        }
        
        guard let (files, sharingGroups) = getIndex(sharingGroupId: sharingGroupId) else {
            XCTFail()
            return
        }
        
        guard files != nil && files?.count == 0 else {
            XCTFail()
            return
        }
        
        guard sharingGroups.count == 2 else {
            XCTFail()
            return
        }
        
        sharingGroups.forEach { sharingGroup in
            guard let deleted = sharingGroup.deleted else {
                XCTFail()
                return
            }
            XCTAssert(!deleted)
            XCTAssert(sharingGroup.permission == .admin)
            XCTAssert(sharingGroup.masterVersion == 0)
        }
        
        let filtered = sharingGroups.filter {$0.sharingGroupId == sharingGroupId}
        guard filtered.count == 1 else {
            XCTFail()
            return
        }
        
        XCTAssert(filtered[0].sharingGroupName == sharingGroup.sharingGroupName)
        
        guard let users = filtered[0].sharingGroupUsers, users.count == 1, users[0].name != nil, users[0].name.count > 0 else {
            XCTFail()
            return
        }
    }
    
    func testUpdateSharingGroupWorks() {
        let deviceUUID = Foundation.UUID().uuidString
        guard let addUserResponse = self.addNewUser(deviceUUID:deviceUUID),
            let sharingGroupId = addUserResponse.sharingGroupId else {
            XCTFail()
            return
        }
        
        guard let masterVersion = getMasterVersion(sharingGroupId: sharingGroupId) else {
            XCTFail()
            return
        }
        
        let sharingGroup = SyncServerShared.SharingGroup()!
        sharingGroup.sharingGroupId = sharingGroupId
        sharingGroup.sharingGroupName = "Louisiana Guys"
        
        guard updateSharingGroup(deviceUUID:deviceUUID, sharingGroup: sharingGroup, masterVersion: masterVersion) else {
            XCTFail()
            return
        }
    }
    
    func testUpdateSharingGroupWithBadMasterVersionFails() {
        let deviceUUID = Foundation.UUID().uuidString
        guard let addUserResponse = self.addNewUser(deviceUUID:deviceUUID),
            let sharingGroupId = addUserResponse.sharingGroupId else {
            XCTFail()
            return
        }
        
        guard let masterVersion = getMasterVersion(sharingGroupId: sharingGroupId) else {
            XCTFail()
            return
        }
        
        let sharingGroup = SyncServerShared.SharingGroup()!
        sharingGroup.sharingGroupId = sharingGroupId
        sharingGroup.sharingGroupName = "Louisiana Guys"
        
        updateSharingGroup(deviceUUID:deviceUUID, sharingGroup: sharingGroup, masterVersion: masterVersion+1, expectMasterVersionUpdate: true)
    }
    
    // MARK: Remove sharing groups
    
    func testRemoveSharingGroupWorks() {
        let deviceUUID = Foundation.UUID().uuidString
        guard let addUserResponse = self.addNewUser(deviceUUID:deviceUUID),
            let sharingGroupId = addUserResponse.sharingGroupId else {
            XCTFail()
            return
        }
        
        guard let masterVersion = getMasterVersion(sharingGroupId: sharingGroupId) else {
            XCTFail()
            return
        }
        
        guard removeSharingGroup(deviceUUID:deviceUUID, sharingGroupId: sharingGroupId, masterVersion: masterVersion) else {
            XCTFail()
            return
        }
        
        let key1 = SharingGroupRepository.LookupKey.sharingGroupId(sharingGroupId)
        let result1 = SharingGroupRepository(db).lookup(key: key1, modelInit: SharingGroup.init)
        guard case .found(let model) = result1, let sharingGroup = model as? Server.SharingGroup else {
            XCTFail()
            return
        }
        
        guard sharingGroup.deleted else {
            XCTFail()
            return
        }
        
        guard let count = SharingGroupUserRepository(db).count(), count == 0 else {
            XCTFail()
            return
        }
    }
    
    func testRemoveSharingGroupWorks_filesMarkedAsDeleted() {
        let deviceUUID = Foundation.UUID().uuidString
        guard let uploadResult = uploadTextFile(deviceUUID:deviceUUID), let sharingGroupId = uploadResult.sharingGroupId else {
            XCTFail()
            return
        }
        
        self.sendDoneUploads(expectedNumberOfUploads: 1, deviceUUID:deviceUUID, sharingGroupId: sharingGroupId)
        
        guard let masterVersion = getMasterVersion(sharingGroupId: sharingGroupId) else {
            XCTFail()
            return
        }

        guard removeSharingGroup(deviceUUID:deviceUUID, sharingGroupId: sharingGroupId, masterVersion: masterVersion) else {
            XCTFail()
            return
        }
        
        // Can't do a file index because no one is left in the sharing group. So, just look up in the db directly.
        
        let key = FileIndexRepository.LookupKey.sharingGroupId(sharingGroupId: sharingGroupId)
        let result = FileIndexRepository(db).lookup(key: key, modelInit: FileIndex.init)
        switch result {
        case .noObjectFound:
            XCTFail()
        case .error:
            XCTFail()
        case .found(let model):
            let file = model as! FileIndex
            XCTAssert(file.deleted)
        }
    }
    
    func testRemoveSharingGroupWorks_multipleUsersRemovedFromSharingGroup() {
        let deviceUUID = Foundation.UUID().uuidString
        guard let addUserResponse = self.addNewUser(deviceUUID:deviceUUID),
            let sharingGroupId = addUserResponse.sharingGroupId else {
            XCTFail()
            return
        }

        var sharingInvitationUUID:String!
        createSharingInvitation(permission: .read, sharingGroupId:sharingGroupId) { expectation, invitationUUID in
            sharingInvitationUUID = invitationUUID
            expectation.fulfill()
        }
        
        let sharingUser: TestAccount = .secondaryOwningAccount
        
        redeemSharingInvitation(sharingUser:sharingUser, sharingInvitationUUID: sharingInvitationUUID) { result, expectation in
            expectation.fulfill()
        }
        
        guard let masterVersion = getMasterVersion(sharingGroupId: sharingGroupId) else {
            XCTFail()
            return
        }
        
        guard removeSharingGroup(deviceUUID:deviceUUID, sharingGroupId: sharingGroupId, masterVersion: masterVersion) else {
            XCTFail()
            return
        }
        
        guard let count = SharingGroupUserRepository(db).count(), count == 0 else {
            XCTFail()
            return
        }
    }
    
    func testRemoveSharingGroupWorks_cannotThenInviteSomeoneToThatGroup() {
        let deviceUUID = Foundation.UUID().uuidString
        guard let addUserResponse = self.addNewUser(deviceUUID:deviceUUID),
            let sharingGroupId = addUserResponse.sharingGroupId else {
            XCTFail()
            return
        }
        
        guard let masterVersion = getMasterVersion(sharingGroupId: sharingGroupId) else {
            XCTFail()
            return
        }
        
        guard removeSharingGroup(deviceUUID:deviceUUID, sharingGroupId: sharingGroupId, masterVersion: masterVersion) else {
            XCTFail()
            return
        }
        
        createSharingInvitation(permission: .read, sharingGroupId:sharingGroupId, errorExpected: true) { expectation, _ in
            expectation.fulfill()
        }
    }
    
    func testRemoveSharingGroupWorks_cannotThenUploadFileToThatSharingGroup() {
        let deviceUUID = Foundation.UUID().uuidString
        guard let addUserResponse = self.addNewUser(deviceUUID:deviceUUID),
            let sharingGroupId = addUserResponse.sharingGroupId else {
            XCTFail()
            return
        }
        
        guard let masterVersion = getMasterVersion(sharingGroupId: sharingGroupId) else {
            XCTFail()
            return
        }
        
        guard removeSharingGroup(deviceUUID:deviceUUID, sharingGroupId: sharingGroupId, masterVersion: masterVersion) else {
            XCTFail()
            return
        }
        
        uploadTextFile(deviceUUID:deviceUUID, addUser: .no(sharingGroupId: sharingGroupId), masterVersion:masterVersion+1, errorExpected:true)
    }
    
    func testRemoveSharingGroupWorks_cannotThenDoDoneUploads() {
        let deviceUUID = Foundation.UUID().uuidString
        guard let addUserResponse = self.addNewUser(deviceUUID:deviceUUID),
            let sharingGroupId = addUserResponse.sharingGroupId else {
            XCTFail()
            return
        }
        
        guard let masterVersion = getMasterVersion(sharingGroupId: sharingGroupId) else {
            XCTFail()
            return
        }
        
        guard removeSharingGroup(deviceUUID:deviceUUID, sharingGroupId: sharingGroupId, masterVersion: masterVersion) else {
            XCTFail()
            return
        }
        
        self.sendDoneUploads(expectedNumberOfUploads: 0, deviceUUID:deviceUUID, masterVersion: masterVersion+1, sharingGroupId: sharingGroupId, failureExpected: true)
    }
    
    func testRemoveSharingGroupWorks_cannotDeleteFile() {
        let deviceUUID = Foundation.UUID().uuidString
        guard let uploadResult = uploadTextFile(deviceUUID:deviceUUID), let sharingGroupId = uploadResult.sharingGroupId else {
            XCTFail()
            return
        }
        
        self.sendDoneUploads(expectedNumberOfUploads: 1, deviceUUID:deviceUUID, sharingGroupId: sharingGroupId)
        
        guard let masterVersion = getMasterVersion(sharingGroupId: sharingGroupId) else {
            XCTFail()
            return
        }
        
        guard removeSharingGroup(deviceUUID:deviceUUID, sharingGroupId: sharingGroupId, masterVersion: masterVersion) else {
            XCTFail()
            return
        }

        let uploadDeletionRequest = UploadDeletionRequest(json: [
            UploadDeletionRequest.fileUUIDKey: uploadResult.request.fileUUID,
            UploadDeletionRequest.fileVersionKey: uploadResult.request.fileVersion,
            UploadDeletionRequest.masterVersionKey: masterVersion + 1,
            ServerEndpoint.sharingGroupIdKey: sharingGroupId
        ])!
        
        uploadDeletion(uploadDeletionRequest: uploadDeletionRequest, deviceUUID: deviceUUID, addUser: false, expectError: true)
    }
    
    func testRemoveSharingGroupWorks_uploadAppMetaDataFails() {
        let deviceUUID = Foundation.UUID().uuidString
        guard let uploadResult = uploadTextFile(deviceUUID:deviceUUID), let sharingGroupId = uploadResult.sharingGroupId else {
            XCTFail()
            return
        }
        
        self.sendDoneUploads(expectedNumberOfUploads: 1, deviceUUID:deviceUUID, sharingGroupId: sharingGroupId)
        
        guard let masterVersion = getMasterVersion(sharingGroupId: sharingGroupId) else {
            XCTFail()
            return
        }
        
        guard removeSharingGroup(deviceUUID:deviceUUID, sharingGroupId: sharingGroupId, masterVersion: masterVersion) else {
            XCTFail()
            return
        }

        let appMetaData = AppMetaData(version: 0, contents: "Foo")

        uploadAppMetaDataVersion(deviceUUID: deviceUUID, fileUUID: uploadResult.request.fileUUID, masterVersion:masterVersion+1, appMetaData: appMetaData, sharingGroupId:sharingGroupId, expectedError: true)
    }
    
    func testRemoveSharingGroupWorks_downloadAppMetaDataFails() {
        let deviceUUID = Foundation.UUID().uuidString
        let appMetaData = AppMetaData(version: 0, contents: "Foo")
        guard let uploadResult = uploadTextFile(deviceUUID:deviceUUID, appMetaData: appMetaData), let sharingGroupId = uploadResult.sharingGroupId else {
            XCTFail()
            return
        }
        
        self.sendDoneUploads(expectedNumberOfUploads: 1, deviceUUID:deviceUUID, sharingGroupId: sharingGroupId)
        
        guard let masterVersion = getMasterVersion(sharingGroupId: sharingGroupId) else {
            XCTFail()
            return
        }
        
        guard removeSharingGroup(deviceUUID:deviceUUID, sharingGroupId: sharingGroupId, masterVersion: masterVersion) else {
            XCTFail()
            return
        }

        downloadAppMetaDataVersion(deviceUUID: deviceUUID, fileUUID: uploadResult.request.fileUUID, masterVersionExpectedWithDownload:masterVersion + 1, appMetaDataVersion: 0, sharingGroupId: sharingGroupId, expectedError: true)
    }
    
    func testRemoveSharingGroupWorks_downloadFileFails() {
        let deviceUUID = Foundation.UUID().uuidString
        guard let uploadResult = uploadTextFile(deviceUUID:deviceUUID), let sharingGroupId = uploadResult.sharingGroupId else {
            XCTFail()
            return
        }
        
        self.sendDoneUploads(expectedNumberOfUploads: 1, deviceUUID:deviceUUID, sharingGroupId: sharingGroupId)
        
        guard let masterVersion = getMasterVersion(sharingGroupId: sharingGroupId) else {
            XCTFail()
            return
        }
        
        guard removeSharingGroup(deviceUUID:deviceUUID, sharingGroupId: sharingGroupId, masterVersion: masterVersion) else {
            XCTFail()
            return
        }
        
        downloadTextFile(masterVersionExpectedWithDownload:Int(masterVersion+1),  downloadFileVersion:0, uploadFileRequest:uploadResult.request, fileSize: 12, expectedError: true)
    }
    
    func testRemoveSharingGroup_failsWithBadMasterVersion() {
        let deviceUUID = Foundation.UUID().uuidString
        guard let addUserResponse = self.addNewUser(deviceUUID:deviceUUID),
            let sharingGroupId = addUserResponse.sharingGroupId else {
            XCTFail()
            return
        }
        
        guard let masterVersion = getMasterVersion(sharingGroupId: sharingGroupId) else {
            XCTFail()
            return
        }
        
        guard !removeSharingGroup(deviceUUID:deviceUUID, sharingGroupId: sharingGroupId, masterVersion: masterVersion+1) else {
            XCTFail()
            return
        }
    }

    func testUpdateSharingGroupForDeletedSharingGroupFails() {
        let deviceUUID = Foundation.UUID().uuidString
        guard let addUserResponse = self.addNewUser(deviceUUID:deviceUUID),
            let sharingGroupId = addUserResponse.sharingGroupId else {
            XCTFail()
            return
        }
        
        guard var masterVersion = getMasterVersion(sharingGroupId: sharingGroupId) else {
            XCTFail()
            return
        }
        
        guard removeSharingGroup(deviceUUID:deviceUUID, sharingGroupId: sharingGroupId, masterVersion: masterVersion) else {
            XCTFail()
            return
        }
        
        masterVersion += 1
        
        let sharingGroup = SyncServerShared.SharingGroup()!
        sharingGroup.sharingGroupId = sharingGroupId
        sharingGroup.sharingGroupName = "Louisiana Guys"
        
        let result = updateSharingGroup(deviceUUID:deviceUUID, sharingGroup: sharingGroup, masterVersion: masterVersion, expectFailure: true)
        XCTAssert(result == false)
    }
    
    // MARK: Remove user from sharing group
    
    func testRemoveUserFromSharingGroup_lastUserInSharingGroup() {
        let deviceUUID = Foundation.UUID().uuidString
        guard let addUserResponse = self.addNewUser(deviceUUID:deviceUUID),
            let sharingGroupId = addUserResponse.sharingGroupId else {
            XCTFail()
            return
        }
        
        guard let masterVersion = getMasterVersion(sharingGroupId: sharingGroupId) else {
            XCTFail()
            return
        }
        
        guard removeUserFromSharingGroup(deviceUUID: deviceUUID, sharingGroupId: sharingGroupId, masterVersion: masterVersion) else {
            XCTFail()
            return
        }
        
        let key1 = SharingGroupRepository.LookupKey.sharingGroupId(sharingGroupId)
        let result1 = SharingGroupRepository(db).lookup(key: key1, modelInit: SharingGroup.init)
        guard case .found(let model) = result1, let sharingGroup = model as? Server.SharingGroup else {
            XCTFail()
            return
        }
        
        guard sharingGroup.deleted else {
            XCTFail()
            return
        }
        
        let key2 = SharingGroupUserRepository.LookupKey.userId(addUserResponse.userId)
        let result2 = SharingGroupUserRepository(db).lookup(key: key2 , modelInit: SharingGroupUser.init)
        guard case .noObjectFound = result2 else {
            XCTFail()
            return
        }
    }
    
    func testRemoveUserFromSharingGroup_notLastUserInSharingGroup() {
        let deviceUUID = Foundation.UUID().uuidString
        guard let addUserResponse = self.addNewUser(deviceUUID:deviceUUID),
            let sharingGroupId = addUserResponse.sharingGroupId else {
            XCTFail()
            return
        }

        var sharingInvitationUUID:String!
        
        createSharingInvitation(permission: .read, sharingGroupId:sharingGroupId) { expectation, invitationUUID in
            sharingInvitationUUID = invitationUUID
            expectation.fulfill()
        }
        
        let sharingUser: TestAccount = .secondaryOwningAccount
        
        redeemSharingInvitation(sharingUser:sharingUser, sharingInvitationUUID: sharingInvitationUUID) { result, expectation in
            expectation.fulfill()
        }
        
        guard let masterVersion = getMasterVersion(sharingGroupId: sharingGroupId) else {
            XCTFail()
            return
        }
        
        guard removeUserFromSharingGroup(deviceUUID: deviceUUID, sharingGroupId: sharingGroupId, masterVersion: masterVersion) else {
            XCTFail()
            return
        }
        
        guard let masterVersion2 = getMasterVersion(testAccount: sharingUser, sharingGroupId: sharingGroupId), masterVersion + 1 == masterVersion2 else {
            XCTFail()
            return
        }
        
        let key1 = SharingGroupRepository.LookupKey.sharingGroupId(sharingGroupId)
        let result1 = SharingGroupRepository(db).lookup(key: key1, modelInit: SharingGroup.init)
        guard case .found(let model) = result1, let sharingGroup = model as? Server.SharingGroup else {
            XCTFail()
            return
        }
        
        // Still one user in sharing group-- should not be deleted.
        guard !sharingGroup.deleted else {
            XCTFail()
            return
        }
        
        let key2 = SharingGroupUserRepository.LookupKey.userId(addUserResponse.userId)
        let result2 = SharingGroupUserRepository(db).lookup(key: key2 , modelInit: SharingGroupUser.init)
        guard case .noObjectFound = result2 else {
            XCTFail()
            return
        }
    }
    
    func testRemoveUserFromSharingGroup_failsWithBadMasterVersion() {
        let deviceUUID = Foundation.UUID().uuidString
        guard let addUserResponse = self.addNewUser(deviceUUID:deviceUUID),
            let sharingGroupId = addUserResponse.sharingGroupId else {
            XCTFail()
            return
        }
        
        guard let masterVersion = getMasterVersion(sharingGroupId: sharingGroupId) else {
            XCTFail()
            return
        }
        
        removeUserFromSharingGroup(deviceUUID: deviceUUID, sharingGroupId: sharingGroupId, masterVersion: masterVersion + 1, expectMasterVersionUpdate: true)
    }
    
    // When user has files in the sharing group-- those should be marked as deleted.
    func testRemoveUserFromSharingGroup_userHasFiles() {
        let deviceUUID = Foundation.UUID().uuidString
        guard let uploadResult = uploadTextFile(deviceUUID:deviceUUID), let sharingGroupId = uploadResult.sharingGroupId else {
            XCTFail()
            return
        }
        
        self.sendDoneUploads(expectedNumberOfUploads: 1, deviceUUID:deviceUUID, sharingGroupId: sharingGroupId)

        // Need a second user as a member of the sharing group so we can do a file index on the sharing group after the first user is removed.
        var sharingInvitationUUID:String!
        createSharingInvitation(permission: .read, sharingGroupId:sharingGroupId) { expectation, invitationUUID in
            sharingInvitationUUID = invitationUUID
            expectation.fulfill()
        }
        
        let sharingUser: TestAccount = .secondaryOwningAccount
        
        redeemSharingInvitation(sharingUser:sharingUser, sharingInvitationUUID: sharingInvitationUUID) { result, expectation in
            expectation.fulfill()
        }
        
        guard let masterVersion = getMasterVersion(sharingGroupId: sharingGroupId) else {
            XCTFail()
            return
        }
        
        guard removeUserFromSharingGroup(deviceUUID: deviceUUID, sharingGroupId: sharingGroupId, masterVersion: masterVersion) else {
            XCTFail()
            return
        }
        
        guard let (files, _) = getIndex(testAccount: sharingUser, sharingGroupId: sharingGroupId) else {
            XCTFail()
            return
        }
        
        let filtered = files!.filter {$0.fileUUID == uploadResult.request.fileUUID}
        guard filtered.count == 1 else {
            XCTFail()
            return
        }
        
        XCTAssert(filtered[0].deleted == true)
    }
    
    // When owning user has sharing users in sharing group: Those should no longer be able to upload to the sharing group.
    func testRemoveUserFromSharingGroup_owningUserHasSharingUsers() {
        let deviceUUID = Foundation.UUID().uuidString
        guard let addUserResponse = self.addNewUser(deviceUUID:deviceUUID),
            let sharingGroupId = addUserResponse.sharingGroupId else {
            XCTFail()
            return
        }
        
        var sharingInvitationUUID:String!
        createSharingInvitation(permission: .write, sharingGroupId:sharingGroupId) { expectation, invitationUUID in
            sharingInvitationUUID = invitationUUID
            expectation.fulfill()
        }
        
        let sharingUser: TestAccount = .nonOwningSharingAccount
        
        redeemSharingInvitation(sharingUser:sharingUser, sharingInvitationUUID: sharingInvitationUUID) { result, expectation in
            expectation.fulfill()
        }
        
        guard let masterVersion = getMasterVersion(sharingGroupId: sharingGroupId) else {
            XCTFail()
            return
        }
        
        guard removeUserFromSharingGroup(deviceUUID: deviceUUID, sharingGroupId: sharingGroupId, masterVersion: masterVersion) else {
            XCTFail()
            return
        }
        
        uploadTextFile(testAccount: sharingUser, deviceUUID:deviceUUID, addUser: .no(sharingGroupId:sharingGroupId), masterVersion: masterVersion + 1, errorExpected: true)
    }
}

extension SharingGroupsControllerTests {
    static var allTests : [(String, (SharingGroupsControllerTests) -> () throws -> Void)] {
        return [
            ("testCreateSharingGroupWorks", testCreateSharingGroupWorks),
            ("testThatNonOwningUserCannotCreateASharingGroup", testThatNonOwningUserCannotCreateASharingGroup),
            ("testNewlyCreatedSharingGroupHasNoFiles", testNewlyCreatedSharingGroupHasNoFiles),
            ("testUpdateSharingGroupWorks", testUpdateSharingGroupWorks),
            ("testUpdateSharingGroupWithBadMasterVersionFails", testUpdateSharingGroupWithBadMasterVersionFails),
            ("testRemoveSharingGroupWorks", testRemoveSharingGroupWorks),
            ("testRemoveSharingGroupWorks_filesMarkedAsDeleted", testRemoveSharingGroupWorks_filesMarkedAsDeleted),
            ("testRemoveSharingGroupWorks_multipleUsersRemovedFromSharingGroup", testRemoveSharingGroupWorks_multipleUsersRemovedFromSharingGroup),
            ("testRemoveSharingGroupWorks_cannotThenInviteSomeoneToThatGroup", testRemoveSharingGroupWorks_cannotThenInviteSomeoneToThatGroup),
            ("testRemoveSharingGroupWorks_cannotThenUploadFileToThatSharingGroup", testRemoveSharingGroupWorks_cannotThenUploadFileToThatSharingGroup),
            ("testRemoveSharingGroupWorks_cannotThenDoDoneUploads", testRemoveSharingGroupWorks_cannotThenDoDoneUploads),
            ("testRemoveSharingGroupWorks_cannotDeleteFile", testRemoveSharingGroupWorks_cannotDeleteFile),
            ("testRemoveSharingGroupWorks_uploadAppMetaDataFails", testRemoveSharingGroupWorks_uploadAppMetaDataFails),
            ("testRemoveSharingGroupWorks_downloadAppMetaDataFails", testRemoveSharingGroupWorks_downloadAppMetaDataFails),
            ("testRemoveSharingGroupWorks_downloadFileFails", testRemoveSharingGroupWorks_downloadFileFails),
            ("testRemoveSharingGroup_failsWithBadMasterVersion", testRemoveSharingGroup_failsWithBadMasterVersion),
            ("testUpdateSharingGroupForDeletedSharingGroupFails", testUpdateSharingGroupForDeletedSharingGroupFails),
            ("testRemoveUserFromSharingGroup_lastUserInSharingGroup", testRemoveUserFromSharingGroup_lastUserInSharingGroup),
            ("testRemoveUserFromSharingGroup_notLastUserInSharingGroup", testRemoveUserFromSharingGroup_notLastUserInSharingGroup),
            ("testRemoveUserFromSharingGroup_failsWithBadMasterVersion",
                testRemoveUserFromSharingGroup_failsWithBadMasterVersion),
            ("testRemoveUserFromSharingGroup_userHasFiles", testRemoveUserFromSharingGroup_userHasFiles),
            ("testRemoveUserFromSharingGroup_owningUserHasSharingUsers", testRemoveUserFromSharingGroup_owningUserHasSharingUsers)
        ]
    }
    
    func testLinuxTestSuiteIncludesAllTests() {
        linuxTestSuiteIncludesAllTests(testType: SharingGroupsControllerTests.self)
    }
}
