//
//  ViewController.swift
//  Voice Memo
//
//  Created by Jeremy on 2021/12/18.
//

import UIKit
import AVFoundation
import Photos
import MediaPlayer

class ViewController: UIViewController {

    private lazy var timeLabel = _timeLabel()
    private lazy var recordButton = _recordButton()
    private lazy var stopButton = _stopButton()
    private lazy var playButton = _playButton()
    
    private var levelTimer: CADisplayLink?
    private var timer: Timer?
    private var player: AVAudioPlayer?
    private var recorder: AVAudioRecorder?
    private var recording = false {
        didSet {
            recordButton.setTitle(recording ? "Pause" : "Record", for: .normal)
        }
    }
    
    private var documentDir: URL {
        URL(fileURLWithPath: NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        _setupUI()
        _setupRecorder()
        _requestPermission()

        let url = Bundle.main.url(forResource: "sample4", withExtension: "m4a")!
        let asset = AVAsset(url: url)
        let formatsKey = "availableMetadataFormats"

        asset.loadValuesAsynchronously(forKeys: [formatsKey]) {
            var error: NSError? = nil
            let status = asset.statusOfValue(forKey: formatsKey, error: &error)
            guard status == .loaded else { return }
            let metadata = asset.availableMetadataFormats.compactMap { [weak asset] in
                asset?.metadata(forFormat: $0)
            }.flatMap { $0 }
            let keySpace = AVMetadataKeySpace.iTunes
            let artistKey = AVMetadataKey.iTunesMetadataKeyArtist
            let albumKey = AVMetadataKey.iTunesMetadataKeyAlbum
            let artistMetadata = AVMetadataItem.metadataItems(from: metadata, withKey: artistKey, keySpace: keySpace)
            let albumMetadata = AVMetadataItem.metadataItems(from: metadata, withKey: albumKey, keySpace: keySpace)
            print("artistMetadata: \(artistMetadata), albumMetadata: \(albumMetadata)")
            
            metadata.forEach {
                print("\($0.identifier?.rawValue)")
            }
        }
    }
}

private extension ViewController {
    func _setupUI() {
        view.addSubview(timeLabel)
        view.addSubview(recordButton)
        view.addSubview(stopButton)
        view.addSubview(playButton)
    }
    
    func _setupRecorder() {
        let tmp = NSTemporaryDirectory()
        let filePath = URL(fileURLWithPath: tmp).appendingPathComponent("memo.caf")
        
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatAppleIMA4,
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitDepthHintKey: 16,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
        ]
        
        do {
            recorder = try AVAudioRecorder(url: filePath, settings: settings)
            recorder?.isMeteringEnabled = true
            recorder?.delegate = self
            recorder?.prepareToRecord()
        } catch let error {
            print("failed with error: \(error)")
        }
    }
    
    func _record() {
        if recorder?.isRecording == false {
            recording = recorder?.record() == true
            _startMeterTimer()
        }
    }
    
    func _pause() {
        recorder?.pause()
    }
    
    func _stop() {
        recorder?.stop()
        _stopMeterTimer()
    }
    
    func _requestPermission() {
        AVAudioSession.sharedInstance().requestRecordPermission { allowed in
            print("allowed: \(allowed)")
        }
    }
    
    func _playbackMemo() {
        let fileName = "memo.caf"
        let finalURL = documentDir.appendingPathComponent(fileName)
        player?.stop()
        player = try? AVAudioPlayer(contentsOf: finalURL)
        player?.delegate = self
        player?.play()
        _startTimer()
    }
    
    func _formattedCurrentTime() -> String {
        guard let currentTime = player?.currentTime else { return "" }
        let hours = Int(currentTime / 3600.0)
        let minutes = Int((currentTime / 60.0).truncatingRemainder(dividingBy: 60.0))
        let seconds = Int(currentTime.truncatingRemainder(dividingBy: 60.0))
        return String(format: "%02i:%02i:%02i", hours, minutes, seconds)
    }
    
    func _startTimer() {
        timer?.invalidate()
        timer = Timer(timeInterval: 0.5, target: self, selector: #selector(_updateTimerDisplay), userInfo: nil, repeats: true)
        RunLoop.main.add(timer!, forMode: .common)
    }
    
    @objc func _updateTimerDisplay() {
        timeLabel.text = _formattedCurrentTime()
    }
    
    func _startMeterTimer() {
        levelTimer = CADisplayLink(target: self, selector: #selector(_updateMeter))
        levelTimer?.preferredFramesPerSecond = 5
        levelTimer?.add(to: RunLoop.current, forMode: .common)
    }
    
    @objc func _updateMeter() {
        recorder?.updateMeters()
        let avgPower = recorder?.averagePower(forChannel: 0)
        let peakPower = recorder?.peakPower(forChannel: 0)
        print("avgPower: \(avgPower). peakPower: \(peakPower)")
    }
    
    func _stopMeterTimer() {
        levelTimer?.invalidate()
        levelTimer = nil
    }
}

private extension ViewController {
    func _recordButton() -> UIButton {
        let b = UIButton(type: .system)
        b.setTitle("Record", for: .normal)
        b.frame = CGRect(x: 50, y: 100, width: 100, height: 100)
        b.addAction(UIAction(handler: { [weak self] _ in
            guard let self = self else { return }
            if self.recording {
                self._pause()
            } else {
                self._record()
            }
        }), for: .touchUpInside)
        return b
    }
    
    func _stopButton() -> UIButton {
        let b = UIButton(type: .system)
        b.setTitle("Stop", for: .normal)
        b.frame = CGRect(x: 150, y: 100, width: 100, height: 100)
        b.addAction(UIAction(handler: { [weak self] _ in
            self?._stop()
        }), for: .touchUpInside)
        return b
    }
    
    func _playButton() -> UIButton {
        let b = UIButton(type: .system)
        b.setTitle("Play", for: .normal)
        b.frame = CGRect(x: 50, y: 200, width: 100, height: 100)
        b.addAction(UIAction(handler: { [weak self] _ in
            self?._playbackMemo()
        }), for: .touchUpInside)
        return b
    }
    
    func _timeLabel() -> UILabel {
        let l = UILabel()
        l.text = "--:--:--"
        l.textAlignment = .center
        l.textColor = .black
        l.frame = CGRect(x: 0, y: 50, width: view.bounds.width, height: 50)
        return l
    }
}

extension ViewController: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        guard flag else {
            print("did finish recording failed")
            return
        }
        let timestamp = Date.timeIntervalSinceReferenceDate
        let fileName = "memo.caf"
        let finalURL = documentDir.appendingPathComponent(fileName)
        let recorderURL = recorder.url
        do {
            try FileManager.default.copyItem(at: recorderURL, to: finalURL)
        } catch let error {
            print("move file failed with error: \(error)")
        }
        print("did finish recording")
    }
}

extension ViewController: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        guard flag else { return }
        timer?.invalidate()
        timer = nil
        timeLabel.text = "--:--:--"
    }
}
