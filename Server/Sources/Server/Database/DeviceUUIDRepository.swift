//
//  DeviceUUIDRepository.swift
//  Server
//
//  Created by Christopher Prince on 2/14/17.
//
//

import Foundation

import Foundation
import PerfectLib

class DeviceUUID : NSObject, Model {
    var userId: UserId!
    var deviceUUID: String!

    override init() {
        super.init()
    }
    
    init(userId: UserId, deviceUUID: String) {
        self.userId = userId
        
        // TODO: *2* Validate that this is a good UUID.
        self.deviceUUID = deviceUUID
    }
}

class DeviceUUIDRepository : Repository {
    private(set) var db:Database!
    
    var maximumNumberOfDeviceUUIDsPerUser:Int? = Constants.session.maxNumberDeviceUUIDPerUser
    
    init(_ db:Database) {
        self.db = db
    }
    
    var tableName:String {
        return "DeviceUUID"
    }

    func create() -> Database.TableCreationResult {
        let createColumns =
            // reference into User table
            "(userId BIGINT NOT NULL, " +

            // identifies a specific mobile device (assigned by app)
            "deviceUUID VARCHAR(\(Database.uuidLength)) NOT NULL, " +
            
            "UNIQUE (deviceUUID))"
        
        return db.createTableIfNeeded(tableName: "\(tableName)", columnCreateQuery: createColumns)
    }
    
    enum LookupKey : CustomStringConvertible {
        case userId(UserId)
        case deviceUUID(String)
        
        var description : String {
            switch self {
            case .userId(let userId):
                return "userId(\(userId))"
            case .deviceUUID(let deviceUUID):
                return "deviceUUID(\(deviceUUID))"
            }
        }
    }
    
    func lookupConstraint(key:LookupKey) -> String {
        switch key {
        case .userId(let userId):
            return "userId = '\(userId)'"
        case .deviceUUID(let deviceUUID):
            return "deviceUUID = '\(deviceUUID)'"
        }
    }
    
    enum DeviceUUIDAddResult {
    case error(String)
    case success
    case exceededMaximumUUIDsPerUser
    }
    
    // Adds a record
    // If maximumNumberOfDeviceUUIDsPerUser != nil, makes sure that the number of deviceUUID's per user doesn't exceed maximumNumberOfDeviceUUIDsPerUser
    func add(deviceUUID:DeviceUUID) -> DeviceUUIDAddResult {
        if deviceUUID.userId == nil || deviceUUID.deviceUUID == nil {
            let message = "One of the model values was nil!"
            Log.error(message: message)
            return .error(message)
        }
        
        var query = "INSERT INTO \(tableName) (userId, deviceUUID) "
        
        if maximumNumberOfDeviceUUIDsPerUser == nil {
            query += "VALUES (\(deviceUUID.userId!), '\(deviceUUID.deviceUUID!)')"
        }
        else {
            query +=
        "select \(deviceUUID.userId!), '\(deviceUUID.deviceUUID!)' from Dual where " +
        "(select count(*) from \(tableName) where userId = \(deviceUUID.userId!)) < \(maximumNumberOfDeviceUUIDsPerUser!)"
        }

        if db.connection.query(statement: query) {
            if db.connection.numberAffectedRows() == 1 {
                return .success
            }
            else {
                return .exceededMaximumUUIDsPerUser
            }
        }
        else {
            let message = "Could not insert into \(tableName): \(db.error)"
            Log.error(message: message)
            return .error(message)
        }
    }
}