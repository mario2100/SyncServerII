//
//  ServerRoutes.swift
//  Authentication
//
//  Created by Christopher Prince on 11/26/16.
//
//

import Kitura

// When adding a new controller, you must also add it to the list in Controllers.swift
public class ServerRoutes {
    class func add(proxyRouter:CreateRoutes) {
        let utilController = UtilController()
        proxyRouter.addRoute(ep: ServerEndpoints.healthCheck, createRequest: HealthCheckRequest.init, processRequest: utilController.healthCheck)
#if DEBUG
        proxyRouter.addRoute(ep: ServerEndpoints.checkPrimaryCreds, createRequest: CheckPrimaryCredsRequest.init, processRequest: utilController.checkPrimaryCreds)
#endif

        let userController = UserController()
        proxyRouter.addRoute(ep: ServerEndpoints.addUser, createRequest: AddUserRequest.init, processRequest: userController.addUser)
        proxyRouter.addRoute(ep: ServerEndpoints.checkCreds, createRequest: CheckCredsRequest.init, processRequest: userController.checkCreds)
        proxyRouter.addRoute(ep: ServerEndpoints.removeUser, createRequest: RemoveUserRequest.init, processRequest: userController.removeUser)
        
        let fileController = FileController()
        proxyRouter.addRoute(ep: ServerEndpoints.fileIndex, createRequest: FileIndexRequest.init, processRequest: fileController.fileIndex)
        proxyRouter.addRoute(ep: ServerEndpoints.uploadFile, createRequest: UploadFileRequest.init, processRequest: fileController.uploadFile)
        proxyRouter.addRoute(ep: ServerEndpoints.doneUploads, createRequest: DoneUploadsRequest.init, processRequest: fileController.doneUploads)
        proxyRouter.addRoute(ep: ServerEndpoints.downloadFile, createRequest: DownloadFileRequest.init, processRequest: fileController.downloadFile)
        proxyRouter.addRoute(ep: ServerEndpoints.getUploads, createRequest: GetUploadsRequest.init, processRequest: fileController.getUploads)
        proxyRouter.addRoute(ep: ServerEndpoints.uploadDeletion, createRequest: UploadDeletionRequest.init, processRequest: fileController.uploadDeletion)
        
        let sharingAccountsController = SharingAccountsController()
        proxyRouter.addRoute(ep: ServerEndpoints.createSharingInvitation, createRequest: CreateSharingInvitationRequest.init, processRequest: sharingAccountsController.createSharingInvitation)
        proxyRouter.addRoute(ep: ServerEndpoints.redeemSharingInvitation, createRequest: RedeemSharingInvitationRequest.init, processRequest: sharingAccountsController.redeemSharingInvitation)
    }
}