//
//  ViewController.swift
//  MetaManager
//
//  Created by Jeremy on 2021/12/23.
//

import UIKit
import AVFoundation

class ViewController: UIViewController {
    private var player: AVPlayer?
    private var playerItemContext = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
     
        let url = Bundle.main.url(forResource: "test", withExtension: "MOV")!
        let asset = AVAsset(url: url)
        let playerItem = AVPlayerItem(asset: asset)
        
        playerItem.addObserver(self,
                               forKeyPath: #keyPath(AVPlayerItem.status),
                               options: [.old, .new],
                               context: &playerItemContext)
        
        player = AVPlayer(playerItem: playerItem)
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.frame = view.layer.bounds
        view.layer.addSublayer(playerLayer)
     }
    
    override func observeValue(forKeyPath keyPath: String?,
                               of object: Any?,
                               change: [NSKeyValueChangeKey : Any]?,
                               context: UnsafeMutableRawPointer?) {

        // Only handle observations for the playerItemContext
        guard context == &playerItemContext else {
            super.observeValue(forKeyPath: keyPath,
                               of: object,
                               change: change,
                               context: context)
            return
        }

        if keyPath == #keyPath(AVPlayerItem.status) {
            let status: AVPlayerItem.Status
            if let statusNumber = change?[.newKey] as? NSNumber {
                status = AVPlayerItem.Status(rawValue: statusNumber.intValue)!
            } else {
                status = .unknown
            }

            // Switch over status value
            switch status {
            case .readyToPlay:
                player?.play()
            case .failed:
                print("Player item failed.")
            case .unknown:
                print("Player item is not yet ready.")
            }
        }
    }
}

