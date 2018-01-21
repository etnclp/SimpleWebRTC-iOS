//
//  ViewController.swift
//  SimpleWebRTC
//
//  Created by Erdi T on 21.01.2018.
//  Copyright © 2018 Mirana Software. All rights reserved.
//

import UIKit
import WebRTC

class ViewController: UIViewController {
    
    var remoteVideoStream: RTCMediaStream? {
        didSet {
            self.remoteVideoStream?.videoTracks[0].add(self.remoteVideoView)
        }
    }
    
    var localVideoStream: RTCMediaStream? {
        didSet {
            self.localVideoStream?.videoTracks[0].add(self.localVideoView)
        }
    }
    
    // MARK: - IBOutlets
    
    @IBOutlet weak var remoteVideoView: RTCEAGLVideoView!
    @IBOutlet weak var localVideoView: RTCEAGLVideoView!
    
    @IBOutlet weak var remoteVideoHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var localVideoHeightConstraint: NSLayoutConstraint!
    
    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        
        remoteVideoView.delegate = self
        localVideoView.delegate = self
        
        localVideoView.transform = CGAffineTransform(scaleX: -1, y: 1)
        
        let roomName = "2f36f758-0db1-4691-a4b6-e30cdc5dd11d"
        let client = WebRtcClient.shared
        client.listener = self
        client.start(roomName: roomName)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        UIApplication.shared.statusBarStyle = .lightContent
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

}

extension ViewController: RTCEAGLVideoViewDelegate {
    
    func videoView(_ videoView: RTCEAGLVideoView, didChangeVideoSize size: CGSize) {
        let scale = size.width / size.height
        switch videoView {
        case remoteVideoView:
            let height = videoView.frame.width / scale
            remoteVideoHeightConstraint.constant = height
            videoView.layoutIfNeeded()
        case localVideoView:
            let height = videoView.frame.width / scale
            localVideoHeightConstraint.constant = height
            videoView.layoutIfNeeded()
        default:
            break
        }
    }
    
}

extension ViewController: RtcListener {
    
    func localStreamAdded(_ stream: RTCMediaStream) {
        self.localVideoStream = stream
    }
    
    func remoteStreamAdded(_ stream: RTCMediaStream) {
        self.remoteVideoStream = stream
    }
    
}
