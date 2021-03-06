//
// Created by Raimundas Sakalauskas on 9/20/18.
// Copyright (c) 2018 Particle. All rights reserved.
//

import UIKit

class Gen3SetupGetCommissionerReadyViewController: Gen3SetupGetReadyViewController {

    private var callback: (() -> ())!

    func setup(didPressReady: @escaping () -> (), deviceType: ParticleDeviceType!, networkName: String) {
        self.callback = didPressReady
        self.deviceType = deviceType
        self.networkName = networkName

        self.isSOM = false
    }

    @IBAction override func nextButtonTapped(_ sender: Any) {
        callback()
    }
    
    override func setStyle() {
        videoView.layer.cornerRadius = 5
        videoView.clipsToBounds = true
        
        titleLabel.setStyle(font: ParticleStyle.RegularFont, size: ParticleStyle.LargeSize, color: ParticleStyle.PrimaryTextColor)

        continueButton.setStyle(font: ParticleStyle.BoldFont, size: ParticleStyle.RegularSize)
    }

    override func setContent() {
        titleLabel.text = Gen3SetupStrings.GetCommissionerReady.Title


        continueButton.setTitle(Gen3SetupStrings.GetCommissionerReady.Button, for: .normal)

        view.setNeedsLayout()
        view.layoutIfNeeded()

        videoView.addTarget(self, action: #selector(videoViewTapped), for: .touchUpInside)

        initializeVideoPlayerWithVideo(videoFileName: "commissioner_to_listening_mode")
    }
}
