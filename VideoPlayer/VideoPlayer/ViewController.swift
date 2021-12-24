//
//  ViewController.swift
//  VideoPlayer
//
//  Created by Jeremy on 2021/12/24.
//

import UIKit
import AVFoundation

private var playerViewControllerKVOContext = 0

class ViewController: UIViewController {
    private let assetKeysRequiredToPlay = [
        "playable",
        "hasProtectedContent"
    ]
    
    private var timeObserverToken: Any?
    
    @objc private let player = AVPlayer()
    
    private var currentTime: TimeInterval {
        get {
            CMTimeGetSeconds(player.currentTime())
        }
        set {
            let newTime = CMTimeMakeWithSeconds(newValue, preferredTimescale: 1)
            player.seek(to: newTime, toleranceBefore: .zero, toleranceAfter: .zero)
        }
    }
    
    private var duration: TimeInterval {
        guard let currentItem = player.currentItem else { return 0.0 }
        return CMTimeGetSeconds(currentItem.duration)
    }
    
    private var rate: Float {
        get {
            player.rate
        }
        set {
            player.rate = newValue
        }
    }
    
    private var asset: AVURLAsset? {
        didSet {
            guard let newAsset = asset else { return }
            _asynchronouslyLoadURLAsset(newAsset)
        }
    }
    
    private var playerLayer: AVPlayerLayer? {
        playerView.playerLayer
    }
    
    private var playerItem: AVPlayerItem? = nil {
        didSet {
            player.replaceCurrentItem(with: playerItem)
        }
    }
    
    private let timeRemainingFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.zeroFormattingBehavior = .pad
        formatter.allowedUnits = [.minute, .second]
        
        return formatter
    }()
    
    // UI Components
    private lazy var timeSlider = _timeSlider()
    private lazy var startTimeLabel = _startTimeLabel()
    private lazy var durationLabel = _durationLabel()
    private lazy var rewindButton = _rewindButton()
    private lazy var playPauseButton = _playPauseButton()
    private lazy var fastForwardButton = _fastForwardButton()
    private lazy var playerView = _playerView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        _setupUI()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        addObserver(self, forKeyPath: #keyPath(ViewController.player.currentItem.duration), options: [.new, .initial], context: &playerViewControllerKVOContext)
        addObserver(self, forKeyPath: #keyPath(ViewController.player.rate), options: [.new, .initial], context: &playerViewControllerKVOContext)
        addObserver(self, forKeyPath: #keyPath(ViewController.player.currentItem.status), options: [.new, .initial], context: &playerViewControllerKVOContext)

        playerView.playerLayer.player = player
        
        let movieURL = Bundle.main.url(forResource: "ElephantSeals", withExtension: "mov")!
        asset = AVURLAsset(url: movieURL, options: nil)
        
        let interval = CMTimeMake(value: 1, timescale: 1)
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: DispatchQueue.main) {
            [unowned self] time in
            
            let timeElapsed = Float(CMTimeGetSeconds(time))
            
            timeSlider.value = Float(timeElapsed)
            startTimeLabel.text = _createTimeString(time: timeElapsed)
            startTimeLabel.sizeToFit()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        if let timeObserverToken = timeObserverToken {
            player.removeTimeObserver(timeObserverToken)
            self.timeObserverToken = nil
        }
        
        player.pause()
        
        removeObserver(self, forKeyPath: #keyPath(ViewController.player.currentItem.duration), context: &playerViewControllerKVOContext)
        removeObserver(self, forKeyPath: #keyPath(ViewController.player.rate), context: &playerViewControllerKVOContext)
        removeObserver(self, forKeyPath: #keyPath(ViewController.player.currentItem.status), context: &playerViewControllerKVOContext)
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        guard context == &playerViewControllerKVOContext else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
            return
        }
        
        if keyPath == #keyPath(ViewController.player.currentItem.duration) {
            let newDuration: CMTime
            if let newDurationAsValue = change?[.newKey] as? NSValue {
                newDuration = newDurationAsValue.timeValue
            } else {
                newDuration = .zero
            }
            
            let hasValidDuration = newDuration.isNumeric && newDuration.value != 0
            let newDurationSeconds = hasValidDuration ? CMTimeGetSeconds(newDuration) : 0.0
            let currentTime = hasValidDuration ? Float(CMTimeGetSeconds(player.currentTime())) : 0.0
            
            timeSlider.maximumValue = Float(newDurationSeconds)
            timeSlider.value = currentTime
            timeSlider.isEnabled = hasValidDuration
            
            rewindButton.isEnabled = hasValidDuration
            playPauseButton.isEnabled = hasValidDuration
            fastForwardButton.isEnabled = hasValidDuration
            
            startTimeLabel.isEnabled = hasValidDuration
            startTimeLabel.text = _createTimeString(time: currentTime)
            
            durationLabel.isEnabled = hasValidDuration
            durationLabel.text = _createTimeString(time: Float(newDurationSeconds))
            durationLabel.sizeToFit()
        } else if keyPath == #keyPath(ViewController.player.rate) {
            let newRate = (change?[.newKey] as! NSNumber).doubleValue
            playPauseButton.setTitle(newRate == 1.0 ? "¶" : "∆", for: .normal)
        } else if keyPath == #keyPath(ViewController.player.currentItem.status) {
            let newStatus: AVPlayerItem.Status

            if let newStatusAsNumber = change?[.newKey] as? NSNumber {
                newStatus = AVPlayerItem.Status(rawValue: newStatusAsNumber.intValue)!
            }
            else {
                newStatus = .unknown
            }
            
            if newStatus == .failed {
                _handleErrorWithMessage(player.currentItem?.error?.localizedDescription, error:player.currentItem?.error)
            }
        }
    }
    
    override class func keyPathsForValuesAffectingValue(forKey key: String) -> Set<String> {
        let affectedKeyPathsMappingByKey: [String: Set<String>] = [
            "duration":     [#keyPath(ViewController.player.currentItem.duration)],
            "rate":         [#keyPath(ViewController.player.rate)]
        ]
        
        return affectedKeyPathsMappingByKey[key] ?? super.keyPathsForValuesAffectingValue(forKey: key)
    }
}

private extension ViewController {
    func _setupUI() {
        view.addSubview(timeSlider)
        timeSlider.frame.origin = CGPoint(x: view.bounds.width - timeSlider.bounds.width - 20,
                                          y: view.bounds.height - timeSlider.bounds.height - 30)
        
        view.addSubview(startTimeLabel)
        startTimeLabel.frame.origin = CGPoint(x: timeSlider.frame.minX, y: timeSlider.frame.minY - startTimeLabel.bounds.height)
        
        view.addSubview(durationLabel)
        durationLabel.frame.origin = CGPoint(x: timeSlider.frame.maxX - durationLabel.bounds.width, y: timeSlider.frame.minY - durationLabel.bounds.height)
        
        view.addSubview(rewindButton)
        rewindButton.frame.origin = CGPoint(x: 30, y: timeSlider.frame.minY)
        
        view.addSubview(playPauseButton)
        playPauseButton.frame.origin = CGPoint(x: rewindButton.frame.maxX + 10, y: timeSlider.frame.minY)
        
        view.addSubview(fastForwardButton)
        fastForwardButton.frame.origin = CGPoint(x: playPauseButton.frame.maxX + 10, y: timeSlider.frame.minY)
        
        view.addSubview(playerView)
        playerView.frame.origin = CGPoint(x: 0, y: 44)
    }
    
    func _asynchronouslyLoadURLAsset(_ asset: AVURLAsset) {
        asset.loadValuesAsynchronously(forKeys: assetKeysRequiredToPlay) { [weak self] in
            guard let self = self else { return }
            DispatchQueue.main.async {
                guard self.asset == asset else { return }
                for key in self.assetKeysRequiredToPlay {
                    var error: NSError?
                    if asset.statusOfValue(forKey: key, error: &error) == .failed {
                        let stringFormat = NSLocalizedString("error.asset_key_%@_failed.description", comment: "Can't use this AVAsset because one of it's keys failed to load")

                        let message = String.localizedStringWithFormat(stringFormat, key)
                        
                        self._handleErrorWithMessage(message, error: error)
                        
                        return
                    }
                }
                if !asset.isPlayable || asset.hasProtectedContent {
                    let message = NSLocalizedString("error.asset_not_playable.description", comment: "Can't use this AVAsset because it isn't playable or has protected content")
                    
                    self._handleErrorWithMessage(message)
                    
                    return
                }
                self.playerItem = AVPlayerItem(asset: asset)
            }
        }
    }
    
    func _handleErrorWithMessage(_ message: String?, error: Error? = nil) {
        NSLog("Error occured with message: \(String(describing: message)), error: \(String(describing: error)).")
    
        let alertTitle = NSLocalizedString("alert.error.title", comment: "Alert title for errors")
        let defaultAlertMessage = NSLocalizedString("error.default.description", comment: "Default error message when no NSError provided")

        let alert = UIAlertController(title: alertTitle, message: message == nil ? defaultAlertMessage : message, preferredStyle: .alert)

        let alertActionTitle = NSLocalizedString("alert.error.actions.OK", comment: "OK on error alert")

        let alertAction = UIAlertAction(title: alertActionTitle, style: .default, handler: nil)
        
        alert.addAction(alertAction)

        present(alert, animated: true, completion: nil)
    }
    
    func _createTimeString(time: Float) -> String {
        let components = NSDateComponents()
        components.second = Int(max(0.0, time))
        
        return timeRemainingFormatter.string(from: components as DateComponents)!
    }
    
    @objc func _timeSliderDidChanged(_ sender: UISlider) {
        currentTime = Double(sender.value)
    }
}

// UI Components
private extension ViewController {
    func _timeSlider() -> UISlider {
        let v = UISlider()
        v.frame.size.width = 200
        v.addTarget(self, action: #selector(_timeSliderDidChanged(_:)), for: .valueChanged)
        return v
    }
    
    func _baseLabel(with text: String) -> UILabel {
        let l = UILabel()
        l.text = text
        l.font = .systemFont(ofSize: 12)
        l.textColor = .gray
        l.textAlignment = .center
        l.sizeToFit()
        return l
    }
    
    func _startTimeLabel() -> UILabel {
        _baseLabel(with: "0:00")
    }
    
    func _durationLabel() -> UILabel {
        _baseLabel(with: "-:--")
    }
    
    func _baseButton(with title: String, action: (() -> Void)?) -> UIButton {
        let b = UIButton(type: .system)
        b.backgroundColor = .gray.withAlphaComponent(0.3)
        b.titleLabel?.font = .systemFont(ofSize: 12)
        b.setTitle(title, for: .normal)
        b.sizeToFit()
        b.addAction(UIAction(handler: { _ in
            action?()
        }), for: .touchUpInside)
        return b
    }
    
    func _rewindButton() -> UIButton {
        let b = _baseButton(with: "≤") { [weak self] in
            guard let self = self else { return }
            self.rate = max(self.player.rate - 2.0, -2.0)
        }
        return b
    }
    
    func _playPauseButton() -> UIButton {
        let b = _baseButton(with: "∆") { [weak self] in
            guard let self = self else { return }
            if self.player.rate != 1.0 {
                if self.currentTime == self.duration {
                    self.currentTime = 0.0
                }
                self.player.play()
            } else {
                self.player.pause()
            }
        }
        return b
    }
    
    func _fastForwardButton() -> UIButton {
        let b = _baseButton(with: "≥") { [weak self] in
            guard let self = self else { return }
            self.rate = min(self.player.rate + 2.0, 2.0)
        }
        return b
    }
    
    func _playerView() -> PlayerView {
        let v = PlayerView()
        v.backgroundColor = .gray.withAlphaComponent(0.3)
        let ratio: CGFloat = 3/4
        v.frame.size = CGSize(width: view.bounds.width, height: view.bounds.width * ratio)
        return v
    }
}
