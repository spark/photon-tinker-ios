//
// Created by Raimundas Sakalauskas on 2019-06-14.
// Copyright (c) 2019 Particle. All rights reserved.
//

import Foundation

class DeviceInspectorTextInputViewController: UIViewController, Fadeable, Storyboardable, UITextFieldDelegate {

    
    var isBusy: Bool = false
    @IBOutlet var viewsToFade: [UIView]?
    
    @IBOutlet weak var titleLabel: ParticleLabel!
    @IBOutlet weak var inputTextField: ParticleTextField!
    @IBOutlet weak var inputTextArea: ParticleTextView!
    @IBOutlet weak var saveButton: ParticleButton!
    @IBOutlet weak var closeButton: UIButton!
    @IBOutlet weak var promptBackground: UIView!
    @IBOutlet weak var inputFrameView: UIView!
    @IBOutlet weak var viewCenterYConstraint: NSLayoutConstraint!
    

    private var onCompletion: ((String) -> ())!
    private var multiline: Bool!
    private var caption: String!
    private var inputValue: String!
    private var blurBackground:Bool!

    init() {
        super.init(nibName: nil, bundle: nil)

        self.modalTransitionStyle = .crossDissolve
        self.modalPresentationStyle = .overFullScreen
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        self.modalTransitionStyle = .crossDissolve
        self.modalPresentationStyle = .overFullScreen
    }

    func setup(caption: String, multiline: Bool, value: String? = "", blurBackground: Bool = true, onCompletion: @escaping (String) -> ()) {
        self.multiline = multiline
        self.caption = caption
        self.inputValue = value
        self.onCompletion = onCompletion
        self.blurBackground = blurBackground
    }

    override func viewDidLoad() {
        super.viewDidLoad()


        //make transparent
        self.view.backgroundColor = .clear

        if (self.blurBackground) {
            //add blur
            let blurEffect = UIBlurEffect(style: .dark)
            let blurEffectView = UIVisualEffectView(effect: blurEffect)
            blurEffectView.frame = self.view.bounds
            blurEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            self.view.insertSubview(blurEffectView, at: 0)
        } else {
            //add fade
            let fadeView = UIView(frame: self.view.bounds)
            fadeView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            fadeView.backgroundColor = UIColor.black.withAlphaComponent(0.7)
            self.view.insertSubview(fadeView, at: 0)
        }

        self.inputTextField.delegate = self

        self.setStyle()
        self.setContent()
    }

    private func setStyle() {
        self.promptBackground.layer.masksToBounds = false
        self.promptBackground.layer.cornerRadius = 5
        self.promptBackground.layer.applySketchShadow(color: UIColor(rgb: 0x000000), alpha: 0.3, x: 0, y: 2, blur: 4, spread: 0)

        self.inputTextField.borderStyle = .none

        self.inputTextField.backgroundColor = .clear
        self.inputTextArea.backgroundColor = .clear

        self.inputFrameView.layer.cornerRadius = 3
        self.inputFrameView.layer.borderColor = UIColor(rgb: 0xD9D8D6).cgColor
        self.inputFrameView.layer.borderWidth = 1


        self.titleLabel.setStyle(font: ParticleStyle.BoldFont, size: ParticleStyle.LargeSize, color: ParticleStyle.PrimaryTextColor)
        self.inputTextField.setStyle(font: ParticleStyle.RegularFont, size: ParticleStyle.RegularSize, color: ParticleStyle.PrimaryTextColor)
        self.inputTextArea.setStyle(font: ParticleStyle.RegularFont, size: ParticleStyle.RegularSize, color: ParticleStyle.PrimaryTextColor)

        self.saveButton.setStyle(font: ParticleStyle.BoldFont, size: ParticleStyle.RegularSize)
    }

    private func setContent() {
        //set visibility and value
        self.titleLabel.text = caption
        if (multiline) {
            self.inputTextArea.isHidden = false
            self.inputTextField.superview?.isHidden = true

            self.inputTextArea.placeholderText = ""
            self.inputTextArea.text = inputValue
        } else {
            self.inputTextArea.isHidden = true
            self.inputTextField.superview?.isHidden = false

            self.inputTextField.placeholder = ""
            self.inputTextField.text = inputValue
        }
        self.saveButton.setTitle(TinkerStrings.Action.Save, for: .normal)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)

        if (multiline) {
            self.inputTextArea.becomeFirstResponder()
            self.inputTextArea.selectAll(nil)
        } else {
            self.inputTextField.becomeFirstResponder()
            self.inputTextField.selectAll(nil)
        }

    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.saveTapped(self)
        return false
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
    }


    @IBAction func saveTapped(_ sender: Any) {
        self.view.endEditing(true)
        self.fade(animated: true)
        if (multiline){
            self.onCompletion(self.inputTextArea.text)
        } else {
            self.onCompletion(self.inputTextField.text ?? "")
        }
    }
    
    @IBAction func closeTapped(_ sender: Any) {
        self.view.endEditing(true)
        self.dismiss(animated: true, completion: nil)
    }

    @objc func keyboardWillShow(notification: NSNotification) {
        if let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
            let keyboardHeight = keyboardSize.height
            viewCenterYConstraint.constant = keyboardHeight / 2
            UIView.animate(withDuration: 0.25) { () -> Void in
                self.view.layoutIfNeeded()
            }
        }
    }

    @objc func keyboardWillHide(notification: NSNotification) {
        viewCenterYConstraint.constant = 0
        UIView.animate(withDuration: 0.25) { () -> Void in
            self.view.layoutIfNeeded()
        }
    }
}
