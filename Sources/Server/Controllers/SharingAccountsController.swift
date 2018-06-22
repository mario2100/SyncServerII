//
//  SharingAccountsController
//  Server
//
//  Created by Christopher Prince on 4/9/17.
//
//

import Credentials
import SyncServerShared
import LoggerAPI

class SharingAccountsController : ControllerProtocol {
    class func setup(db:Database) -> Bool {
        if case .failure(_) = SharingInvitationRepository(db).upcreate() {
            return false
        }
        
        return true
    }
    
    init() {
    }
    
    func createSharingInvitation(params:RequestProcessingParameters) {
        assert(params.ep.authenticationLevel == .secondary)
        assert(params.ep.minPermission == .admin)

        guard let createSharingInvitationRequest = params.request as? CreateSharingInvitationRequest else {
            Log.error("Did not receive CreateSharingInvitationRequest")
            params.completion(nil)
            return
        }
        
        guard let currentSignedInUser = params.currentSignedInUser else {
            Log.error("No currentSignedInUser")
            params.completion(nil)
            return
        }
        
        // 6/20/18; The current user can be a sharing or owning user, and whether or not these users can invite others depends on the permissions they have. See https://github.com/crspybits/SyncServerII/issues/76

        let result = SharingInvitationRepository(params.db).add(
            owningUserId: currentSignedInUser.effectiveOwningUserId,
            permission: createSharingInvitationRequest.permission)
        
        guard case .success(let sharingInvitationUUID) = result else {
            Log.error("Failed to add Sharing Invitation")
            params.completion(nil)
            return
        }
        
        let response = CreateSharingInvitationResponse()!
        response.sharingInvitationUUID = sharingInvitationUUID
        params.completion(response)
    }
    
    func redeemSharingInvitation(params:RequestProcessingParameters) {
        assert(params.ep.authenticationLevel == .primary)

        guard let request = params.request as? RedeemSharingInvitationRequest else {
            Log.error("Did not receive RedeemSharingInvitationRequest")
            params.completion(nil)
            return
        }
        
        let userExists = UserController.userExists(userProfile: params.userProfile!, userRepository: params.repos.user)
        switch userExists {
        case .doesNotExist:
            break
        case .error, .exists(_):
            Log.error("Could not add user: Already exists!")
            params.completion(nil)
            return
        }
        
        // Remove stale invitations.
        let removalKey = SharingInvitationRepository.LookupKey.staleExpiryDates
        let removalResult = SharingInvitationRepository(params.db).remove(key: removalKey)
        
        guard case .removed(_) = removalResult else{
            Log.error("Failed removing stale sharing invitations")
            params.completion(nil)
            return
        }

        // What I want to do at this point is to simultaneously and atomically, (a) lookup the sharing invitation, and (b) delete it. I believe that since (i) I'm using mySQL transactions, and (ii) InnoDb with a default transaction level of REPEATABLE READ, this should work by first doing the lookup, and then doing the delete.
        
        let sharingInvitationKey = SharingInvitationRepository.LookupKey.sharingInvitationUUID(uuid: request.sharingInvitationUUID)
        let lookupResult = SharingInvitationRepository(params.db).lookup(key: sharingInvitationKey, modelInit: SharingInvitation.init)
        
        guard case .found(let model) = lookupResult,
            let sharingInvitation = model as? SharingInvitation else {
            Log.error("Could not find sharing invitation: \(request.sharingInvitationUUID). Was it stale?")
            params.completion(nil)
            return
        }
        
        let removalResult2 = SharingInvitationRepository(params.db).remove(key: sharingInvitationKey)
        guard case .removed(let numberRemoved) = removalResult2, numberRemoved == 1 else {
            Log.error("Failed removing sharing invitation!")
            params.completion(nil)
            return
        }
        
        // All seems good. Let's create the new user.
        
        // No database creds because this is a new user-- so use params.profileCreds
        
        let user = User()
        user.username = params.userProfile!.displayName
        user.accountType = AccountType.for(userProfile: params.userProfile!)
        user.credsId = params.userProfile!.id
        user.creds = params.profileCreds!.toJSON(userType:user.accountType.userType)
        user.permission = sharingInvitation.permission
        
        // When the user is an owning user, they will rely on their own cloud storage to upload new files-- if they have upload permissions.
        if user.accountType.userType == .sharing {
            user.owningUserId = sharingInvitation.owningUserId
        }
        
        let userId = params.repos.user.add(user: user)
        if userId == nil {
            Log.error("Failed on adding sharing user to User!")
            params.completion(nil)
            return
        }
        
        let response = RedeemSharingInvitationResponse()!
        
        // 11/5/17; Up until now I had been calling `generateTokensIfNeeded` for Facebook creds and that had been generating tokens. Somehow, in running my tests today, I'm getting failures from the Facebook API when I try to do this. This may only occur in testing because I'm passing long-lived access tokens. Plus, it's possible this error has gone undiagnosed until now. In testing, there is no need to generate the long-lived access tokens.

        params.profileCreds!.generateTokensIfNeeded(userType: user.accountType.userType, dbCreds: nil, routerResponse: params.routerResponse, success: {
            params.completion(response)
        }, failure: {
            params.completion(nil)
        })
    }
}
