//
// Created by Raimundas Sakalauskas on 2019-03-15.
// Copyright (c) 2019 Particle. All rights reserved.
//

import Foundation

class Gen3SetupControlPanelFlowManager : Gen3SetupFlowRunner {

    fileprivate let actionAddToMeshFlow:[Gen3SetupStep] = [
        StepGetTargetDeviceInfo(),
        StepConnectToTargetDevice(),
        StepStopSignal(),
        StepEnsureNotOnMeshNetwork(),
        StepCheckHasNetworkInterfaces(),
        StepOfferSelectOrCreateNetwork()
    ]

    //runs post ethernet/wifi/cellular flows
    fileprivate let networkCreatorFlow: [Gen3SetupStep] = [
        StepGetNewNetworkName(),
        StepGetNewNetworkPassword(),
        StepCreateNetwork(),
        StepExitListeningMode(),
        StepControlPanelFlowCompleted()
    ]

    fileprivate let joinerFlow: [Gen3SetupStep] = [
        StepShowInfo(.joinerFlow),
        StepGetCommissionerDeviceInfo(),
        StepConnectToCommissionerDevice(),
        StepEnsureCommissionerNetworkMatches(),
        StepEnsureCorrectSelectedNetworkPassword(),
        StepJoinSelectedNetwork(),
        StepFinishJoinSelectedNetwork(dropCommissionerConnection: true),
        StepExitListeningMode(),
        StepEnsureGotClaimed(),
        StepControlPanelFlowCompleted()
    ]




    func actionAddToMesh() {
        self.currentFlow = actionAddToMeshFlow
        self.currentStepIdx = 0
        self.runCurrentStep()
    }


    fileprivate let actionNewWifiFlow:[Gen3SetupStep] = [
        StepGetTargetDeviceInfo(),
        StepConnectToTargetDevice(),
        StepStopSignal(),
        StepEnterListeningMode(),
        StepGetUserWifiNetworkSelection(),
        StepEnsureCorrectSelectedWifiNetworkPassword(),
        StepExitListeningMode(),
        StepGetWifiNetwork(),
        StepControlPanelFlowCompleted()
    ]

    func actionNewWifi() {
        self.currentFlow = actionNewWifiFlow
        self.currentStepIdx = 0
        self.runCurrentStep()
    }


    fileprivate let actionManageWifiFlow:[Gen3SetupStep] = [
        StepGetTargetDeviceInfo(),
        StepConnectToTargetDevice(),
        StepStopSignal(),
        StepGetKnownWifiNetworks(),
        StepControlPanelFlowCompleted()
    ]

    func actionManageWifi() {
        self.currentFlow = actionManageWifiFlow
        self.currentStepIdx = 0
        self.runCurrentStep()
    }


    fileprivate let actionRemoveWifiCredentialsFlow:[Gen3SetupStep] = [
        StepRemoveSelectedWifiCredentials(),
        StepGetKnownWifiNetworks(),
        StepEnterListeningMode(),
        StepExitListeningMode(),
        StepGetWifiNetwork(),
        StepControlPanelFlowCompleted()
    ]

    func actionRemoveWifiCredentials() {
        self.currentFlow = actionRemoveWifiCredentialsFlow
        self.currentStepIdx = 0
        self.runCurrentStep()
    }

    fileprivate let actionPairMeshFlow:[Gen3SetupStep] = [
        StepGetTargetDeviceInfo(),
        StepConnectToTargetDevice(),
        StepStopSignal(),
        StepExitListeningMode(),
        StepGetMeshNetwork(),
        StepControlPanelFlowCompleted()
    ]

    func actionPairMesh() {
        self.currentFlow = actionPairMeshFlow
        self.currentStepIdx = 0
        self.runCurrentStep()
    }

    fileprivate let actionPairEthernetFlow:[Gen3SetupStep] = [
        StepGetTargetDeviceInfo(),
        StepConnectToTargetDevice(),
        StepStopSignal(),
        StepExitListeningMode(),
        StepGetEthernetFeatureStatus(),
        StepControlPanelFlowCompleted()
    ]

    func actionPairEthernet() {
        self.currentFlow = actionPairEthernetFlow
        self.currentStepIdx = 0
        self.runCurrentStep()
    }

    fileprivate let actionPairWifiFlow:[Gen3SetupStep] = [
        StepGetTargetDeviceInfo(),
        StepConnectToTargetDevice(),
        StepStopSignal(),
        StepExitListeningMode(),
        StepGetWifiNetwork(),
        StepControlPanelFlowCompleted()
    ]

    func actionPairWifi() {
        self.currentFlow = actionPairWifiFlow
        self.currentStepIdx = 0
        self.runCurrentStep()
    }

    fileprivate let actionPairCellularFlow:[Gen3SetupStep] = [
        StepGetTargetDeviceInfo(),
        StepConnectToTargetDevice(),
        StepStopSignal(),
        StepExitListeningMode(),
        StepCheckHasNetworkInterfaces(forceSimStatus: true),
        StepControlPanelFlowCompleted()
    ]

    func actionPairCellular() {
        self.currentFlow = actionPairCellularFlow
        self.currentStepIdx = 0
        self.runCurrentStep()
    }



    fileprivate let actionToggleEthernetFeatureFlow:[Gen3SetupStep] = [
        StepGetTargetDeviceInfo(),
        StepConnectToTargetDevice(),
        StepStopSignal(),
        StepExitListeningMode(),
        StepEnsureCorrectEthernetFeatureStatus(),
        StepControlPanelFlowCompleted()
    ]

    func actionToggleEthernetFeature() {
        self.currentFlow = actionToggleEthernetFeatureFlow
        self.currentStepIdx = 0
        self.runCurrentStep()
    }




    fileprivate let actionToggleSimStatusFlow:[Gen3SetupStep] = [
        StepGetTargetDeviceInfo(),
        StepConnectToTargetDevice(),
        StepStopSignal(),
        StepExitListeningMode(),
        StepShowInfo(.simStatusToggle),
        StepEnsureCorrectSimState(),
        StepControlPanelFlowCompleted()
    ]

    func actionToggleSimStatus() {
        self.currentFlow = actionToggleSimStatusFlow
        self.currentStepIdx = 0
        self.runCurrentStep()
    }



    fileprivate let actionChangeDataLimitFlow:[Gen3SetupStep] = [
        StepGetTargetDeviceInfo(),
        StepConnectToTargetDevice(),
        StepStopSignal(),
        StepExitListeningMode(),
        StepSetSimDataLimit(),
        StepControlPanelFlowCompleted()
    ]

    func actionChangeDataLimit() {
        self.currentFlow = actionChangeDataLimitFlow
        self.currentStepIdx = 0
        self.runCurrentStep()
    }


    fileprivate let actionLeaveMeshNetworkFlow:[Gen3SetupStep] = [
        StepGetTargetDeviceInfo(),
        StepConnectToTargetDevice(),
        StepStopSignal(),
        StepEnsureNotOnMeshNetwork(),
        StepExitListeningMode(),
        StepControlPanelFlowCompleted()
    ]

    func actionLeaveMeshNetwork() {
        self.currentFlow = actionLeaveMeshNetworkFlow
        self.currentStepIdx = 0
        self.runCurrentStep()
    }

    func stopCurrentFlow() {
        self.context.canceled = false

        self.currentStep?.reset()
        self.currentStep?.context = nil

        self.currentFlow = nil
        self.currentStepIdx = 0
    }


    //this is for internal use only, because it requires a lot of internal knowledge to use and is nearly impossible to expose to external developers
    override internal func rewindTo(step: Gen3SetupStep.Type, runStep: Bool = true) -> Gen3SetupFlowError? {
        currentStep!.rewindFrom()

        if (currentStepIdx == 0) {
            //if we are backing from one of these flows, we need to switch the flow type.
            if (currentFlow == joinerFlow || currentFlow == networkCreatorFlow) {
                currentFlow = actionAddToMeshFlow
            }
            currentStepIdx = actionAddToMeshFlow.count
            self.log("Rewinding flow to internetConnectedPreflow")
        }

        guard let currentFlow = self.currentFlow else {
            return .IllegalOperation
        }

        for i in 0 ..< currentFlow.count {
            if (currentFlow[i].isKind(of: step)) {
                if (i >= self.currentStepIdx) {
                    //trying to "rewind" forward
                    return .IllegalOperation
                }

                self.currentStepIdx = i
                self.log("returning to step: \(self.currentStepIdx)")
                self.currentStep!.rewindTo(context: self.context)
                if (runStep) {
                    self.runCurrentStep()

                }

                return nil
            }
        }

        return .IllegalOperation
    }

    override internal func switchFlow() {
        log("stepComplete\n\n" +
                "--------------------------------------------------------------------------------------------\n" +
                "Switching flow!!!")

        if (currentFlow == actionAddToMeshFlow) {
            if (context.selectedNetworkMeshInfo == nil) {
                self.currentFlow = networkCreatorFlow
            } else {
                self.currentFlow = joinerFlow
            }
        } else {
            self.currentFlow = nil
        }

        self.currentStepIdx = 0
    }


}

