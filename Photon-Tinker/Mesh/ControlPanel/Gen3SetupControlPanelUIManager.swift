//
// Created by Raimundas Sakalauskas on 2019-03-14.
// Copyright (c) 2019 Particle. All rights reserved.
//

import Foundation
import UIKit

class Gen3SetupControlPanelUIManager: Gen3SetupUIBase {

    private var currentAction: Gen3SetupControlPanelCellType?

    var controlPanelManager: Gen3SetupControlPanelFlowManager! {
        return self.flowRunner as! Gen3SetupControlPanelFlowManager
    }

    public private(set) var device: ParticleDevice!

    func setDevice(_ device: ParticleDevice, context: Gen3SetupContext? = nil) {
        self.device = device
        self.log("Setting device: \(device)")
        if let serial = device.serialNumber, let mobileSecret = device.mobileSecret {
            self.targetDeviceDataMatrix = Gen3SetupDataMatrix(device: device)!
        } else if (device.is3rdGen()) {
            fatalError("Device Serial Number (\(device.serialNumber)) or Mobile Secret (\(device.mobileSecret)) is missing for device (\(device).")
        }

        self.flowRunner = Gen3SetupControlPanelFlowManager(delegate: self, context: context)

        self.flowRunner.context.targetDevice.deviceId = self.device.id
        self.flowRunner.context.targetDevice.name = self.device.getName()
        self.flowRunner.context.targetDevice.notes = self.device.notes
        self.flowRunner.context.targetDevice.networkRole = self.device.networkRole
    }

    override internal func setupInitialViewController() {
        self.currentStepType = nil

        let rootVC = Gen3SetupControlPanelRootViewController.loadedViewController()
        rootVC.setup(device: self.device, context: controlPanelManager.context, didSelectAction: self.controlPanelRootViewCompleted)
        rootVC.ownerStepType = nil
        self.embededNavigationController.setViewControllers([rootVC], animated: false)
    }


    private func showControlPanelRootView() {
        DispatchQueue.main.async {
            if (!self.rewindTo(Gen3SetupControlPanelRootViewController.self)) {
                let rootVC = Gen3SetupControlPanelRootViewController.loadedViewController()
                rootVC.setup(device: self.device, context: self.controlPanelManager.context, didSelectAction: self.controlPanelRootViewCompleted)
                rootVC.ownerStepType = nil
                self.embededNavigationController.setViewControllers([rootVC], animated: true)
            }
        }
    }

    func controlPanelRootViewCompleted(action: Gen3SetupControlPanelCellType) {
        currentAction = action

        switch action {
            case .documentation:
                showDocumentation()
            case .unclaim:
                showUnclaim()
            case .mesh:
                controlPanelManager.actionPairMesh()
            case .cellular:
                controlPanelManager.actionPairCellular()
            case .ethernet:
                controlPanelManager.actionPairEthernet()
            case .wifi:
                controlPanelManager.actionPairWifi()
            case .notes:
                editNotes()
            case .name:
                rename()
            default:
                fatalError("cellType \(action) should never be returned")
        }
    }

    func rename() {
        var vc = DeviceInspectorTextInputViewController.storyboardViewController()
        vc.setup(caption: "Name", multiline: false, value: self.device.name, blurBackground: false, onCompletion: {
            [weak self] value in
            if let self = self {
                self.device.rename(value) { error in
                    if let error = error {
                        RMessage.showNotification(withTitle: "Error", subtitle: "Error renaming device: \(error.localizedDescription)", type: .error, customTypeName: nil, callback: nil)
                        vc.resume(animated: true)
                    } else {
                        self.controlPanelManager.context.targetDevice.name = self.device.getName()
                        let root = self.embededNavigationController!.topViewController as! Gen3SetupViewController
                        root.resume(animated: false)
                        vc.dismiss(animated: true)
                    }
                }
            }
        })
        self.present(vc, animated: true)

    }


    func editNotes() {
        var vc = DeviceInspectorTextInputViewController.storyboardViewController()
        vc.setup(caption: "Notes", multiline: true, value: self.device.notes, blurBackground: false, onCompletion: {
            [weak self] value in
            if let self = self {
                self.device.setNotes(value) { error in
                    if let error = error {
                        RMessage.showNotification(withTitle: "Error", subtitle: "Error editing notes device: \(error.localizedDescription)", type: .error, customTypeName: nil, callback: nil)
                        vc.resume(animated: true)
                    } else {
                        self.controlPanelManager.context.targetDevice.notes = self.device.notes
                        let root = self.embededNavigationController!.topViewController as! Gen3SetupViewController
                        root.resume(animated: false)
                        vc.dismiss(animated: true)
                    }
                }
            }

        })
        self.present(vc, animated: true)
    }

    private func showDocumentation() {
        DispatchQueue.main.async {
            let wifiVC = Gen3SetupControlPanelDocumentationViewController.loadedViewController()
            wifiVC.setup(self.device)
            wifiVC.ownerStepType = nil
            self.embededNavigationController.pushViewController(wifiVC, animated: true)
        }
    }

    private func showUnclaim() {
        self.currentAction = .unclaim
        DispatchQueue.main.async {
            let unclaimVC = Gen3SetupControlPanelUnclaimViewController.loadedViewController()
            unclaimVC.setup(deviceName: self.device.name!, callback: self.unclaimCompleted)
            unclaimVC.ownerStepType = nil
            self.embededNavigationController.pushViewController(unclaimVC, animated: true)
        }
    }

    func unclaimCompleted(unclaimed: Bool) {
        if (unclaimed) {
            self.unclaim()
        }
    }

    private func unclaim() {
        self.device.unclaim() { (error: Error?) -> Void in
            if let error = error as? NSError {
                self.showNetworkError(error: error)
            } else {
                if let callback = self.callback {
                    callback(Gen3SetupFlowResult.unclaimed, nil)
                }
                self.terminate()
            }
        }
    }

    internal func showNetworkError(error: NSError) {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: Gen3SetupStrings.Prompt.ErrorTitle,
                    message: error.localizedDescription,
                    preferredStyle: .alert)

            alert.addAction(UIAlertAction(title: Gen3SetupStrings.Action.Cancel, style: .cancel) { action in
                (self.embededNavigationController.topViewController! as! Fadeable).resume(animated: true)
            })

            alert.addAction(UIAlertAction(title: Gen3SetupStrings.Action.Retry, style: .default) { action in
                self.unclaim()
            })

            self.present(alert, animated: true)
        }
    }




    private func showControlPanelWifiView() {
        self.currentAction = .wifi
        DispatchQueue.main.async {
            if (!self.rewindTo(Gen3SetupControlPanelWifiViewController.self)) {
                let wifiVC = Gen3SetupControlPanelWifiViewController.loadedViewController()
                wifiVC.setup(device: self.device, context: self.controlPanelManager.context, didSelectAction: self.controlPanelWifiViewCompleted)
                wifiVC.ownerStepType = nil
                self.embededNavigationController.pushViewController(wifiVC, animated: true)
            }
        }
    }

    func controlPanelWifiViewCompleted(action: Gen3SetupControlPanelCellType) {
        currentAction = action
        switch action {
            case .actionNewWifi:
                controlPanelManager.actionNewWifi()
            case .actionManageWifi:
                controlPanelManager.actionManageWifi()
            case .wifi:
                controlPanelManager.actionPairWifi()
            default:
                fatalError("cellType \(action) should never be returned")
        }
    }

    private func showControlPanelCellularView() {
        self.currentAction = .cellular
        DispatchQueue.main.async {
            if (!self.rewindTo(Gen3SetupControlPanelCellularViewController.self)) {
                let cellularVC = Gen3SetupControlPanelCellularViewController.loadedViewController()
                cellularVC.setup(device: self.device, context: self.controlPanelManager.context, didSelectAction: self.controlPanelCellularViewCompleted)
                cellularVC.ownerStepType = nil
                self.embededNavigationController.pushViewController(cellularVC, animated: true)
            }
        }
    }

    func controlPanelCellularViewCompleted(action: Gen3SetupControlPanelCellType) {
        currentAction = action
        switch action {
            case .actionChangeSimStatus:
                if controlPanelManager.context.targetDevice.sim!.status! == .activate {
                    controlPanelManager.context.targetDevice.setSimActive = false
                    controlPanelManager.actionToggleSimStatus()
                } else if (controlPanelManager.context.targetDevice.sim!.status! == .inactiveDataLimitReached) {
                    controlPanelManager.context.targetDevice.setSimActive = true
                    controlPanelManager.actionToggleSimStatus()
                } else {
                    controlPanelManager.context.targetDevice.setSimActive = true
                    controlPanelManager.actionToggleSimStatus()
                }
            case .actionChangeDataLimit:
                controlPanelManager.actionChangeDataLimit()
            default:
                fatalError("cellType \(action) should never be returned")
        }
    }

    private func showControlPanelMeshView() {
        self.currentAction = .mesh
        DispatchQueue.main.async {
            if (!self.rewindTo(Gen3SetupControlPanelMeshViewController.self)) {
                let meshVC = Gen3SetupControlPanelMeshViewController.loadedViewController()
                meshVC.setup(device: self.device, context: self.controlPanelManager.context, didSelectAction: self.controlPanelMeshViewCompleted)
                meshVC.ownerStepType = nil
                self.embededNavigationController.pushViewController(meshVC, animated: true)
            }
        }
    }

    func controlPanelMeshViewCompleted(action: Gen3SetupControlPanelCellType) {
        currentAction = action
        switch action {
            case .actionAddToMeshNetwork:
                controlPanelManager.context.userSelectedToSetupMesh = true
                controlPanelManager.actionAddToMesh()
            case .actionLeaveMeshNetwork:
                controlPanelManager.context.targetDevice.networkRole = nil
                controlPanelManager.context.userSelectedToLeaveNetwork = true
                controlPanelManager.actionLeaveMeshNetwork()
            case .mesh:
                controlPanelManager.actionPairMesh()
            case .actionPromoteToGateway:
                break
            case .actionDemoteFromGateway:
                break

            default:
                fatalError("cellType \(action) should never be returned")
        }
    }

    private func showControlPanelEthernetView() {
        self.currentAction = .ethernet
        DispatchQueue.main.async {
            if (!self.rewindTo(Gen3SetupControlPanelEthernetViewController.self)) {
                let ethernetVC = Gen3SetupControlPanelEthernetViewController.loadedViewController()
                ethernetVC.setup(device: self.device, context: self.controlPanelManager.context, didSelectAction: self.controlPanelEthernetViewCompleted)
                ethernetVC.ownerStepType = nil
                self.embededNavigationController.pushViewController(ethernetVC, animated: true)
            }
        }
    }

    func controlPanelEthernetViewCompleted(action: Gen3SetupControlPanelCellType) {
        currentAction = action
        switch action {
            case .actionChangePinsStatus:
                if (controlPanelManager.context.targetDevice.ethernetDetectionFeature!) {
                    controlPanelManager.context.targetDevice.enableEthernetDetectionFeature = false
                    controlPanelManager.actionToggleEthernetFeature()
                } else {
                    controlPanelManager.context.targetDevice.enableEthernetDetectionFeature = true
                    controlPanelManager.actionToggleEthernetFeature()
                }
            default:
                fatalError("cellType \(action) should never be returned")
        }
    }

    private func showPrepareForPairingView() {
        DispatchQueue.main.async {
            if (!self.rewindTo(Gen3SetupControlPanelPrepareForPairingViewController.self)) {
                let prepareVC = Gen3SetupControlPanelPrepareForPairingViewController.loadedViewController()
                prepareVC.setup(device: self.device)
                prepareVC.ownerStepType = nil
                self.embededNavigationController.pushViewController(prepareVC, animated: true)
            }
        }
    }

    override func gen3SetupDidCompleteControlPanelFlow(_ sender: Gen3SetupStep) {
        switch currentAction! {
            case .actionNewWifi,
                 .actionChangePinsStatus,
                 .actionChangeSimStatus, .actionChangeDataLimit,
                 .actionLeaveMeshNetwork:
                showFlowCompleteView()
            case .mesh:
                showControlPanelMeshView()
            case .ethernet:
                showControlPanelEthernetView()
            case .wifi:
                showControlPanelWifiView()
            case .cellular:
                showControlPanelCellularView()
            case .actionManageWifi:
                showManageWifiView()
            case .actionAddToMeshNetwork:
                controlPanelManager.context.userSelectedToCreateNetwork = nil
                controlPanelManager.context.selectedNetworkMeshInfo = nil
                controlPanelManager.context.selectedNetworkPassword = nil

                controlPanelManager.context.newNetworkName = nil
                controlPanelManager.context.newNetworkPassword = nil
                controlPanelManager.context.newNetworkId = nil


                currentAction = .mesh
                controlPanelManager.actionPairMesh()
            default:
                break;
        }
    }

    private func showFlowCompleteView() {
        DispatchQueue.main.async {
            if (!self.rewindTo(Gen3SetupControlPanelFlowCompleteViewController.self)) {
                let flowCompleteVC = Gen3SetupControlPanelFlowCompleteViewController.loadedViewController()
                flowCompleteVC.setup(didFinishScreen: self.flowCompleteViewCompleted, deviceType: self.device.type, deviceName: self.device.name!, action: self.currentAction!, context: self.controlPanelManager.context)
                flowCompleteVC.ownerStepType = nil
                self.embededNavigationController.pushViewController(flowCompleteVC, animated: true)
            }
        }
    }

    internal func flowCompleteViewCompleted() {
        switch currentAction! {
            case .actionNewWifi:
                controlPanelManager.context.selectedWifiNetworkInfo = nil

                currentAction = .wifi
                controlPanelManager.actionPairWifi()
            case .actionChangeSimStatus, .actionChangeDataLimit:
                controlPanelManager.context.targetDevice.setSimDataLimit = nil
                controlPanelManager.context.targetDevice.setSimActive = nil

                currentAction = .cellular
                controlPanelManager.actionPairCellular()
            case .actionChangePinsStatus:
                controlPanelManager.context.targetDevice.enableEthernetDetectionFeature = nil

                currentAction = .ethernet
                controlPanelManager.actionPairEthernet()
            case .actionLeaveMeshNetwork:
                controlPanelManager.context.userSelectedToLeaveNetwork = nil

                currentAction = .mesh
                controlPanelManager.actionPairMesh()
            default:
                break;
        }
    }

    override func gen3SetupDidRequestToShowInfo(_ sender: Gen3SetupStep) {
        currentStepType = type(of: sender)
        let infoType = (sender as! StepShowInfo).infoType

        if infoType == .joinerFlow {
            if (!self.rewindTo(Gen3SetupInfoJoinerViewController.self)) {
                let infoVC = Gen3SetupInfoJoinerViewController.loadedViewController()
                infoVC.allowBack = true
                infoVC.ownerStepType = self.currentStepType
                infoVC.setup(didFinishScreen: self.infoViewCompleted, setupMesh: self.flowRunner.context.userSelectedToSetupMesh, deviceType: self.flowRunner.context.targetDevice.type!)
                self.embededNavigationController.pushViewController(infoVC, animated: true)
            }
        } else {
            if controlPanelManager.context.targetDevice.sim!.status! == .activate {
                showDeactivateSimInfoView()
            } else if (controlPanelManager.context.targetDevice.sim!.status! == .inactiveDataLimitReached) {
                showResumeSimInfoView()
            } else {
                showActivateSimInfoView()
            }
        }
    }

    func infoViewCompleted() {
        self.flowRunner.setInfoDone()
    }

    private func showManageWifiView() {
        DispatchQueue.main.async {
            if let manageWifiView = self.embededNavigationController.topViewController as? Gen3SetupControlPanelManageWifiViewController {
                manageWifiView.setNetworks(networks: self.controlPanelManager.context.targetDevice.knownWifiNetworks!)
            }

            if (!self.rewindTo(Gen3SetupControlPanelManageWifiViewController.self)) {
                let manageWifiView = Gen3SetupControlPanelManageWifiViewController.loadedViewController()
                manageWifiView.setup(didSelectNetwork: self.selectKnownWifiNetworkViewCompleted)
                manageWifiView.setNetworks(networks: self.controlPanelManager.context.targetDevice.knownWifiNetworks!)
                manageWifiView.ownerStepType = nil
                self.embededNavigationController.pushViewController(manageWifiView, animated: true)
            }
        }
    }

    internal func selectKnownWifiNetworkViewCompleted(network: Gen3SetupKnownWifiNetworkInfo) {
        self.controlPanelManager.context.selectedForRemovalWifiNetworkInfo = network
        self.controlPanelManager.actionRemoveWifiCredentials()
    }

    private func showDeactivateSimInfoView() {
        DispatchQueue.main.async {
            if (!self.rewindTo(Gen3SetupControlPanelInfoDeactivateSimViewController.self)) {
                let infoView = Gen3SetupControlPanelInfoDeactivateSimViewController.loadedViewController()
                infoView.setup(context: self.controlPanelManager.context, didFinish: self.simInfoViewCompleted)
                infoView.ownerStepType = nil
                self.embededNavigationController.pushViewController(infoView, animated: true)
            }
        }
    }

    private func showActivateSimInfoView() {
        DispatchQueue.main.async {
            if (!self.rewindTo(Gen3SetupControlPanelInfoActivateSimViewController.self)) {
                let infoView = Gen3SetupControlPanelInfoActivateSimViewController.loadedViewController()
                infoView.setup(context: self.controlPanelManager.context, didFinish: self.simInfoViewCompleted)
                infoView.ownerStepType = nil
                self.embededNavigationController.pushViewController(infoView, animated: true)
            }
        }
    }

    private func showResumeSimInfoView() {
        DispatchQueue.main.async {
            if (!self.rewindTo(Gen3SetupControlPanelInfoResumeSimViewController.self)) {
                let infoView = Gen3SetupControlPanelInfoResumeSimViewController.loadedViewController()
                infoView.setup(context: self.controlPanelManager.context, didFinish: self.simInfoViewCompleted, requestShowDataLimit: self.requestShowDataLimit)
                infoView.ownerStepType = nil
                self.embededNavigationController.pushViewController(infoView, animated: true)
            }
        }
    }

    func simInfoViewCompleted() {
        self.controlPanelManager.setInfoDone()
    }

    func requestShowDataLimit() {
        self.showSimDataLimitView()
    }



    override func gen3SetupDidRequestToSelectSimDataLimit(_ sender: Gen3SetupStep) {
        self.currentStepType = type(of: sender)
        showSimDataLimitView()
    }

    private func showSimDataLimitView() {
        DispatchQueue.main.async {
            if (!self.rewindTo(Gen3SetupControlPanelSimDataLimitViewController.self)) {
                let dataLimitVC = Gen3SetupControlPanelSimDataLimitViewController.loadedViewController()
                dataLimitVC.setup(currentLimit: self.controlPanelManager.context.targetDevice.sim!.dataLimit!,
                        disableValuesSmallerThanCurrent: self.currentAction == .actionChangeDataLimit ? false : true,
                        callback: self.simDataLimitViewCompleted)
                dataLimitVC.ownerStepType = self.currentStepType
                self.embededNavigationController.pushViewController(dataLimitVC, animated: true)
            }
        }
    }

    private func simDataLimitViewCompleted(limit: Int) {
        if (self.currentAction == .actionChangeDataLimit) {
            self.controlPanelManager.setSimDataLimit(dataLimit: limit)
        } else {
            //adjust value in context and pop to previous view
            self.controlPanelManager.context.targetDevice.setSimDataLimit = limit
            showResumeSimInfoView()
        }
    }

    override func gen3SetupDidRequestTargetDeviceInfo(_ sender: Gen3SetupStep) {
        self.controlPanelManager.setTargetDeviceInfo(dataMatrix: self.targetDeviceDataMatrix!)
    }

    override func targetPairingProcessViewCompleted() {
        //remove last two views, because they will prevent back from functioning properly
        while self.embededNavigationController.viewControllers.count > 1 {
            self.embededNavigationController.popViewController(animated: false)
        }

        super.targetPairingProcessViewCompleted()
    }


    internal func showExternalSim() {
        DispatchQueue.main.async {
            if (self.hideAlertIfVisible()) {
                self.alert = UIAlertController(title: Gen3SetupStrings.Prompt.ErrorTitle,
                        message: Gen3SetupStrings.Prompt.ControlPanelExternalSimNotSupportedText,
                        preferredStyle: .alert)

                self.alert!.addAction(UIAlertAction(title: Gen3SetupStrings.Action.Ok, style: .default) { action in
                    (self.embededNavigationController.topViewController as? Gen3SetupViewController)?.resume(animated: true)
                })

                self.present(self.alert!, animated: true)
            }
        }
    }

    internal func showMeshNotSupported() {
        DispatchQueue.main.async {
            if (self.hideAlertIfVisible()) {
                self.alert = UIAlertController(title: Gen3SetupStrings.Prompt.ErrorTitle,
                        message: Gen3SetupStrings.Prompt.ControlPanelMeshNotSupportedText,
                        preferredStyle: .alert)

                self.alert!.addAction(UIAlertAction(title: Gen3SetupStrings.Action.Ok, style: .default) { action in
                    (self.embededNavigationController.topViewController as? Gen3SetupViewController)?.resume(animated: true)
                })

                self.present(self.alert!, animated: true)
            }
        }
    }

    override func gen3SetupDidEnterState(_ sender: Gen3SetupStep, state: Gen3SetupFlowState) {
        super.gen3SetupDidEnterState(sender, state: state)

        switch state {
            case .TargetDeviceConnecting:
                showPrepareForPairingView()
            case .TargetDeviceDiscovered:
                showTargetPairingProcessView()
            default:
                break
        }
    }


    override func gen3SetupError(_ sender: Gen3SetupStep, error: Gen3SetupFlowError, severity: Gen3SetupErrorSeverity, nsError: Error?) {
        //don't show timeout error when pairing to target device
        if error == .FailedToScanBecauseOfTimeout,  let currentStep = flowRunner.currentStep, type(of: currentStep) == StepConnectToTargetDevice.self {
            self.flowRunner.retryLastAction()
        } else if (error == .ExternalSimNotSupported) {
            self.controlPanelManager.stopCurrentFlow()
            self.showExternalSim()
        } else if (error == .MeshNotSupported) {
            self.controlPanelManager.stopCurrentFlow()
            self.showMeshNotSupported()
        } else {
            super.gen3SetupError(sender, error: error, severity: severity, nsError: nsError)
        }
    }

    @IBAction override func backTapped(_ sender: UIButton) {
        //resume previous VC
        let vcs = self.embededNavigationController.viewControllers
        log("Back tapped: \(vcs)")

        if (vcs.last! as! Gen3SetupViewController).viewControllerIsBusy {
            log("viewController is busy, not backing")
            //view controller cannot be backed from at this moment
            return
        }

        guard vcs.count > 1, let vcCurr = (vcs[vcs.count-1] as? Gen3SetupViewController), let vcPrev = (vcs[vcs.count-2] as? Gen3SetupViewController) else {
            log("Back button was pressed when it was not supposed to be pressed. Ignoring.")
            return
        }

        if vcCurr.allowBack {
            vcPrev.resume(animated: false)

            if vcPrev.ownerStepType != nil, vcCurr.ownerStepType != vcPrev.ownerStepType {
                log("Rewinding flow from: \(vcCurr.ownerStepType) to: \(vcPrev.ownerStepType!)")
                self.flowRunner.rewindTo(step: vcPrev.ownerStepType!)
            } else {
                if (vcPrev.ownerStepType == nil) {
                    self.controlPanelManager.stopCurrentFlow()
                }

                log("Popping")
                self.embededNavigationController.popViewController(animated: true)
            }
        } else {
            log("Back button was pressed when it was not supposed to be pressed. Ignoring.")
        }
    }
}
