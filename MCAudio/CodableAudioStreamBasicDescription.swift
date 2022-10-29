//
//  AudioStreamBasicDescriptionExtension.swift
//
//  Created by Tewodros Wondimu on 10/19/22.
//

import Foundation
import AVFoundation

struct CodableAudioStreamBasicDescription: Codable {
    var mBitsPerChannel: UInt32
    var mBytesPerFrame: UInt32
    var mBytesPerPacket: UInt32
    var mChannelsPerFrame: UInt32
    var mFormatFlags: AudioFormatFlags
    var mFormatID: AudioFormatID
    var mFramesPerPacket: UInt32
    var mReserved: UInt32
    var mSampleRate: Float64
    
    init(withASBD description: AudioStreamBasicDescription) {
        self.mBitsPerChannel = description.mBitsPerChannel
        self.mBytesPerFrame = description.mBytesPerFrame
        self.mBytesPerPacket = description.mBytesPerPacket
        self.mChannelsPerFrame = description.mChannelsPerFrame
        self.mFormatFlags = description.mFormatFlags
        self.mFormatID = description.mFormatID
        self.mFramesPerPacket = description.mFramesPerPacket
        self.mReserved = description.mReserved
        self.mSampleRate = description.mSampleRate
    }
    
    func getASBD() -> AudioStreamBasicDescription {
        var description = AudioStreamBasicDescription()
        description.mBitsPerChannel = self.mBitsPerChannel
        description.mBytesPerFrame = self.mBytesPerFrame
        description.mBytesPerPacket = self.mBytesPerPacket
        description.mChannelsPerFrame = self.mChannelsPerFrame
        description.mFormatFlags = self.mFormatFlags
        description.mFormatID = self.mFormatID
        description.mFramesPerPacket = self.mFramesPerPacket
        description.mReserved = self.mReserved
        description.mSampleRate = self.mSampleRate
        return description
    }
    
    /// Returns a JSON data object
    func getData() -> Data? {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(self) else { return nil }
        return data
    }
    
    static func getObject(fromData data: Data?) -> Self? {
        let decoder = JSONDecoder()
        guard let action = try? decoder.decode(CodableAudioStreamBasicDescription.self, from: data!) else { return nil }
        return action
    }
}
