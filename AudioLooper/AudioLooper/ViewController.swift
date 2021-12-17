//
//  ViewController.swift
//  AudioLooper
//
//  Created by Jeremy on 2021/12/17.
//

import UIKit
import AVFoundation

class ViewController: UIViewController {

    private lazy var playButton = _playButton()
    private lazy var rateSlider = _rateSlider()
    private lazy var firstPanSlider = _firstPanSlider()
    private lazy var secondPanSlider = _secondPanSlider()
    private lazy var thirdPanSlider = _thirdPanSlider()
    private lazy var firstVolumeSlider = _firstVolumeSlider()
    private lazy var secondVolumeSlider = _secondVolumeSlider()
    private lazy var thirdVolumeSlider = _thirdVolumeSlider()
    
    private var playing = false
    private var players = [AVAudioPlayer]()
    private var recorder: AVAudioRecorder?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        _setupUI()
        _setupPlayers()
        _registerNotification()
        _createRecorder()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
}

private extension ViewController {
    func _setupUI() {
        playButton.frame.origin = CGPoint(x: 100, y: 100)
        rateSlider.frame.origin = CGPoint(x: 100, y: 160)
        
        firstPanSlider.frame.origin = CGPoint(x: 100, y: 270)
        firstVolumeSlider.frame.origin = CGPoint(x: 100, y: 310)
        
        secondPanSlider.frame.origin = CGPoint(x: 100, y: 370)
        secondVolumeSlider.frame.origin = CGPoint(x: 100, y: 410)
        
        thirdPanSlider.frame.origin = CGPoint(x: 100, y: 479)
        thirdVolumeSlider.frame.origin = CGPoint(x: 100, y: 520)
    }
    
    func _setupPlayers() {
        players = ["test1", "test2", "test3"].map(_playerForFile(with:))
    }
    
    func _playerForFile(with name: String) -> AVAudioPlayer {
        let url = Bundle.main.url(forResource: name, withExtension: "aac")!
        let player = try! AVAudioPlayer(contentsOf: url)
        player.numberOfLoops = -1 // loop indefinitely
        player.enableRate = true
        player.prepareToPlay()
        return player
    }
    
    func _registerNotification() {
        NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: AVAudioSession.sharedInstance, queue: OperationQueue.main) { [weak self] notification in
            let info = notification.userInfo
            let type = info?[AVAudioSessionInterruptionTypeKey] as? AVAudioSession.InterruptionType
            
            if type == AVAudioSession.InterruptionType.began {
                self?._stop()
            } else {
                if let options = info?[AVAudioSessionInterruptionOptionKey] as? AVAudioSession.InterruptionOptions, options == .shouldResume {
                    self?._play()
                }
                self?._stop()
            }
        }
        
        NotificationCenter.default.addObserver(forName: AVAudioSession.routeChangeNotification, object: AVAudioSession.sharedInstance, queue: OperationQueue.main) { [weak self] notification in
            let info = notification.userInfo
            if let reason = info?[AVAudioSessionRouteChangeReasonKey] as? AVAudioSession.RouteChangeReason, reason == .oldDeviceUnavailable {
                let previousRoute = info?[AVAudioSessionRouteChangePreviousRouteKey] as? AVAudioSessionRouteDescription
                let previousOutput = previousRoute?.outputs.first
                let portType = previousOutput?.portType
                if portType == AVAudioSession.Port.headphones {
                    self?._stop()
                }
            }
        }
    }
    
    func _createRecorder() {
        let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).last!
        let filePath = URL(string: path)!.appendingPathComponent("@voice.m4a")
        let setting = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 22050.0,
            AVNumberOfChannelsKey: 1,
        ] as [String : Any]
        do {
            recorder = try AVAudioRecorder(url: filePath, settings: setting)
        } catch let error {
            print("failed with error: \(error)")
        }
        recorder?.prepareToRecord()
    }
    
    func _doPlay() {
        if !playing {
            _play()
        } else {
            _stop()
        }
    }
    
    func _play() {
        guard !playing else { return }
        let delayTime = players[0].deviceCurrentTime + 0.01
        players.forEach {
            $0.play(atTime: delayTime)
        }
        playing = true
        print("delayTime: \(delayTime)")
    }
    
    func _stop() {
        guard playing else { return }
        players.forEach {
            $0.stop()
            $0.currentTime = 0.0
        }
        playing = false
    }
    
    @objc func _rateChanged(_ sender: UISlider) {
        let rate = sender.value
        players.forEach {
            $0.rate = rate
        }
        print("rate: \(rate)")
    }
    
    @objc func _firstPanChanged(_ sender: UISlider) {
        let pan = sender.value
        players[0].pan = pan
        print("first pan: \(pan)")
    }
    
    @objc func _secondPanChanged(_ sender: UISlider) {
        let pan = sender.value
        players[1].pan = pan
        print("second pan: \(pan)")
    }
    
    @objc func _thirdPanChanged(_ sender: UISlider) {
        let pan = sender.value
        players[2].pan = pan
        print("third pan: \(pan)")
    }
    
    @objc func _firstVolumeChanged(_ sender: UISlider) {
        let volume = sender.value
        players[0].volume = volume
        print("first volume: \(volume)")
    }
    
    @objc func _secondVolumeChanged(_ sender: UISlider) {
        let volume = sender.value
        players[1].volume = volume
        print("second volume: \(volume)")
    }
    
    @objc func _thirdVolumeChanged(_ sender: UISlider) {
        let volume = sender.value
        players[2].volume = volume
        print("third volume: \(volume)")
    }
}

private extension ViewController {
    func _playButton() -> UIButton {
        let b = UIButton(type: .system)
        b.frame.size = CGSize(width: 50, height: 50)
        b.setTitle("Play", for: .normal)
        b.addAction(UIAction(handler: { [weak self] _ in
            self?._doPlay()
        }), for: .touchUpInside)
        view.addSubview(b)
        return b
    }
    
    func _rateSlider() -> UISlider {
        let s = UISlider()
        s.frame.size = CGSize(width: 200, height: 10)
        s.minimumValue = 0.5
        s.maximumValue = 2.0
        s.value = 1.0
        s.isContinuous = true
        s.addTarget(self, action: #selector(_rateChanged), for: .valueChanged)
        view.addSubview(s)
        return s
    }

    func _basePanSlider() -> UISlider {
        let s = UISlider()
        s.frame.size = CGSize(width: 200, height: 10)
        s.minimumValue = -1.0
        s.maximumValue = 1.0
        s.value = 0.0
        s.isContinuous = true
        view.addSubview(s)
        return s
    }
    
    func _firstPanSlider() -> UISlider {
        let s = _basePanSlider()
        s.addTarget(self, action: #selector(_firstPanChanged), for: .valueChanged)
        return s
    }
    
    func _secondPanSlider() -> UISlider {
        let s = _basePanSlider()
        s.addTarget(self, action: #selector(_secondPanChanged), for: .valueChanged)
        return s
    }
    
    func _thirdPanSlider() -> UISlider {
        let s = _basePanSlider()
        s.addTarget(self, action: #selector(_thirdPanChanged), for: .valueChanged)
        return s
    }
    
    func _baseVolumeSlider() -> UISlider {
        let s = UISlider()
        s.frame.size = CGSize(width: 200, height: 10)
        s.minimumValue = 0.0
        s.maximumValue = 1.0
        s.value = 0.5
        view.addSubview(s)
        return s
    }
    
    func _firstVolumeSlider() -> UISlider {
        let s = _baseVolumeSlider()
        s.addTarget(self, action: #selector(_firstVolumeChanged), for: .valueChanged)
        return s
    }
    
    func _secondVolumeSlider() -> UISlider {
        let s = _baseVolumeSlider()
        s.addTarget(self, action: #selector(_secondVolumeChanged), for: .valueChanged)
        return s
    }
    
    func _thirdVolumeSlider() -> UISlider {
        let s = _baseVolumeSlider()
        s.addTarget(self, action: #selector(_thirdVolumeChanged), for: .valueChanged)
        return s
    }
}

