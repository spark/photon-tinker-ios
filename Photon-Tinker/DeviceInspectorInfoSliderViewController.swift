//
// Created by Raimundas Sakalauskas on 2019-06-06.
// Copyright (c) 2019 Particle. All rights reserved.
//

import Foundation

protocol DeviceInspectorInfoSliderViewDelegate: class {
    func infoSliderDidUpdateDevice()
    func infoSliderDidExpand()
    func infoSliderDidCollapse()
}

class DeviceInspectorInfoSliderViewController: UIViewController, UIGestureRecognizerDelegate, UITableViewDataSource, UITableViewDelegate {
    @IBOutlet weak var yConstraint: NSLayoutConstraint?
    @IBOutlet weak var heightConstraint: NSLayoutConstraint?
    
    @IBOutlet weak var collapsedContent: UIView!
    @IBOutlet weak var collapsedDeviceImageView: ScaledHeightImageView!
    @IBOutlet weak var collapsedDeviceImageYConstraint: NSLayoutConstraint!
    @IBOutlet weak var collapsedDeviceStateImageView: UIImageView!
    @IBOutlet weak var collapsedDeviceNameLabel: ParticleLabel!
    @IBOutlet weak var collapsedDeviceTypeLabel: DeviceTypeLabel!
    
    
    @IBOutlet weak var expandedContent: UIView!
    @IBOutlet weak var expandedDeviceImageView: ScaledHeightImageView!
    @IBOutlet weak var expandedDeviceImageViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var expandedDeviceStateImageView: UIImageView!
    @IBOutlet weak var expandedDeviceNameLabel: ParticleLabel!
    @IBOutlet weak var expandedDeviceStateLabel: ParticleLabel!
    @IBOutlet weak var expandedDeviceSignalLabel: ParticleLabel!
    @IBOutlet weak var expandedTableView: UITableView!
    @IBOutlet weak var expandedTableViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var expandedDeviceNotesTitleLabel: ParticleLabel!
    @IBOutlet weak var expandedDeviceNotesLabel: ParticleLabel!
    @IBOutlet weak var expandedPingButton: ParticleAlternativeButton!
    @IBOutlet weak var expandedPingActivityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var expandedSignalToggle: UISwitch!
    
    @IBOutlet var constraintsToShrinkOnSmallScreens: [NSLayoutConstraint]?

    weak var delegate: DeviceInspectorInfoSliderViewDelegate?

    let contentSwitchDistanceInPixels: CGFloat = 180
    let contentSwitchDelayInPixels: CGFloat = 100

    var device: ParticleDevice!
    var collapsedPosConstraint: CGFloat!
    var collapsedPosFrame: CGFloat!


    var panGestureRecognizer: UIPanGestureRecognizer!
    var startY: CGFloat = 0
    var collapsed: Bool = true
    var animating: Bool = false
    var beingDragged: Bool = false
    var displayLink: CADisplayLink!

    var details: [String: Any]!
    var detailsOrder: [String]!

    func setup(_ device: ParticleDevice!, yConstraint: NSLayoutConstraint, heightConstraint: NSLayoutConstraint) {
        self.yConstraint = yConstraint
        self.heightConstraint = heightConstraint

        self.device = device
        self.details = device.getInfoDetails()
        self.detailsOrder = device.getInfoDetailsOrder()

        internalInit()
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        if #available(iOS 13.0, *) {
            if self.responds(to: Selector("overrideUserInterfaceStyle")) {
                self.setValue(UIUserInterfaceStyle.light.rawValue, forKey: "overrideUserInterfaceStyle")
            }
        }
    }

    private func internalInit() {
        self.view.layer.borderWidth = 1
        self.view.layer.borderColor = UIColor(rgb: 0xD9D8D6).cgColor

        self.adjustConstraintPositions()
        self.yConstraint!.constant = collapsedPosConstraint

        self.setStyle()
        self.setContent()

        panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(panGestureTriggered))
        panGestureRecognizer.delegate = self
        panGestureRecognizer.isEnabled = true
        self.view.addGestureRecognizer(panGestureRecognizer)
    }

    private func setContent() {
        self.collapsedDeviceImageView.image = self.device.type.getImage()
        self.collapsedDeviceNameLabel.text = self.device.getName()
        self.collapsedDeviceTypeLabel.setDeviceType(self.device.type)

        self.expandedDeviceImageView.image = self.device.type.getImage()
        self.expandedDeviceNameLabel.text = self.device.getName()
        self.expandedDeviceStateLabel.text = self.device.isFlashing ? TinkerStrings.InfoSlider.DeviceStatus.Flashing : (self.device.connected ? TinkerStrings.InfoSlider.DeviceStatus.Online : TinkerStrings.InfoSlider.DeviceStatus.Offline)
        self.expandedDeviceSignalLabel.text = TinkerStrings.InfoSlider.SignalDevice
        self.expandedDeviceNotesTitleLabel.text = TinkerStrings.InfoSlider.Notes
        self.expandedDeviceNotesLabel.text = self.device.notes ?? TinkerStrings.InfoSlider.NotesPlaceholder

        self.expandedPingButton.setTitle(TinkerStrings.InfoSlider.Button.Ping, for: .normal, upperCase: false)

        self.expandedTableViewHeightConstraint.constant = CGFloat(self.detailsOrder.count * 30)

        self.expandedTableView.reloadData()

        ParticleUtils.animateOnlineIndicatorImageView(self.collapsedDeviceStateImageView, online: self.device.connected, flashing: self.device.isFlashing)
        ParticleUtils.animateOnlineIndicatorImageView(self.expandedDeviceStateImageView, online: self.device.connected, flashing: self.device.isFlashing)
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return detailsOrder.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: DeviceInfoSliderCell?
        let key = detailsOrder[indexPath.row]

        if let type = details[key] as? ParticleDeviceType {
            cell = tableView.dequeueReusableCell(withIdentifier: "DeviceInfoSliderTypeCell") as! DeviceInfoSliderCell
        } else {
            cell = tableView.dequeueReusableCell(withIdentifier: "DeviceInfoSliderCell") as! DeviceInfoSliderCell    
        }

        cell!.setup(title: key, value: details[key])
        return cell!
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 30
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let cell = tableView.cellForRow(at: indexPath) as! DeviceInfoSliderCell
        tableView.deselectRow(at: indexPath, animated: true)

        UIPasteboard.general.string = cell.valueLabel.text!

        RMessage.dismissActiveNotification()
        RMessage.showNotification(withTitle: TinkerStrings.InfoSlider.Prompt.ValueCopied.Title, subtitle: TinkerStrings.InfoSlider.Prompt.ValueCopied.Message.replacingOccurrences(of: "{{label}}", with: cell.titleLabel.text!), type: .success, customTypeName: nil, callback: nil)
    }

    private func setStyle() {
        if (ScreenUtils.isIPhone() && (ScreenUtils.getPhoneScreenSizeClass() <= .iPhone5)) {
            if let constraints = constraintsToShrinkOnSmallScreens {
                self.expandedDeviceImageViewHeightConstraint.constant = 120
                for constraint in constraints {
                    constraint.constant = constraint.constant / 2
                }
            }
        }

        self.expandedTableView.separatorColor = .clear

        self.collapsedDeviceNameLabel.setStyle(font: ParticleStyle.BoldFont, size: ParticleStyle.LargeSize, color: ParticleStyle.PrimaryTextColor)

        self.expandedDeviceNameLabel.setStyle(font: ParticleStyle.BoldFont, size: ParticleStyle.LargeSize, color: ParticleStyle.PrimaryTextColor)
        self.expandedDeviceStateLabel.setStyle(font: ParticleStyle.RegularFont, size: ParticleStyle.RegularSize, color: ParticleStyle.PrimaryTextColor)
        self.expandedDeviceSignalLabel.setStyle(font: ParticleStyle.RegularFont, size: ParticleStyle.RegularSize, color: ParticleStyle.PrimaryTextColor)

        self.expandedDeviceNotesTitleLabel.setStyle(font: ParticleStyle.BoldFont, size: ParticleStyle.RegularSize, color: ParticleStyle.PrimaryTextColor)
        self.expandedDeviceNotesLabel.setStyle(font: ParticleStyle.RegularFont, size: ParticleStyle.RegularSize, color: ParticleStyle.DetailsTextColor)

        self.expandedPingButton.setStyle(font: ParticleStyle.BoldFont, size: ParticleStyle.RegularSize)
        self.expandedPingButton.layer.shadowColor = UIColor.clear.cgColor
        self.expandedPingButton.contentEdgeInsets = UIEdgeInsets(top: 5, left: 10, bottom: 5, right: 10)

        self.expandedPingActivityIndicator.hidesWhenStopped = true
    }

    func update() {
        self.setContent()
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()

        self.adjustConstraintPositions()

        //if safe area insets change during idle state
        if !animating && !beingDragged, let yConstraint = yConstraint {
            if (yConstraint.constant > 0) {
                yConstraint.constant = collapsedPosConstraint
            }
        }

        let progress = min(self.contentSwitchDistanceInPixels, self.collapsedPosFrame - self.view.superview!.frame.origin.y - self.contentSwitchDelayInPixels) / self.contentSwitchDistanceInPixels
        updateState(progress: progress)
    }

    private func updateState(progress: CGFloat) {
        self.view.layer.cornerRadius = 10 * progress

        self.collapsedContent.alpha = 1 - progress
        self.expandedContent.alpha = progress
    }


    private func adjustConstraintPositions() {
        if #available(iOS 11, *), let superview = self.view.superview?.superview, let heightConstraint = self.heightConstraint {
            collapsedPosConstraint = UIScreen.main.bounds.height - 100
            collapsedPosFrame = collapsedPosConstraint

            heightConstraint.constant = self.view.safeAreaInsets.bottom + 11

            collapsedPosConstraint! -= (superview.safeAreaInsets.bottom + superview.safeAreaInsets.top)
            collapsedPosFrame = collapsedPosConstraint + superview.safeAreaInsets.top
            
            collapsedDeviceImageYConstraint.constant = superview.safeAreaInsets.bottom / 4
            
        } else if let heightConstraint = self.heightConstraint {
            collapsedPosConstraint = UIScreen.main.bounds.height - 120 //top bar included
            collapsedPosFrame = collapsedPosConstraint

            heightConstraint.constant = -9
            
            collapsedDeviceImageYConstraint.constant = 0
        }
    }


    @objc
    func panGestureTriggered(_ recognizer:UIPanGestureRecognizer) {
        guard let yConstraint = self.yConstraint else {
            return
        }

        switch (recognizer.state) {
            case.began:
                self.beingDragged = true
                let pos = recognizer.translation(in: self.view)
                self.startY = yConstraint.constant
            case .changed:
                let change = recognizer.translation(in: self.view)

                var offset = startY + change.y
                if (offset >= collapsedPosConstraint) {
                    //if we reach end of motion, move initial offset so that when user
                    //starts scrolling in different direction he gets instant feedback
                    self.startY = collapsedPosConstraint - change.y
                    offset = collapsedPosConstraint
                } else if (offset <= 0) {
                    //if we reach end of motion, move initial offset so that when user
                    //starts scrolling in different direction he gets instant feedback
                    self.startY = 0 - change.y
                    offset = 0
                }

                yConstraint.constant = offset

                self.view.setNeedsLayout()
                self.view.layoutIfNeeded()
            case .failed:
                fallthrough
            case.cancelled:
                fallthrough
            case .ended:
                self.beingDragged = false

                let change = recognizer.translation(in: self.view)
                let velocity = recognizer.velocity(in: self.view)

                if (collapsed) {
                    if (-1 * change.y > collapsedPosConstraint / 4) || (-1 * (change.y + velocity.y) > collapsedPosConstraint) {
                        expand()
                    } else {
                        collapse()
                    }
                } else {
                    if (change.y > collapsedPosConstraint / 4) || ((change.y + velocity.y) > collapsedPosConstraint) {
                        collapse()
                    } else {
                        expand()
                    }
                }

            case.possible:
                //do nothing
                break
        }
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return !animating
    }


    @IBAction func expandTapped(_ sender: Any) {
        if collapsed && !animating && !beingDragged {
            self.expand()
        }
    }
    
    func expand() {
        guard let yConstraint = self.yConstraint else {
            return
        }

        animating = true

        self.view.superview?.layoutIfNeeded()
        let duration:Double = Double(yConstraint.constant / self.collapsedPosConstraint * 0.25)
        yConstraint.constant = 0

        animateStateChange(duration: duration, collapsed: false)
    }

    @IBAction func collapseTapped(_ sender: Any) {
        if !collapsed && !animating && !beingDragged {
            self.collapse()
        }
    }
    
    func collapse() {
        guard let yConstraint = self.yConstraint else {
            return
        }

        animating = true

        self.device.signal(false)
        self.expandedSignalToggle.setOn(false, animated: true)

        self.view.superview?.layoutIfNeeded()
        let duration:Double = Double((self.collapsedPosConstraint - yConstraint.constant) / self.collapsedPosConstraint * 0.25)
        yConstraint.constant = self.collapsedPosConstraint

        animateStateChange(duration: duration, collapsed: true)
    }

    private func animateStateChange(duration: Double, collapsed: Bool) {
        displayLink = CADisplayLink(target: self, selector: #selector(animationDidUpdate))
        displayLink.add(to: .main, forMode: RunLoop.Mode.default)

        UIView.animate(withDuration: duration, delay:0, options:.curveEaseOut, animations: { () -> Void in
            self.view.superview?.superview?.layoutIfNeeded()
        }, completion: { [weak self] b in
            self?.displayLink.invalidate()
            self?.displayLink = nil
            self?.animating = false
            self?.collapsed = collapsed
            if (collapsed) {
                self?.delegate?.infoSliderDidCollapse()
            } else {
                self?.delegate?.infoSliderDidExpand()
            }
        })
    }

    @objc func animationDidUpdate(displayLink: CADisplayLink) {
        let presentationLayer = self.view.superview!.layer.presentation() as! CALayer

        let progress = min(self.contentSwitchDistanceInPixels, self.collapsedPosFrame - presentationLayer.frame.origin.y - self.contentSwitchDelayInPixels) / self.contentSwitchDistanceInPixels
        self.updateState(progress: progress)
    }

    @IBAction func signalSwitchValueChanged(_ sender: Any) {
        if expandedSignalToggle.isOn {
            self.device.signal(true)
        } else {
            self.device.signal(false)
        }
    }

    @IBAction func pingButtonTapped(_ sender: Any) {
        self.expandedPingActivityIndicator.startAnimating()
        self.expandedPingButton.isHidden = true

        RMessage.dismissActiveNotification()
        RMessage.showNotification(withTitle: TinkerStrings.InfoSlider.Prompt.PingingDevice.Title, subtitle: TinkerStrings.InfoSlider.Prompt.PingingDevice.Message, type: .warning, customTypeName: nil, callback: nil)

        self.device.ping { [weak self] connected, error in
            if let self = self {
                DispatchQueue.main.async {
                    self.expandedPingActivityIndicator.stopAnimating()
                    self.expandedPingButton.isHidden = false
                }
            }

            if error != nil || !connected {
                RMessage.dismissActiveNotification()
                RMessage.showNotification(withTitle: TinkerStrings.InfoSlider.Error.PingingFailed.Title, subtitle: TinkerStrings.InfoSlider.Error.PingingFailed.Message, type: .error, customTypeName: nil, duration: -1, callback: nil)
            } else {
                RMessage.dismissActiveNotification()
                RMessage.showNotification(withTitle: TinkerStrings.InfoSlider.Prompt.PingingSuccessful.Title, subtitle: TinkerStrings.InfoSlider.Prompt.PingingSuccessful.Message, type: .success, customTypeName: nil, callback: nil)
            }
        }
    }

    @IBAction func renameButtonTapped(_ sender: Any) {
        var vc = DeviceInspectorTextInputViewController.storyboardViewController()
        vc.setup(caption: TinkerStrings.InfoSlider.Name, multiline: false, value: self.device.name, onCompletion: {
            [weak self] value in
            if let self = self {
                self.device.rename(value) { error in
                    if let error = error {
                        RMessage.showNotification(withTitle: TinkerStrings.InfoSlider.Error.RenamingDeviceFailed.Title, subtitle: TinkerStrings.InfoSlider.Error.RenamingDeviceFailed.Message.replacingOccurrences(of: "{{error}}", with: error.localizedDescription), type: .error, customTypeName: nil, duration: -1, callback: nil)
                        vc.resume(animated: true)
                    } else {
                        self.delegate?.infoSliderDidUpdateDevice()
                        vc.dismiss(animated: true)
                    }
                }
            }
        })
        self.present(vc, animated: true)

    }

    
    @IBAction func editNotesButtonTapped(_ sender: Any) {
        var vc = DeviceInspectorTextInputViewController.storyboardViewController()
        vc.setup(caption: TinkerStrings.InfoSlider.Notes, multiline: true, value: self.device.notes, onCompletion: {
            [weak self] value in
            if let self = self {
                self.device.setNotes(value) { error in
                    if let error = error {
                        RMessage.showNotification(withTitle: TinkerStrings.InfoSlider.Error.EditingNotesFailed.Title, subtitle: TinkerStrings.InfoSlider.Error.EditingNotesFailed.Message.replacingOccurrences(of: "{{error}}", with: error.localizedDescription), type: .error, customTypeName: nil, duration: -1, callback: nil)
                        vc.resume(animated: true)
                    } else {
                        self.delegate?.infoSliderDidUpdateDevice()
                        vc.dismiss(animated: true)
                    }
                }
            }

        })
        self.present(vc, animated: true)
    }
}
