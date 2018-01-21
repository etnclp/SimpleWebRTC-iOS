//
//  WebRtcClient.swift
//  SimpleWebRTC
//
//  Created by Erdi T on 21.01.2018.
//  Copyright © 2018 Mirana Software. All rights reserved.
//

import SocketIO
import WebRTC
import AVFoundation

class WebRtcClient: NSObject {
    
    // MARK: Properties
    
    static let shared = WebRtcClient()
    
    fileprivate let socket = SocketIOClient(socketURL: URL(string: "https://sandbox.simplewebrtc.com/")!)
    fileprivate let factory: RTCPeerConnectionFactory
    fileprivate var pc: RTCPeerConnection!
    fileprivate var localStream: RTCMediaStream?
    
    fileprivate var clientID: String? = nil
    fileprivate var sid: String?
    
    public var listener: RtcListener?
    
    // MARK: -
    
    override init() {
        RTCPeerConnectionFactory.initialize()
        RTCInitializeSSL()
        factory = RTCPeerConnectionFactory()
        super.init()
    }
    
    /// This method used to open the socket connection.
    ///
    /// - Parameters:
    ///   - roomName: Room name.
    /// - Returns: No return value.
    func start(roomName: String) {
        self.localStream = createLocalStream()
        
        socket.on(clientEvent: .statusChange) { data, ack in
            if self.socket.status == .connected {
                self.joinRoom(name: roomName)
            }
        }
        
        socket.on("message") { data, ack in
            guard let dict = data[0] as? [String: Any], let messageType = dict["type"] as? String else {
                NSLog("Malformed JSON data from Socket. Message.")
                return
            }
            
            print("getting --> \(messageType)")
            switch messageType {
            case "offer": self.CreateAnswerCommand(dict)
            case "answer": self.SetRemoteSDPCommand(dict)
            case "candidate": self.AddIceCandidateCommand(dict)
            default: break
            }
        }
        
        socket.on("remove") { data, ack in
            guard let id = (data[0] as? [String : Any])?["id"] as? String else { return }
            
            if id == self.clientID {
                print("Client removed.", id)
                self.clientID = nil
                self.pc = nil
            }
        }
        
        socket.on("stunservers") { data, ack in
            guard let dict = (data[0] as? [[String: Any]])?.first else { return }
            
            if let urls = dict["urls"] as? String {
                WebRTCUtil.stunServer = RTCIceServer(urlStrings: [urls])
            }
        }
        
        socket.on("turnservers") { data, ack in
            guard let dict = (data[0] as? [[String: Any]])?.first else { return }
            
            if let urls = dict["urls"] as? [String] {
                WebRTCUtil.turnServer = RTCIceServer(
                    urlStrings: urls,
                    username: dict["username"] as? String,
                    credential: dict["credential"] as? String
                )
            }
        }
        
        socket.connect()
    }

    // MARK: -
    
    /** This method is used to join to specified room. */
    private func joinRoom(name: String) {
        socket.emitWithAck("join", name).timingOut(after: 0) { data in
            guard let dict = data[1] as? [String : Any], let clients = dict["clients"] as? [String : Any] else { return }
            
            print("Client count: \(clients.count)")
            if clients.count > 0 {
                self.clientID = clients.first?.key
                self.createOffer()
            }
        }
    }
    
    /** This method creates peer connection. */
    private func getPeer() -> RTCPeerConnection {
        if pc == nil {
            let config = RTCConfiguration()
            config.iceServers = WebRTCUtil.iceServers
            pc = factory.peerConnection(with: config, constraints: WebRTCUtil.peerConnectionConstraints, delegate: self)
            pc.add(localStream ?? createLocalStream())
        }
        return pc
    }
    
    
    /** This method creates local stream. */
    private func createLocalStream() -> RTCMediaStream {
        let videoSource = factory.avFoundationVideoSource(with: WebRTCUtil.mediaStreamConstraints)
        let audioSource = factory.audioSource(with: WebRTCUtil.mediaStreamConstraints)
        
        let localMS = factory.mediaStream(withStreamId: "MyStream")
        localMS.addAudioTrack(factory.audioTrack(with: audioSource, trackId: "MyAudio"))
        localMS.addVideoTrack(factory.videoTrack(with: videoSource, trackId: "MyVideo"))
        listener?.localStreamAdded(localMS)
        return localMS
    }
    
    // MARK: -
    
    /** This method sends message to server. */
    private func sendMessage(type: String, payload: [String: Any]) {
        print("sending --> \(type)")
        let dict: [String: Any] = [
            "type": type,
            "sid": self.sid ?? String(Date().millisecondsSince1970),
            "to": self.clientID ?? "",
            "roomType": "video",
            "payload": payload
        ]
        socket.emit("message", dict)
    }
}

// MARK: - Commands

extension WebRtcClient {
    
    fileprivate func createOffer() {
        getPeer().offer(for: WebRTCUtil.offerConstraints) { (description, error) in
            guard let description = description else { return }
            self.getPeer().setLocalDescription(description) { (error) in
                if let error = error {
                    NSLog("CreateOffer SetLocalDescription error: ", error.localizedDescription)
                    return
                }
                
                let payload: [String: Any] = [
                    "type": RTCSessionDescription.string(for: description.type),
                    "sdp": description.sdp]
                self.sendMessage(type: RTCSessionDescription.string(for: description.type), payload: payload)
            }
        }
    }
    
    fileprivate func CreateAnswerCommand(_ data: [String: Any]) {
        self.clientID = data["from"] as? String
        self.sid = data["sid"] as? String
        
        guard let sdp = (data["payload"] as? [String: Any])?["sdp"] as? String else { return }
        getPeer().setRemoteDescription(RTCSessionDescription(type: .offer, sdp: sdp)) { (error) in
            if let error = error {
                NSLog("ReceiveOffer SetRemoteDescription error: ", error.localizedDescription)
                return
            }
        }
        
        getPeer().answer(for: WebRTCUtil.answerConstraints) { (description, error) in
            guard let description = description else { return }
            self.getPeer().setLocalDescription(description) { (error) in
                if let error = error {
                    NSLog("CreateAnswer SetLocalDescription error: ", error.localizedDescription)
                    return
                }
                
                let payload: [String: Any] = [
                    "type": RTCSessionDescription.string(for: description.type),
                    "sdp": description.sdp,
                    ]
                self.sendMessage(type: RTCSessionDescription.string(for: description.type), payload: payload)
            }
        }
    }
    
    fileprivate func SetRemoteSDPCommand(_ data: [String: Any]) {
        guard let sdp = (data["payload"] as? [String: Any])?["sdp"] as? String else { return }
        getPeer().setRemoteDescription(RTCSessionDescription(type: .answer, sdp: sdp)) { (error) in
            if let error = error {
                NSLog("ReceiveAnswer SetRemoteDescription error: ", error.localizedDescription)
                return
            }
        }
    }
    
    fileprivate func AddIceCandidateCommand(_ data: [String: Any]) {
        guard let candidate = (data["payload"] as? [String: Any])?["candidate"] as? [String: Any] else { return }
        getPeer().add(RTCIceCandidate(
            sdp: candidate["candidate"] as! String,
            sdpMLineIndex: candidate["sdpMLineIndex"] as! Int32,
            sdpMid: candidate["sdpMid"] as? String
        ))
    }
    
}

// MARK: - PeerConnection Delegate

extension WebRtcClient: RTCPeerConnectionDelegate {
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {
        
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
        listener?.remoteStreamAdded(stream)
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {

    }
    
    func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {
        
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {
        
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        let payload: [String: Any] = [
            "candidate": [
                "candidate": candidate.sdp,
                "sdpMLineIndex": candidate.sdpMLineIndex,
                "sdpMid": candidate.sdpMid!
            ]
        ]
        sendMessage(type: "candidate", payload: payload)
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {
        
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {
        
    }
    
}
