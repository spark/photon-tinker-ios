//
// Created by Raimundas Sakalauskas on 9/20/18.
// Copyright (c) 2018 Particle. All rights reserved.
//

import UIKit
import AVFoundation
import AVKit


class Gen3SetupControlPanelPrepareForPairingViewController: Gen3SetupViewController, Storyboardable {

    internal var videoPlayer: AVPlayer?
    internal var layer: AVPlayerLayer?
    internal var defaultVideo : AVPlayerItem?

    internal var defaultVideoURL: URL!
    internal var isSOM:Bool!

    @IBOutlet weak var textLabel: ParticleLabel!
    @IBOutlet weak var videoView: UIControl!
    @IBOutlet weak var signalSwitch: UISwitch!
    @IBOutlet weak var signalLabel: ParticleLabel!
    @IBOutlet weak var signalWarningLabel: ParticleLabel!
    
    private var device: ParticleDevice!

    override var customTitle: String {
        return Gen3SetupStrings.ControlPanel.PrepareForPairing.Title
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setContent()
    }


    func setup(device: ParticleDevice!) {
        self.device = device
        self.deviceName = device.name!
        self.deviceType = device.type

        self.isSOM = (self.deviceType! == ParticleDeviceType.aSeries || self.deviceType! == ParticleDeviceType.bSeries || self.deviceType! == ParticleDeviceType.xSeries)
    }


    override func setStyle() {
        videoView.backgroundColor = .clear
        videoView.layer.cornerRadius = 5
        videoView.clipsToBounds = true

        textLabel.setStyle(font: ParticleStyle.RegularFont, size: ParticleStyle.RegularSize, color: ParticleStyle.PrimaryTextColor)
        signalLabel.setStyle(font: ParticleStyle.BoldFont, size: ParticleStyle.RegularSize, color: ParticleStyle.PrimaryTextColor)
        signalWarningLabel.setStyle(font: ParticleStyle.RegularFont, size: ParticleStyle.SmallSize, color: ParticleStyle.PrimaryTextColor)
    }


    override func setContent() {
        textLabel.text = Gen3SetupStrings.ControlPanel.PrepareForPairing.Text
        signalLabel.text = Gen3SetupStrings.ControlPanel.PrepareForPairing.Signal
        signalWarningLabel.text = Gen3SetupStrings.ControlPanel.PrepareForPairing.SignalWarning


        initializeVideoPlayerWithVideo(videoFileName: "prepare_for_pairing")
        videoView.addTarget(self, action: #selector(videoViewTapped), for: .touchUpInside)

        view.setNeedsLayout()
        view.layoutIfNeeded()
    }



    @objc public func videoViewTapped(sender: UIControl) {
// TODO: uncomment this, but figure out how to exit fullscreen video mode if device enters listening mode while it is visible (otherwise flow stops)
//        let player = AVPlayer(url: defaultVideoURL)
//
//        let playerController = AVPlayerViewController()
//        playerController.player = player
//        present(playerController, animated: true) {
//            player.play()
//        }

    }

    @IBAction func signalSwitchValueChanged(_ sender: Any) {
        if signalSwitch.isOn {
            self.device.signal(true)
        } else {
            self.device.signal(false)
        }
    }



    func initializeVideoPlayerWithVideo(videoFileName: String) {
        if (self.videoPlayer != nil) {
            return
        }

        // Create a new AVPlayerItem with the asset and an
        // array of asset keys to be automatically loaded
        let defaultVideoString:String? = Bundle.main.path(forResource: videoFileName, ofType: "mov")
        defaultVideoURL = URL(fileURLWithPath: defaultVideoString!)
        defaultVideo = AVPlayerItem(url: defaultVideoURL)
        
        self.videoPlayer = AVPlayer(playerItem: defaultVideo)
        layer = AVPlayerLayer(player: videoPlayer)
        layer!.frame = videoView.bounds
        layer!.videoGravity = AVLayerVideoGravity.resizeAspect

        NSLog("initializing layer?")
        videoView.layer.addSublayer(layer!)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        setVideoLoopObserver()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        layer?.frame = videoView.bounds
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        self.device.signal(false)
        self.signalSwitch.setOn(false, animated: false)

        desetVideoLoopObserver()
    }

    func desetVideoLoopObserver() {
        self.videoPlayer?.pause()
        NotificationCenter.default.removeObserver(self.videoPlayer?.currentItem)
    }
    

    
    func setVideoLoopObserver() {
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: self.videoPlayer?.currentItem, queue: .main) { _ in
            self.videoPlayer?.seek(to: CMTime.zero)
            self.videoPlayer?.play()
        }

        self.videoPlayer?.seek(to: CMTime.zero)
        self.videoPlayer?.play()
    }


}
