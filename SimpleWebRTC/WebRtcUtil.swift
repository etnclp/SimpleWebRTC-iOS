//
//  WebRtcUtil.swift
//  SimpleWebRTC
//
//  Created by Erdi T on 21.01.2018.
//  Copyright © 2018 Mirana Software. All rights reserved.
//

import WebRTC

class WebRTCUtil {
    
    static var stunServer: RTCIceServer?
    
    static var turnServer: RTCIceServer?
    
    class var iceServers: [RTCIceServer] {
        return [stunServer, turnServer].filter({ $0 != nil }).map({ $0! })
    }
    
    class var answerConstraints: RTCMediaConstraints {
        return RTCMediaConstraints(
            mandatoryConstraints: ["OfferToReceiveVideo": kRTCMediaConstraintsValueTrue,
                                   "OfferToReceiveAudio": kRTCMediaConstraintsValueTrue],
            optionalConstraints: nil)
    }
    
    class var offerConstraints: RTCMediaConstraints {
        return RTCMediaConstraints(
            mandatoryConstraints: ["OfferToReceiveVideo": kRTCMediaConstraintsValueTrue,
                                   "OfferToReceiveAudio": kRTCMediaConstraintsValueTrue],
            optionalConstraints: nil)
    }
    
    class var mediaStreamConstraints: RTCMediaConstraints {
        return RTCMediaConstraints(
            mandatoryConstraints: nil,
            optionalConstraints: nil)
    }
    
    class var peerConnectionConstraints: RTCMediaConstraints {
        return RTCMediaConstraints(
            mandatoryConstraints: ["OfferToReceiveVideo": kRTCMediaConstraintsValueTrue,
                                   "OfferToReceiveAudio": kRTCMediaConstraintsValueTrue],
            optionalConstraints: nil)
    }
    
}

protocol RtcListener {
    
    /// Returns when local stream is added.
    ///
    /// - Parameters:
    ///   - stream: Self's stream.
    /// - Returns: No return value.
    func localStreamAdded(_ stream: RTCMediaStream)
    
    /// Returns when remote stream is added.
    ///
    /// - Parameters:
    ///   - stream: Remote stream.
    /// - Returns: No return value.
    func remoteStreamAdded(_ stream: RTCMediaStream)
    
}

protocol Command {
    
    func execute(data: [String: Any])
}

