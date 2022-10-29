//
//  Packet.swift
//
//  Created by Tewodros Wondimu on 10/17/22.
//

import Foundation

struct Action: Codable {
    var actionToTake: ActionType
    var time: String?
    var data: Data?
    var peer: String?
    
    init(actionToTake: ActionType, time: String?=nil, data: Data?=nil, peer: String?=nil) {
        self.actionToTake = actionToTake
        self.time = time
        self.data = data
        self.peer = peer
    }
    
    /// Returns a JSON data object
    func getData() -> Data? {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(self) else { return nil }
        return data
    }
    
    static func getObject(fromData data: Data?) -> Self? {
        let decoder = JSONDecoder()
        guard let action = try? decoder.decode(Action.self, from: data!) else { return nil }
        return action
    }
}
