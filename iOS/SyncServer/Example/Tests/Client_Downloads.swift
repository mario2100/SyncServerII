//
//  Client_Downloads.swift
//  SyncServer
//
//  Created by Christopher Prince on 2/23/17.
//  Copyright © 2017 CocoaPods. All rights reserved.
//

import XCTest
@testable import SyncServer
import SMCoreLib

class Client_Downloads: TestCase {
    
    override func setUp() {
        super.setUp()
        DownloadFileTracker.removeAll()
        DirectoryEntry.removeAll()
        removeAllServerFilesInFileIndex()
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func checkForDownloads(expectedMasterVersion:MasterVersionInt, expectedFiles:[ServerAPI.File]) {
        
        let expectation = self.expectation(description: "check")

        Download.session.check() { error in
            XCTAssert(error == nil)
            
            XCTAssert(MasterVersion.get().version == expectedMasterVersion)

            let dfts = DownloadFileTracker.fetchAll()
            let entries = DirectoryEntry.fetchAll()

            XCTAssert(dfts.count == expectedFiles.count)
            XCTAssert(entries.count == expectedFiles.count)

            for file in expectedFiles {
                let dftsResult = dfts.filter { $0.fileUUID == file.fileUUID &&
                    $0.fileVersion == file.fileVersion
                }
                XCTAssert(dftsResult.count == 1)

                let entriesResult = entries.filter { $0.fileUUID == file.fileUUID &&
                    $0.fileVersion == file.fileVersion
                }
                XCTAssert(entriesResult.count == 1)
            }
            
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 30.0, handler: nil)
    }
    
    func testCheckForDownloadOfZeroFilesWorks() {
        let masterVersion = getMasterVersion()
        checkForDownloads(expectedMasterVersion: masterVersion, expectedFiles: [])
    }
    
    func testCheckForDownloadOfSingleFileWorks() {
        let masterVersion = getMasterVersion()
        
        let fileUUID = UUID().uuidString
        
        guard let (_, file) = uploadFile(fileName: "UploadMe", fileExtension: "txt", mimeType: "text/plain", fileUUID: fileUUID, serverMasterVersion: masterVersion) else {
            return
        }
        
        doneUploads(masterVersion: masterVersion, expectedNumberUploads: 1)
        
        checkForDownloads(expectedMasterVersion: masterVersion + 1, expectedFiles: [file])
    }
    
    func testCheckForDownloadOfTwoFilesWorks() {
        let masterVersion = getMasterVersion()
        
        let fileUUID1 = UUID().uuidString
        let fileUUID2 = UUID().uuidString

        guard let (_, file1) = uploadFile(fileName: "UploadMe", fileExtension: "txt", mimeType: "text/plain", fileUUID: fileUUID1, serverMasterVersion: masterVersion) else {
            return
        }
        
        guard let (_, file2) = uploadFile(fileName: "UploadMe", fileExtension: "txt", mimeType: "text/plain", fileUUID: fileUUID2, serverMasterVersion: masterVersion) else {
            return
        }
        
        doneUploads(masterVersion: masterVersion, expectedNumberUploads: 2)
        
        checkForDownloads(expectedMasterVersion: masterVersion + 1, expectedFiles: [file1, file2])
    }
    
    func testDownloadNextWithNoFilesOnServer() {
        let masterVersion = getMasterVersion()
        checkForDownloads(expectedMasterVersion: masterVersion, expectedFiles: [])
    
        let result = Download.session.next() { completionResult in
            XCTFail()
        }
        
        guard case .noDownloads = result else {
            XCTFail()
            return
        }
    }
    
    func testDownloadNextWithOneFileNotDownloadedOnServer() {
        let masterVersion = getMasterVersion()
        
        let fileUUID = UUID().uuidString
        
        guard let (_, file) = uploadFile(fileName: "UploadMe", fileExtension: "txt", mimeType: "text/plain", fileUUID: fileUUID, serverMasterVersion: masterVersion) else {
            return
        }
        
        doneUploads(masterVersion: masterVersion, expectedNumberUploads: 1)
        
        checkForDownloads(expectedMasterVersion: masterVersion + 1, expectedFiles: [file])

        let expectation = self.expectation(description: "next")

        let result = Download.session.next() { completionResult in
            guard case .downloaded = completionResult else {
                XCTFail()
                return
            }
            
            let dfts = DownloadFileTracker.fetchAll()
            XCTAssert(dfts[0].appMetaData == nil)
            XCTAssert(dfts[0].fileVersion == file.fileVersion)
            XCTAssert(dfts[0].status == .downloaded)

            let fileData1 = try? Data(contentsOf: file.localURL)
            let fileData2 = try? Data(contentsOf: dfts[0].localURL! as URL)
            
            XCTAssert(fileData1 != nil)
            XCTAssert(fileData2 != nil)
            XCTAssert(fileData1! == fileData2!)
            XCTAssert(Int64(fileData1!.count) == dfts[0].fileSizeBytes)
            
            expectation.fulfill()
        }
        
        guard case .startedDownload = result else {
            XCTFail()
            return
        }
        
        let dfts = DownloadFileTracker.fetchAll()
        XCTAssert(dfts[0].status == .downloading)
        
        waitForExpectations(timeout: 30.0, handler: nil)
    }
    
    // TODO: *0* Test with masterVersion update.
    
    // TODO: *0* allDownloadsCompleted
    
    // TODO: *0* Try a .next followed by a .next-- the second should indicate that there is a download already occurring.
}
