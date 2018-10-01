//
// Created by Raimundas Sakalauskas on 9/20/18.
// Copyright © 2018 Particle. All rights reserved.
//

import Foundation





//delegate required to request / deliver information from / to the UI
protocol MeshSetupFlowManagerDelegate {
    func meshSetupDidRequestTargetDeviceInfo()
    func meshSetupDidRequestToLeaveNetwork(network: MeshSetupNetworkInfo)
    func meshSetupDidPairWithTargetDevice()


    func meshSetupDidRequestToSelectNetwork(availableNetworks: [MeshSetupNetworkInfo])

    func meshSetupDidRequestCommissionerDeviceInfo()
    func meshSetupDidRequestToEnterSelectedNetworkPassword()


    func meshSetupDidRequestToEnterDeviceName()
    func meshSetupDidRequestToAddOneMoreDevice()

    func meshSetupDidRequestToFinishSetupEarly() //before setting mesh network
    func meshSetupDidRequestToSelectOrCreateNetwork(availableNetworks: [MeshSetupNetworkInfo])

    func meshSetupDidRequestToEnterNewNetworkNameAndPassword()
    func meshSetupDidCreateNetwork(network: MeshSetupNetworkInfo)


    func meshSetupDidEnterState(state: MeshSetupFlowState)
    func meshSetupError(error: MeshSetupFlowError, severity: MeshSetupErrorSeverity, nsError: Error?)
}

enum MeshSetupFlowState {
    case TargetDeviceConnecting
    case TargetDeviceConnected
    case TargetDeviceReady

    case TargetDeviceScanningForNetworks
    case TargetGatewayDeviceScanningForNetworks

    case TargetDeviceConnectingToInternetStarted
    case TargetDeviceConnectingToInternetStep1Done
    case TargetDeviceConnectingToInternetCompleted

    case CommissionerDeviceConnecting
    case CommissionerDeviceConnected
    case CommissionerDeviceReady

    case JoiningNetworkStarted
    case JoiningNetworkStep1Done
    case JoiningNetworkStep2Done
    case JoiningNetworkCompleted


    case CreateNetworkStarted
    case CreateNetworkStep1Done
    case CreateNetworkStep2Done
    case CreateNetworkStep3Done
    case CreateNetworkCompleted
}

enum MeshSetupFlowError: Error, CustomStringConvertible {
    //trying to perform action at the wrong time
    case IllegalOperation

    //EnsureTargetDeviceCanBeClaimed
    case UnableToGenerateClaimCode

    //ConnectToTargetDevice && ConnectToCommissionerDevice
    case DeviceTooFar
    case FailedToStartScan
    case FailedToScanBecauseOfTimeout
    case FailedToConnect

    //Can happen in any step, inform user about it and repeat the step
    case BluetoothDisabled
    case BluetoothConnectionDropped

    //Can happen in any step, when result != NONE and special case is not handled by onReply handler
    case BluetoothError

    //EnsureCommissionerNetworkMatches
    case CommissionerNetworkDoesNotMatch
    case WrongNetworkPassword
    case PasswordTooShort

    //EnsureHasInternetAccess
    case FailedToObtainIp

    //GetNewDeviceName
    case UnableToRenameDevice
    case NameTooShort

    case DeviceIsNotAllowedToJoinNetwork
    case DeviceIsUnableToFindNetworkToJoin
    case DeviceTimeoutWhileJoiningNetwork

    //CheckDeviceGotClaimed
    case DeviceConnectToCloudTimeout
    case DeviceGettingClaimedTimeout

    public var description: String {
        switch self {
            //these errors are handled instantly
            case .WrongNetworkPassword : return "Provided password is incorrect."
            case .PasswordTooShort : return "Network password has to be between 6 and 16 characters."
            case .IllegalOperation : return "Illegal operation."
            case .UnableToRenameDevice : return "Unable to rename device at this time. Please try again later."
            case .NameTooShort : return "Device name cannot be empty."

                //user facing errors
            case .UnableToGenerateClaimCode : return "There was an error attempting to claim this device to your account."
            case .DeviceTooFar : return "Your mesh device is too far away from your phone. Please hold your phone closer and try again."
            case .FailedToStartScan : return "Bluetooth appears to be disabled on your phone. Please enable Bluetooth and try again."
            case .FailedToScanBecauseOfTimeout : return "Unable to find your mesh device. Make sure the mesh device’s LED is blinking blue and that it’s not connected to any other devices."
            case .FailedToConnect : return "You phone failed to connect to your mesh device. Please try again."
            case .BluetoothDisabled : return "Bluetooth appears to be disabled on your phone. Please enable Bluetooth and try again."
            case .BluetoothError : return "Something went wrong with Bluetooth. Please restart the the setup process and try again."
            case .CommissionerNetworkDoesNotMatch : return "The assisting device is on a different mesh network than the one you are trying to join. Please make sure the devices are trying to use the same network."
            case .FailedToObtainIp : return "Your device failed to obtain an IP address. Please make sure the ethernet cable is connected securely to the Ethernet FeatherWing."

            case .BluetoothConnectionDropped : return "The Bluetooth connection was dropped unexpectedly. Please restart the setup and try again."

            case .DeviceIsNotAllowedToJoinNetwork : return "Your device was unable to join the network (NOT_ALLOWED). Please press try again."
            case .DeviceIsUnableToFindNetworkToJoin : return "Your device was unable to join the network (NOT_FOUND). Please press try again."
            case .DeviceTimeoutWhileJoiningNetwork : return "Your device was unable to join the network (TIMEOUT). Please press try again."

            case .DeviceConnectToCloudTimeout : return "Your device could not connect to Device Cloud. Please try again."
            case .DeviceGettingClaimedTimeout : return "Your device failed to be claimed. Please try again."
        }
    }
}

fileprivate struct MeshDevice {
    var type: ParticleDeviceType?
    var deviceId: String?
    var credentials: MeshSetupPeripheralCredentials?

    var transceiver: MeshSetupProtocolTransceiver?

    var claimCode: String?
    var isClaimed: Bool?
    var isSetupDone: Bool?
    var supportsCompressedOTAUpdate: Bool?

    var hasInternetCapableNetworkInterfaces: Bool?
    var hasInternetAddress: Bool?

    var networkInterfaces: [MeshSetupNetworkInterfaceEntry]?
    var joinerCredentials: (eui64: String, password: String)?

    var networkInfo: MeshSetupNetworkInfo?
    var networks: [MeshSetupNetworkInfo]?

    func getEthernetInterfaceIdx() -> UInt32? {
        if let interfaces = networkInterfaces {
            for interface in interfaces {
                if interface.type == .ethernet {
                    return interface.index
                }
            }
        }
        return nil
    }
}


class MeshSetupFlowManager: NSObject, MeshSetupBluetoothConnectionManagerDelegate {



    private enum MeshSetupFlowCommands {
        case ResetSetupAndNetwork

        //preflow
        case GetTargetDeviceInfo
        case ConnectToTargetDevice
        case EnsureLatestFirmware
        case EnsureTargetDeviceCanBeClaimed
        case CheckTargetDeviceHasNetworkInterfaces
        case ChooseFlow

        //main flow
        case SetClaimCode
        case EnsureTargetDeviceIsNotOnMeshNetwork
        case GetUserNetworkSelection
        case GetCommissionerDeviceInfo
        case ConnectToCommissionerDevice
        case EnsureCommissionerNetworkMatches
        case EnsureCorrectSelectedNetworkPassword
        case JoinSelectedNetwork
        case GetNewDeviceName
        case OfferToAddOneMoreDevice

        //gateway
        case EnsureHasInternetAccess
        case CheckDeviceGotClaimed
        case StopTargetDeviceListening
        case OfferToFinishSetupEarly
        case OfferSelectOrCreateNetwork
        case ChooseSubflow

        case CreateNetwork
    }

    private let preflow: [MeshSetupFlowCommands] = [
        .GetTargetDeviceInfo,
        .ConnectToTargetDevice,
        //.ResetSetupAndNetwork,
        //.EnsureLatestFirmware,
        .EnsureTargetDeviceCanBeClaimed,
        .CheckTargetDeviceHasNetworkInterfaces,
        .SetClaimCode,
        .ChooseFlow
    ]


    private let joinerFlow: [MeshSetupFlowCommands] = [
        .EnsureTargetDeviceIsNotOnMeshNetwork,
        .GetUserNetworkSelection,
        .GetCommissionerDeviceInfo,
        .ConnectToCommissionerDevice,
        .EnsureCommissionerNetworkMatches,
        .EnsureCorrectSelectedNetworkPassword,
        .JoinSelectedNetwork,
        .CheckDeviceGotClaimed,
        .GetNewDeviceName,
        .OfferToAddOneMoreDevice
    ]



    private let ethernetFlow: [MeshSetupFlowCommands] = [
        .EnsureTargetDeviceIsNotOnMeshNetwork,
        .EnsureHasInternetAccess,
        .CheckDeviceGotClaimed,
        .GetNewDeviceName,
        .OfferToFinishSetupEarly,
        .OfferSelectOrCreateNetwork,
        .ChooseSubflow
    ]


    private let joinerSubflow: [MeshSetupFlowCommands] = [
        .GetCommissionerDeviceInfo,
        .ConnectToCommissionerDevice,
        .EnsureCommissionerNetworkMatches,
        .EnsureCorrectSelectedNetworkPassword,
        .JoinSelectedNetwork,
        .OfferToAddOneMoreDevice
    ]

    private let creatorSubflow: [MeshSetupFlowCommands] = [
        .CreateNetwork,
        .OfferToAddOneMoreDevice
    ]



    var delegate: MeshSetupFlowManagerDelegate

    private var bluetoothManager: MeshSetupBluetoothConnectionManager!
    private var bluetoothReady: Bool = false


    private var targetDevice: MeshDevice! = MeshDevice()
    private var commissionerDevice: MeshDevice?

    //for joining flow
    private var selectedNetworkInfo: MeshSetupNetworkInfo?
    private var selectedNetworkPassword: String?

    //for creating flow
    private var newNetworkName: String?
    private var newNetworkPassword: String?

    private var userSelectedToLeaveNetwork: Bool?

    //to prevent long running actions from executing
    private var canceled = false


    private var currentFlow: [MeshSetupFlowCommands]!
    private var currentStep: Int = 0
    private var currentStepFlags: [String: Any]! //if there's shared data needed to properly run the step
    private var currentCommand: MeshSetupFlowCommands {
        return currentFlow[currentStep]
    }

    init(delegate: MeshSetupFlowManagerDelegate) {
        self.delegate = delegate
        super.init()
        self.bluetoothManager = MeshSetupBluetoothConnectionManager(delegate: self)
    }

    //MARK: public interface
    func targetDeviceName() -> String? {
        return targetDevice.credentials?.name
    }

    func targetDeviceType() -> ParticleDeviceType? {
        return targetDevice.type
    }

    func commissionerDeviceName() -> String? {
        return commissionerDevice?.credentials?.name
    }

    func commissionerDeviceType() -> ParticleDeviceType? {
        return commissionerDevice?.type
    }


    //entry to the flow
    func startSetup() {
        currentFlow = preflow
        currentStep = 0

        self.runCurrentStep()
    }

    func cancelSetup() {
        self.canceled = true

        self.bluetoothManager.stopScan()
        self.bluetoothManager.dropAllConnections()
    }

    private func finishSetup() {
        self.canceled = true

        self.bluetoothManager.stopScan()
        self.bluetoothManager.dropAllConnections()
    }

    func retryLastAction() {
        switch self.currentCommand {
            //this should never happen
            case .GetTargetDeviceInfo,
                    .GetCommissionerDeviceInfo,
                    .ChooseFlow,
                    .OfferToAddOneMoreDevice,
                    .ChooseSubflow,
                    .OfferToFinishSetupEarly,
                    .GetNewDeviceName: //this will be handeled by onCompleteHandler of setDeviceName method
                break


            case .ConnectToTargetDevice,
                    .ConnectToCommissionerDevice,
                    .EnsureLatestFirmware,
                    .EnsureTargetDeviceCanBeClaimed,
                    .GetUserNetworkSelection,
                    .CheckTargetDeviceHasNetworkInterfaces,
                    .SetClaimCode,
                    .EnsureCommissionerNetworkMatches, //if there's a connection error in this step, we try to recover, but if networks do not match, flow has to be restarted
                    .EnsureCorrectSelectedNetworkPassword,
                    .CreateNetwork,
                    .EnsureHasInternetAccess,
                    .CheckDeviceGotClaimed,
                    .StopTargetDeviceListening,
                    .OfferSelectOrCreateNetwork:
                runCurrentStep()

            case .EnsureTargetDeviceIsNotOnMeshNetwork:
                if (userSelectedToLeaveNetwork == nil) {
                    self.runCurrentStep()
                } else {
                    setTargetDeviceLeaveNetwork(leave: self.userSelectedToLeaveNetwork!)
                }

            case .JoinSelectedNetwork:
                self.runCurrentStep()
            default:
                break;
        }
    }

    //MARK: Flow control
    private func runCurrentStep() {
        if (self.canceled) {
            return
        }

        log("stepComplete\n\n" +
                "--------------------------------------------------------------------------------------------\n" +
                "currentStep = \(currentStep), currentCommand = \(currentCommand)")
        self.currentStepFlags = [:]
        switch self.currentCommand {
            case .ResetSetupAndNetwork:
                #if DEBUG
                    self.stepResetSetupAndNetwork()
                #else
                    fatalError("self.stepResetSetupAndNetwork")
                #endif

            //preflow
            case .GetTargetDeviceInfo:
                self.stepGetTargetDeviceInfo()
            case .ConnectToTargetDevice:
                self.stepConnectToTargetDevice()
            case .EnsureLatestFirmware:
                self.stepEnsureLatestFirmware()
            case .EnsureTargetDeviceCanBeClaimed:
                self.stepEnsureTargetDeviceCanBeClaimed()
            case .CheckTargetDeviceHasNetworkInterfaces:
                self.stepCheckTargetDeviceHasNetworkInterfaces()
            case .EnsureTargetDeviceIsNotOnMeshNetwork:
                self.stepEnsureTargetDeviceIsNotOnMeshNetwork()
            case .SetClaimCode:
                self.stepSetClaimCode()
            case .ChooseFlow:
                 self.stepChooseFlow()

            //main flow
            case .GetUserNetworkSelection:
                self.stepGetUserNetworkSelection()
            case .GetCommissionerDeviceInfo:
                self.stepGetCommissionerDeviceInfo()
            case .ConnectToCommissionerDevice:
                self.stepConnectToCommissionerDevice()
            case .EnsureCommissionerNetworkMatches:
                self.stepEnsureCommissionerNetworkMatches()
            case .EnsureCorrectSelectedNetworkPassword:
                self.stepEnsureCorrectSelectedNetworkPassword()
            case .JoinSelectedNetwork:
                self.stepJoinSelectedNetwork()
            case .GetNewDeviceName:
                self.stepGetNewDeviceName()
            case .OfferToAddOneMoreDevice:
                self.stepOfferToAddOneMoreDevice()

            //gateway
            case .EnsureHasInternetAccess:
                self.stepEnsureHasInternetAccess()
            case .StopTargetDeviceListening:
                self.stepStopTargetDeviceListening()
            case .CheckDeviceGotClaimed:
                 self.stepCheckDeviceGotClaimed()
            case .OfferToFinishSetupEarly:
                self.stepOfferToFinishSetupEarly()
            case .OfferSelectOrCreateNetwork:
                self.stepOfferSelectOrCreateNetwork()
            case .ChooseSubflow:
                self.stepChooseSubflow()

            case .CreateNetwork:
                self.stepCreateNetwork()

            default:
                log("Unknown command: \(currentFlow[currentStep])")
            }
    }

    private func stepComplete() {
        if (self.canceled) {
            return
        }

        self.currentStep += 1
        self.runCurrentStep()
    }


    //end of preflow
    private func stepChooseFlow() {
        log("preflow completed")
        self.delegate.meshSetupDidPairWithTargetDevice()
    }

    func continueWithMainFlow() {

        //jump to new flow
        self.currentStep = 0
        //if there's ethernet and we are not adding more devices to same network
        if (self.targetDevice.hasInternetCapableNetworkInterfaces! && self.selectedNetworkInfo == nil) {
            self.currentFlow = ethernetFlow
            log("setting gateway flow")
        } else {
            self.currentFlow = joinerFlow
            log("setting joiner flow")
        }
        self.runCurrentStep()
    }

    private func stepChooseSubflow() {
        self.currentStep = 0
        if newNetworkPassword != nil && newNetworkPassword != nil {
            log("subflow: creator")
            self.currentFlow = creatorSubflow
        } else {
            log("subflow: joiner")
            self.currentFlow = joinerSubflow
        }
        self.runCurrentStep()
    }

    //MARK: Helpers
    private func log(_ message: String) {
        if (MeshSetup.LogFlowManager) {
            NSLog("MeshSetupFlow: \(message)")
        }
    }

    private func fail(withReason reason: MeshSetupFlowError, severity: MeshSetupErrorSeverity = .Error, nsError: Error? = nil) {
        if self.canceled == false {
            log("error: \(reason.description), nsError: \(nsError?.localizedDescription as Optional)")
            self.delegate.meshSetupError(error: reason, severity: severity, nsError: nsError)
        }
    }

    private func removeRepeatedNetworks(_ networks: [MeshSetupNetworkInfo]) -> [MeshSetupNetworkInfo] {
        var ids:Set<String> = []
        var filtered:[MeshSetupNetworkInfo] = []

        for network in networks {
            if (!ids.contains(network.extPanID)) {
                ids.insert(network.extPanID)
                filtered.append(network)
            }
        }

        return filtered
    }

    //MARK: Input validators
    private func validateNetworkPassword(_ password: String) -> Bool {
        return password.count >= 6
    }

    private func validateNetworkName(_ networkName: String) -> Bool {
        return (networkName.count > 0) && (networkName.count < 16)
    }

    private func validateDeviceName(_ name: String) -> Bool {
        return name.count > 0
    }


    //MARK: Error Handling
    private func handleBluetoothErrorResult(_ result: ControlReplyErrorType) {
        if (self.canceled) {
            return
        }

        if (result == .TIMEOUT && !self.bluetoothReady) {
            self.fail(withReason: .BluetoothDisabled)
            return
        } else {
            self.fail(withReason: .BluetoothError)
        }
    }

    //MARK: BluetoothConnectionManagerDelegate
    func bluetoothConnectionManagerStateChanged(sender: MeshSetupBluetoothConnectionManager, state: MeshSetupBluetoothConnectionManagerState) {
        log("bluetoothConnectionManagerStateChanged = \(state)")
        if (self.bluetoothManager.state == .Ready) {
            self.bluetoothReady = true
        } else if (self.bluetoothManager.state == .Disabled) {
            self.bluetoothReady = false

            //if we are waiting for the reply = trigger timeout
            if let targetDeviceTransceiver = self.targetDevice.transceiver {
                targetDeviceTransceiver.triggerTimeout()
            }

            //if we are waiting for the reply = trigger timeout
            if let commissionerDeviceTransceiver = self.commissionerDevice?.transceiver {
                commissionerDeviceTransceiver.triggerTimeout()
            }
        }
        //other states are really temporary.
    }

    func bluetoothConnectionManagerError(sender: MeshSetupBluetoothConnectionManager, error: BluetoothConnectionManagerError, severity: MeshSetupErrorSeverity) {
        log("bluetoothConnectionManagerError = \(error), severity = \(severity)")
        if (self.currentCommand == .ConnectToTargetDevice || self.currentCommand == .ConnectToCommissionerDevice) {
            if (error == .DeviceWasConnected) {
                self.currentStepFlags["reconnect"] = true
                //this will be used in connection dropped to restart the step
            } else if (error == .DeviceTooFar) {
                self.fail(withReason: .DeviceTooFar)
                //after showing promt, step should be repeated
            } else if (error == .FailedToScanBecauseOfTimeout && self.currentStepFlags["reconnectAfterFirmwareFlash"] != nil) {
                //coming online after a flash might take a while, if for some reason we timeout, we should retry the step
                self.stepConnectToTargetDevice()
            } else {
                if (error == .FailedToStartScan) {
                    self.fail(withReason: .FailedToStartScan)
                } else if (error == .FailedToScanBecauseOfTimeout) {
                    self.fail(withReason: .FailedToScanBecauseOfTimeout)
                } else { //FailedToConnect
                    self.fail(withReason: .FailedToConnect)
                }
            }
        } else {
            //bluetoothConnectionManagerError shouldn't happen in any other step but if it happens lets handle it
            self.fail(withReason: .BluetoothError, severity: .Fatal)
        }
    }

    func bluetoothConnectionManagerConnectionCreated(sender: MeshSetupBluetoothConnectionManager, connection: MeshSetupBluetoothConnection) {
        if (self.currentCommand == .ConnectToTargetDevice) {
            self.delegate.meshSetupDidEnterState(state: .TargetDeviceConnected)
        } else if (self.currentCommand == .ConnectToCommissionerDevice) {
            self.delegate.meshSetupDidEnterState(state: .CommissionerDeviceConnected)
        } else {
            //bluetoothConnectionManagerConnectionCreated shouldn't happen in any other step but if it happens lets handle it
            self.fail(withReason: .BluetoothError, severity: .Fatal)
        }
    }

    func bluetoothConnectionManagerConnectionBecameReady(sender: MeshSetupBluetoothConnectionManager, connection: MeshSetupBluetoothConnection) {
        if (self.currentCommand == .ConnectToTargetDevice) {
            self.delegate.meshSetupDidEnterState(state: .TargetDeviceReady)
            self.targetDeviceConnected(connection: connection)
        } else if (self.currentCommand == .ConnectToCommissionerDevice) {
            self.delegate.meshSetupDidEnterState(state: .CommissionerDeviceReady)
            self.commissionerDeviceConnected(connection: connection)
        } else {
            //bluetoothConnectionManagerConnectionBecameReady shouldn't happen in any other step but if it happens lets handle it
            self.fail(withReason: .BluetoothError, severity: .Fatal)
        }
    }

    func bluetoothConnectionManagerConnectionDropped(sender: MeshSetupBluetoothConnectionManager, connection: MeshSetupBluetoothConnection) {
        log("bluetoothConnectionManagerConnectionDropped = \(connection)")
        if (connection == self.targetDevice.transceiver?.connection || connection == self.commissionerDevice?.transceiver?.connection) {
            if self.currentStepFlags["reconnect"] != nil && (self.currentCommand == .ConnectToTargetDevice || self.currentCommand == .ConnectToCommissionerDevice) {
                self.currentStepFlags["reconnect"] = nil
                self.runCurrentStep()
            } else {
                self.fail(withReason: .BluetoothConnectionDropped, severity: .Fatal)
            }
        }
        //if some other connectio was dropped - we dont care
    }
//}

//extension MeshSetupFlowManager {





    //MARK: ResetSetupAndNetwork
    private func stepResetSetupAndNetwork() {
        self.targetDevice.transceiver!.sendLeaveNetwork () { result in
            self.log("targetDevice.sendLeaveNetwork: \(result.description())")
            if (self.canceled) {
                return
            }
            if (result == .NONE) {
                self.setSetupNotDone()
            } else {
                self.handleBluetoothErrorResult(result)
            }
        }
    }

    private func setSetupNotDone() {
        self.targetDevice.transceiver!.sendDeviceSetupDone(done: false) { result in
            self.log("targetDevice.sendDeviceSetupDone: \(result.description())")
            if (self.canceled) {
                return
            }
            if (result == .NONE) {
                self.log("Device reset complete")
            } else {
                self.handleBluetoothErrorResult(result)
            }
        }
    }


    //MARK: GetTargetDeviceInfo
    private func stepGetTargetDeviceInfo() {
        self.delegate.meshSetupDidRequestTargetDeviceInfo()
    }

    func setTargetDeviceInfo(dataMatrix: MeshSetupDataMatrix) -> MeshSetupFlowError? {
        guard currentCommand == .GetTargetDeviceInfo else {
            return .IllegalOperation
        }

        self.userSelectedToLeaveNetwork = nil
        self.targetDevice = MeshDevice()

        //these flags are used to determine gateway subflow .. if they are set, new network is being created
        //otherwise gateway is joining the existing network so it is important to clear them
        //we cant use selected network, because that part might be reused if multiple devices are connected to same
        //network without disconnecting commissioner
        self.newNetworkPassword = nil
        self.newNetworkName = nil

        self.log("dataMatrix: \(dataMatrix)")
        self.targetDevice.type = ParticleDeviceType(serialNumber: dataMatrix.serialNumber)
        self.log("self.targetDevice.type?.description = \(self.targetDevice.type?.description as Optional)")
        self.targetDevice.credentials = MeshSetupPeripheralCredentials(name: self.targetDevice.type!.description + "-" + dataMatrix.serialNumber.suffix(6), mobileSecret: dataMatrix.mobileSecret)

        self.stepComplete()

        return nil
    }

    //MARK: ConnectToTargetDevice
    private func stepConnectToTargetDevice() {
        if (self.bluetoothManager.state != .Ready) {
            self.fail(withReason: .BluetoothDisabled)
            return
        }

        self.bluetoothManager.createConnection(with: self.targetDevice.credentials!)
        self.delegate.meshSetupDidEnterState(state: .TargetDeviceConnecting)
    }

    private func targetDeviceConnected(connection: MeshSetupBluetoothConnection) {
        self.targetDevice.transceiver = MeshSetupProtocolTransceiver(connection: connection)
        self.stepComplete()
    }

    //Slave Latency ≤ 30
    //2 seconds ≤ connSupervisionTimeout ≤ 6 seconds
    //Interval Min modulo 15 ms == 0
    //Interval Min ≥ 15 ms
    //
    //One of the following:
    //  Interval Min + 15 ms ≤ Interval Max
    //  Interval Min == Interval Max == 15 ms
    //
    //Interval Max * (Slave Latency + 1) ≤ 2 seconds
    //Interval Max * (Slave Latency + 1) * 3 <connSupervisionTimeout

    //MARK: EnsureLatestFirmware
    private func stepEnsureLatestFirmware() {
        self.targetDevice.transceiver!.sendGetSystemVersion { result, version in
            self.log("targetDevice.sendGetSystemVersion: \(result.description()), version: \(version as Optional)")
            if (self.canceled) {
                return
            }
            if (result == .NONE) {
                //TODO: get the answer from server if firmware should be updated
                if (version!.range(of: "rc.13") != nil) {
                    self.stepComplete()
                } else {
                    self.checkTargetDeviceSupportsCompressedOTA()
                }
            } else {
                self.handleBluetoothErrorResult(result)
            }
        }
    }


    private func checkTargetDeviceSupportsCompressedOTA() {
        self.targetDevice.transceiver!.sendGetSystemCapabilities { result, capability in
            self.log("targetDevice.sendGetSystemCapabilities: \(result.description()), capability: \(capability?.rawValue as Optional)")
            if (self.canceled) {
                return
            }
            if (result == .NONE) {
                self.targetDevice.supportsCompressedOTAUpdate = (capability! == SystemCapability.compressedOta)
                self.checkTargetDeviceIsSetupDone()
            } else {
                self.handleBluetoothErrorResult(result)
            }
        }
    }

    private func checkTargetDeviceIsSetupDone() {
        self.targetDevice.transceiver!.sendIsDeviceSetupDone { result, isSetupDone in
            self.log("targetDevice.sendIsDeviceSetupDone: \(result.description()), isSetupDone: \(isSetupDone as Optional)")
            if (self.canceled) {
                return
            }
            if (result == .NONE) {
                self.targetDevice.isSetupDone = isSetupDone
                self.startFirmwareUpdate()
            } else {
                self.handleBluetoothErrorResult(result)
            }
        }
    }

    private func startFirmwareUpdate() {
        self.log("Starting firmware update")

        //TODO: get proper firmware binary

        let path = Bundle.main.path(forResource: "tinker-0.8.0-rc.13-xenon", ofType: "bin")

        let firmwareData = try! Data(contentsOf: URL(fileURLWithPath: path!))

        self.currentStepFlags["firmwareData"] = firmwareData
        self.targetDevice.transceiver!.sendStartFirmwareUpdate(binarySize: firmwareData.count) { result, chunkSize in
            self.log("targetDevice.sendStartFirmwareUpdate: \(result.description()), chunkSize: \(chunkSize)")
            if (self.canceled) {
                return
            }
            if (result == .NONE) {
                self.currentStepFlags["chunkSize"] = Int(chunkSize)
                self.currentStepFlags["idx"] = 0

                self.sendFirmwareUpdateChunk()
            } else {
                self.handleBluetoothErrorResult(result)
            }
        }
    }

    private func sendFirmwareUpdateChunk() {
        let chunk = self.currentStepFlags["chunkSize"] as! Int
        let idx = self.currentStepFlags["idx"] as! Int
        let firmwareData = self.currentStepFlags["firmwareData"] as! Data

        let start = idx*chunk
        let bytesLeft = firmwareData.count - start

        self.log("bytesLeft: \(bytesLeft)")

        let subdata = firmwareData.subdata(in: start ..< min(start+chunk, start+bytesLeft))
        self.targetDevice.transceiver!.sendFirmwareUpdateData(data: subdata) { result in
            self.log("targetDevice.sendFirmwareUpdateData: \(result.description())")
            if (self.canceled) {
                return
            }
            if (result == .NONE) {
                if ((idx+1) * chunk >= firmwareData.count) {
                    self.finishFirmwareUpdate()
                } else {
                    self.currentStepFlags["idx"] = idx + 1
                    self.sendFirmwareUpdateChunk()
                }
            } else {
                self.handleBluetoothErrorResult(result)
            }
        }
    }

    private func finishFirmwareUpdate() {
        self.targetDevice.transceiver!.sendFinishFirmwareUpdate(validateOnly: false) { result in
            self.log("targetDevice.sendFinishFirmwareUpdate: \(result.description())")
            if (self.canceled) {
                return
            }
            if (result == .NONE) {
                // reconnect to device by jumping back few steps in the sequence
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .seconds(5)) {
                    if (self.canceled) {
                        return
                    }


                    self.currentStep = self.preflow.index(of: .ConnectToTargetDevice)!
                    self.log("returning to step: \(self.currentStep)")
                    self.runCurrentStep()
                    self.currentStepFlags["reconnectAfterFirmwareFlash"] = true
                }
            } else {
                self.handleBluetoothErrorResult(result)
            }
        }
    }


    //MARK: CheckTargetDeviceHasNetworkInterfaces
    private func stepCheckTargetDeviceHasNetworkInterfaces() {
        self.targetDevice.transceiver!.sendGetInterfaceList { result, interfaces in
            self.log("targetDevice.sendGetInterfaceList: \(result.description()), networkCount: \(interfaces?.count as Optional)")
            if (self.canceled) {
                return
            }
            if (result == .NONE) {
                self.targetDevice.hasInternetCapableNetworkInterfaces = false
                self.targetDevice.networkInterfaces = interfaces!
                for interface in interfaces! {
                    if (interface.type == .ethernet || interface.type == .wifi || interface.type == .ppp) {
                        self.targetDevice.hasInternetCapableNetworkInterfaces = true
                        break
                    }
                }
                self.stepComplete()
            } else {
                self.handleBluetoothErrorResult(result)
            }
        }
    }


    //MARK: EnsureDeviceCanBeClaimed
    private func stepEnsureTargetDeviceCanBeClaimed() {
        self.targetDevice.transceiver!.sendGetDeviceId { result, deviceId in
            self.log("targetDevice.didReceiveDeviceIdReply: \(result.description()), deviceId: \(deviceId as Optional)")
            if (self.canceled) {
                return
            }
            if (result == .NONE) {
                self.targetDevice.deviceId = deviceId!
                self.checkTargetDeviceIsClaimed()
            } else {
                self.handleBluetoothErrorResult(result)
            }
        }
    }


    private func checkTargetDeviceIsClaimed() {
        ParticleCloud.sharedInstance().getDevices { devices, error in
            if (self.canceled) {
                return
            }

            guard error == nil else {
                self.fail(withReason: .UnableToGenerateClaimCode, nsError: error)
                return
            }

            if let devices = devices {
                for device in devices {
                    if (device.id == self.targetDevice.deviceId!) {
                        self.log("device belongs to user already")
                        self.targetDevice.isClaimed = true
                        self.targetDevice.claimCode = nil
                        self.stepComplete()
                        return
                    }
                }
            }

            self.targetDevice.isClaimed = nil
            self.targetDevice.claimCode = nil

            self.getClaimCode()
        }
    }

    private func getClaimCode() {
        log("generating claim code")
        ParticleCloud.sharedInstance().generateClaimCode { claimCode, userDevices, error in
            if (self.canceled) {
                return
            }

            guard error == nil else {
                self.fail(withReason: .UnableToGenerateClaimCode, nsError: error)
                return
            }

            self.log("claim code generated")
            self.targetDevice.claimCode = claimCode
            self.targetDevice.isClaimed = false
            self.stepComplete()
        }
    }



    //MARK: EnsureTargetDeviceIsNotOnMeshNetwork
    private func stepEnsureTargetDeviceIsNotOnMeshNetwork() {
        self.targetDevice.transceiver!.sendGetNetworkInfo { result, networkInfo in
            self.log("targetDevice.sendGetNetworkInfo: \(result.description())")
            if (self.canceled) {
                return
            }
            if (result == .NOT_FOUND) {
                self.targetDevice.networkInfo = nil
                self.targetDeviceLeaveNetwork()
            } else if (result == .NONE) {
                self.targetDevice.networkInfo = networkInfo

                //if user selected to leave network for this device, just do it
                if self.userSelectedToLeaveNetwork != nil {
                    let _ = self.setTargetDeviceLeaveNetwork(leave: self.userSelectedToLeaveNetwork!)
                } else {
                    self.delegate.meshSetupDidRequestToLeaveNetwork(network: networkInfo!)
                }
            } else {
                self.handleBluetoothErrorResult(result)
            }
        }
    }

    func setTargetDeviceLeaveNetwork(leave: Bool) -> MeshSetupFlowError? {
        guard currentCommand == .EnsureTargetDeviceIsNotOnMeshNetwork else {
            return .IllegalOperation
        }

        self.userSelectedToLeaveNetwork = leave

        self.log("setTargetDeviceLeaveNetwork: \(leave)")
        if (leave || self.targetDevice.networkInfo == nil) {
            //forcing this command on devices with no network info helps with the joining process
            self.targetDeviceLeaveNetwork()
        } else {
            fatalError("this is not implemented")
        }

        return nil
    }

    private func targetDeviceLeaveNetwork() {
        self.targetDevice.transceiver!.sendLeaveNetwork { result in
            self.log("targetDevice.didReceiveLeaveNetworkReply: \(result.description())")
            if (self.canceled) {
                return
            }
            if (result == .NONE) {
                self.stepComplete()
            } else {
                self.handleBluetoothErrorResult(result)
            }
        }
    }




    //MARK: SetClaimCode
    private func stepSetClaimCode() {
        if let claimCode = self.targetDevice.claimCode {
            self.targetDevice.transceiver!.sendSetClaimCode(claimCode: claimCode) { result in
                self.log("targetDevice.sendSetClaimCode: \(result.description())")
                if (self.canceled) {
                    return
                }
                if (result == .NONE) {
                    self.stepComplete()
                } else {
                    self.handleBluetoothErrorResult(result)
                }
            }
        } else {
            self.stepComplete()
        }
    }




    //MARK: GetUserNetworkSelection
    private func stepGetUserNetworkSelection() {
        //adding more devices to same network
        if (self.selectedNetworkInfo != nil) {
            self.stepComplete()
            return
        }

        self.delegate.meshSetupDidEnterState(state: .TargetDeviceScanningForNetworks)
        self.scanNetworks(onComplete: self.getUserNetworkSelection)
    }

    private func scanNetworks(onComplete: @escaping () -> ()) {
        self.targetDevice.transceiver!.sendScanNetworks { result, networks in
            self.log("sendScanNetworks: \(result.description()), networksCount: \(networks?.count as Optional)\n\(networks as Optional)")
            if (self.canceled) {
                return
            }
            if (result == .NONE) {
                self.targetDevice.networks = self.removeRepeatedNetworks(networks!)
                onComplete()
            } else {
                self.handleBluetoothErrorResult(result)
            }
        }
    }

    //TODO: GET /v1/networks to get device count
    func rescanNetworks() -> MeshSetupFlowError? {
        //only allow to rescan if current step asks for it and transceiver is free to be used
        guard let isBusy = targetDevice.transceiver?.isBusy, isBusy == false else {
            return .IllegalOperation
        }

        if (self.currentCommand == .GetUserNetworkSelection) {
            self.scanNetworks(onComplete: self.getUserNetworkSelection)
        } else if (self.currentCommand == .OfferSelectOrCreateNetwork) {
            self.scanNetworks(onComplete: self.getUserMeshSetupChoice)
        } else {
            return .IllegalOperation
        }

        return nil
    }


    private func getUserNetworkSelection() {
        self.delegate.meshSetupDidRequestToSelectNetwork(availableNetworks: self.targetDevice.networks!)
    }

    func setSelectedNetwork(selectedNetwork: MeshSetupNetworkInfo) -> MeshSetupFlowError? {
        guard currentCommand == .GetUserNetworkSelection else {
            return .IllegalOperation
        }

        self.selectedNetworkInfo = selectedNetwork
        self.stepComplete()

        return nil
    }


    //MARK: GetCommissionerDeviceInfo
    private func stepGetCommissionerDeviceInfo() {
        //adding more devices to same network
        if (self.commissionerDevice?.credentials != nil) {
            //we need to put the commissioner into listening mode by sending the command
            self.commissionerDevice!.transceiver!.sendStarListening { result in
                self.log("commissionerDevice.sendStarListening: \(result.description())")
                if (self.canceled) {
                    return
                }
                if (result == .NONE) {
                    self.stepComplete()
                } else {
                    self.handleBluetoothErrorResult(result)
                }
            }
            return
        }

        self.delegate.meshSetupDidRequestCommissionerDeviceInfo()
    }

    func setCommissionerDeviceInfo(dataMatrix: MeshSetupDataMatrix) -> MeshSetupFlowError? {
        guard currentCommand == .GetCommissionerDeviceInfo else {
            return .IllegalOperation
        }

        self.commissionerDevice = MeshDevice()

        self.log("dataMatrix: \(dataMatrix)")
        self.commissionerDevice!.type = ParticleDeviceType(serialNumber: dataMatrix.serialNumber)
        self.log("self.commissionerDevice.type?.description = \(self.commissionerDevice!.type?.description as Optional)")
        self.commissionerDevice!.credentials = MeshSetupPeripheralCredentials(name: self.targetDevice.type!.description + "-" + dataMatrix.serialNumber.suffix(6), mobileSecret: dataMatrix.mobileSecret)

        self.stepComplete()

        return nil
    }


    //MARK: ConnectToCommissionerDevice
    private func stepConnectToCommissionerDevice() {
        //adding more devices to same network, no need reconnect to commissioner
        if (self.commissionerDevice?.transceiver != nil) {
            self.stepComplete()
            return
        }

        if (self.bluetoothManager.state != .Ready) {
            self.fail(withReason: .BluetoothDisabled)
            return
        }

        self.bluetoothManager.createConnection(with: self.commissionerDevice!.credentials!)
        self.delegate.meshSetupDidEnterState(state: .CommissionerDeviceConnected)
    }

    private func commissionerDeviceConnected(connection: MeshSetupBluetoothConnection) {
        self.commissionerDevice!.transceiver = MeshSetupProtocolTransceiver(connection: connection)
        self.stepComplete()
    }


    //MARK: EnsureCommissionerNetworkMatches
    private func stepEnsureCommissionerNetworkMatches() {
        self.commissionerDevice!.transceiver!.sendGetNetworkInfo { result, networkInfo in
            self.log("commissionerDevice.sendGetNetworkInfo: \(result.description()), networkInfo: \(networkInfo as Optional)")
            if (self.canceled) {
                return
            }

            if (result == .NOT_FOUND) {
                self.commissionerDevice!.networkInfo = nil
            } else if (result == .NONE) {
                self.commissionerDevice!.networkInfo = networkInfo
            } else {
                self.handleBluetoothErrorResult(result)
                return
            }

            if (self.selectedNetworkInfo?.extPanID == self.commissionerDevice!.networkInfo?.extPanID) {
                self.stepComplete()
            } else {
                //drop connection with current peripheral
                let connection = self.commissionerDevice!.transceiver!.connection
                self.commissionerDevice!.transceiver = nil
                self.commissionerDevice = nil
                self.bluetoothManager.dropConnection(with: connection)

                //TODO: rollback to correct step?
                self.fail(withReason: .CommissionerNetworkDoesNotMatch, severity: .Fatal)
            }
        }
    }



    //MARK: EnsureCorrectSelectedNetworkPassword
    private func stepEnsureCorrectSelectedNetworkPassword() {
        if (self.selectedNetworkPassword != nil) {
            self.stepComplete()
            return
        }

        self.delegate.meshSetupDidRequestToEnterSelectedNetworkPassword()
    }

    func setSelectedNetworkPassword(_ password: String, onComplete:@escaping (MeshSetupFlowError?) -> ()) {
        guard currentCommand == .EnsureCorrectSelectedNetworkPassword else {
            onComplete(.IllegalOperation)
            return
        }

        guard self.validateNetworkPassword(password) else {
            onComplete(.PasswordTooShort)
            return
        }

        self.log("password set: \(password)")
        self.selectedNetworkPassword = password

        /// NOT_FOUND: The device is not a member of a network
        /// NOT_ALLOWED: Invalid commissioning credential
        self.commissionerDevice!.transceiver!.sendAuth(password: password) { result in
            if (self.canceled) {
                return
            }
            self.log("commissionerDevice.sendAuth: \(result.description())")
            if (result == .NONE) {
                onComplete(nil)
                self.stepComplete()
            } else if (result == .NOT_ALLOWED) {
                onComplete(.WrongNetworkPassword)
            } else {
                self.handleBluetoothErrorResult(result)
            }
        }
    }


    //MARK: JoinNetwork
    private func stepJoinSelectedNetwork() {
        self.delegate.meshSetupDidEnterState(state: .JoiningNetworkStarted)
        /// NOT_ALLOWED: The client is not authenticated
        self.commissionerDevice!.transceiver!.sendStartCommissioner { result in
            self.log("commissionerDevice.sendStartCommissioner: \(result.description())")
            if (self.canceled) {
                return
            }
            if result == .NONE {
                self.prepareJoiner()
            } else {
                self.handleBluetoothErrorResult(result)
            }
        }
    }

    private func prepareJoiner() {
        /// ALREADY_EXIST: The device is already a member of a network
        /// NOT_ALLOWED: The client is not authenticated
        self.targetDevice.transceiver!.sendPrepareJoiner(networkInfo: self.selectedNetworkInfo!) { result, eui64, password in
            self.log("targetDevice.sendPrepareJoiner sent networkInfo: \(self.selectedNetworkInfo!)")
            if (self.canceled) {
                return
            }
            self.log("targetDevice.sendPrepareJoiner: \(result.description())")
            if (result == .NONE) {
                self.targetDevice.joinerCredentials = (eui64: eui64!, password: password!)
                self.addJoiner()
            } else {
                self.handleBluetoothErrorResult(result)
            }
        }
    }

    private func addJoiner() {
        self.delegate.meshSetupDidEnterState(state: .JoiningNetworkStep1Done)
        /// NO_MEMORY: No memory available to add the joiner
        /// INVALID_STATE: The commissioner role is not started
        /// NOT_ALLOWED: The client is not authenticated
        self.commissionerDevice!.transceiver!.sendAddJoiner(eui64: self.targetDevice.joinerCredentials!.eui64, password: self.targetDevice.joinerCredentials!.password) { result in
            self.log("commissionerDevice.sendAddJoiner: \(result.description())")
            if (self.canceled) {
                return
            }
            if (result == .NONE) {
                self.log("Delaying call to joinNetwork")
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .seconds(10)) {
                    if (self.canceled) {
                        return
                    }

                    self.joinNetwork()
                }
            } else {
                self.handleBluetoothErrorResult(result)
            }
        }
    }

    private func joinNetwork() {
        self.log("Sending join network")
        /// NOT_FOUND: No joinable network was found
        /// TIMEOUT: The join process timed out
        /// NOT_ALLOWED: Invalid security credentials
        self.targetDevice.transceiver!.sendJoinNetwork { result in
            self.log("targetDevice.sendJoinNetwork: \(result.description())")
            if (self.canceled) {
                return
            }

            var failureReason: MeshSetupFlowError? = nil

            if (result == .NONE) {
                self.stopCommissioner()
            } else if (result == .NOT_ALLOWED) {
                failureReason = .DeviceIsNotAllowedToJoinNetwork
            } else if (result == .NOT_FOUND) {
                failureReason = .DeviceIsUnableToFindNetworkToJoin
            } else if (result == .TIMEOUT) {
                failureReason = .DeviceTimeoutWhileJoiningNetwork
            } else {
                self.handleBluetoothErrorResult(result)
            }


            if let reason = failureReason {
                let recoveryLeaveNetwork = {
                    self.targetDevice.transceiver!.sendLeaveNetwork() { result in
                        self.log("targetDevice.sendLeaveNetwork: \(result.description())")
                        if (self.canceled) {
                            return
                        }
                        if (result == .NONE) {
                            self.fail(withReason: reason)
                        } else {
                            self.handleBluetoothErrorResult(result)
                        }
                    }
                }

                self.commissionerDevice!.transceiver!.sendStopCommissioner { result in
                    self.log("commissionerDevice.sendStopCommissioner: \(result.description())")
                    if (self.canceled) {
                        return
                    }
                    if (result == .NONE) {
                        if (!self.canceled) {
                            recoveryLeaveNetwork()
                        }
                    } else {
                        self.handleBluetoothErrorResult(result)
                    }
                }
            }
         }
    }

    private func stopCommissioner() {
        self.delegate.meshSetupDidEnterState(state: .JoiningNetworkStep2Done)
        /// NOT_ALLOWED: The client is not authenticated
        self.commissionerDevice!.transceiver!.sendStopCommissioner { result in
            self.log("commissionerDevice.sendStopCommissioner: \(result.description())")
            if (self.canceled) {
                return
            }
            if (result == .NONE) {
                self.setSetupDone()
            } else {
                self.handleBluetoothErrorResult(result)
            }
         }
    }

    private func setSetupDone() {
        self.targetDevice.transceiver!.sendDeviceSetupDone (done: true) { result in
            self.log("targetDevice.sendDeviceSetupDone: \(result.description())")
            if (self.canceled) {
                return
            }
            if (result == .NONE) {
                self.stopCommissionerListening()
            } else {
                self.handleBluetoothErrorResult(result)
            }
        }
    }


    private func stopCommissionerListening() {
        self.commissionerDevice!.transceiver!.sendStopListening { result in
            self.log("commissionerDevice.sendStopListening: \(result.description())")
            if (self.canceled) {
                return
            }
            if (result == .NONE) {
                self.stopTargetDeviceListening(onComplete: self.stepComplete)
            } else {
                self.handleBluetoothErrorResult(result)
            }
        }
    }

    private func stopTargetDeviceListening(onComplete: @escaping () -> ()) {
        self.targetDevice.transceiver!.sendStopListening { result in
            self.log("targetDevice.sendStopListening: \(result.description())")
            if (self.canceled) {
                return
            }
            if (result == .NONE) {
                onComplete()
            } else {
                self.handleBluetoothErrorResult(result)
            }
        }
    }

    //MARK: CheckDeviceGotClaimed
    private func checkTargetDeviceGotConnected() {
        if (self.currentStepFlags["checkTargetDeviceGotConnectedStartTime"] == nil) {
            self.currentStepFlags["checkTargetDeviceGotConnectedStartTime"] = Date()
        }

        let diff = Date().timeIntervalSince(self.currentStepFlags["checkTargetDeviceGotConnectedStartTime"] as! Date)
        if (diff > MeshSetup.deviceConnectToCloudTimeout) {
            self.currentStepFlags["checkTargetDeviceGotConnectedStartTime"] = nil
            self.fail(withReason: .DeviceConnectToCloudTimeout)
            return
        }

        self.targetDevice.transceiver!.sendGetConnectionStatus { result, status in
            self.log("targetDevice.sendGetConnectionStatus: \(result.description())")
            if (self.canceled) {
                return
            }
            if (result == .NONE) {
                self.log("status: \(status as Optional)")
                if (status! == .connected) {
                    self.log("device connected to the cloud")
                    if (self.currentFlow == self.ethernetFlow) {
                        self.delegate.meshSetupDidEnterState(state: .TargetDeviceConnectingToInternetStep1Done)
                    }
                    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .seconds(1)) {
                        if (self.canceled) {
                            return
                        }
                        self.checkTargetDeviceGotClaimed()
                    }
                } else {
                    self.log("device did NOT connect yet")
                    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .seconds(3)) {
                        if (self.canceled) {
                            return
                        }
                        self.checkTargetDeviceGotConnected()
                    }
                }
            } else {
                self.handleBluetoothErrorResult(result)
            }
        }
    }

    private func checkTargetDeviceGotClaimed() {
        if let isClaimed = self.targetDevice.isClaimed, isClaimed == true {
            self.deviceGotClaimed()
            return
        }

        if (self.currentStepFlags["checkTargetDeviceGotClaimedStartTime"] == nil) {
            self.currentStepFlags["checkTargetDeviceGotClaimedStartTime"] = Date()
        }

        let diff = Date().timeIntervalSince(self.currentStepFlags["checkTargetDeviceGotClaimedStartTime"] as! Date)
        if (diff > MeshSetup.deviceGettingClaimedTimeout) {
            self.currentStepFlags["checkTargetDeviceGotClaimedStartTime"] = nil
            fail(withReason: .DeviceGettingClaimedTimeout)
            return
        }

        ParticleCloud.sharedInstance().getDevices { devices, error in
            if (self.canceled) {
                return
            }

            guard error == nil else {
                self.fail(withReason: .DeviceGettingClaimedTimeout, nsError: error!)
                return
            }

            if let devices = devices {
                for device in devices {
                    if (device.id == self.targetDevice.deviceId!) {
                        self.deviceGotClaimed()
                        return
                    }
                }
            }

            self.log("device was NOT successfully claimed")
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .seconds(1)) {
                self.checkTargetDeviceGotClaimed()
            }
        }
    }

    private func deviceGotClaimed() {
        self.log("device was successfully claimed")
        if (self.currentFlow == self.ethernetFlow) {
            self.delegate.meshSetupDidEnterState(state: .TargetDeviceConnectingToInternetCompleted)
        } else if (self.currentFlow == self.joinerFlow) {
            self.delegate.meshSetupDidEnterState(state: .JoiningNetworkCompleted)
        }
        self.stepComplete()
    }



    //MARK: EnsureHasInternetAccess
    private func stepEnsureHasInternetAccess() {
        //we only use ethernet!!!
        if let _ = self.targetDevice.getEthernetInterfaceIdx() {
            self.delegate.meshSetupDidEnterState(state: .TargetDeviceConnectingToInternetStarted)

            self.targetDevice.transceiver!.sendDeviceSetupDone (done: true) { result in
                self.log("targetDevice.transceiver!.sendDeviceSetupDone: \(result.description())")
                if (self.canceled) {
                    return
                }
                if (result == .NONE) {
                    self.stopTargetDeviceListening(onComplete: self.checkDeviceHasIP)
                } else {
                    self.handleBluetoothErrorResult(result)
                }
            }
        } else {
            self.fail(withReason: .FailedToObtainIp)
            return
        }
    }

    private func checkDeviceHasIP() {
        if (self.currentStepFlags["checkDeviceHasIPStartTime"] == nil) {
            self.currentStepFlags["checkDeviceHasIPStartTime"] = Date()
        }

        let diff = Date().timeIntervalSince(self.currentStepFlags["checkDeviceHasIPStartTime"] as! Date)
        if (diff > MeshSetup.deviceObtainedIPTimeout) {
            self.currentStepFlags["checkDeviceHasIPStartTime"] = nil
            self.fail(withReason: .FailedToObtainIp)
            return
        }

        self.targetDevice.transceiver!.sendGetInterface(interfaceIndex: self.targetDevice.getEthernetInterfaceIdx()!) { result, interface in
            self.log("result: \(result.description()), networkInfo: \(interface as Optional)")
            if (self.canceled) {
                return
            }
            if (interface!.ipv4Config.addresses.first != nil) {
                self.targetDevice.hasInternetAddress = true
                self.stepComplete()
            } else {
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .seconds(1)) {
                    if (self.canceled) {
                        return
                    }
                    self.checkDeviceHasIP()
                }
            }
        }
    }

    //MARK: StopTargetDeviceListening
    private func stepStopTargetDeviceListening() {
        self.stopTargetDeviceListening(onComplete: self.stepComplete)
    }

    //MARK: CheckDeviceGotClaimed
    private func stepCheckDeviceGotClaimed() {
        self.checkTargetDeviceGotConnected()
    }

    //MARK: GetNewDeviceName
    private func stepGetNewDeviceName() {
        self.delegate.meshSetupDidRequestToEnterDeviceName()
    }

    func setDeviceName(name: String, onComplete:@escaping (MeshSetupFlowError?) -> ()) {
        guard currentCommand == .GetNewDeviceName else {
            onComplete(.IllegalOperation)
            return
        }

        guard self.validateDeviceName(name) else {
            onComplete(.NameTooShort)
            return
        }

        ParticleCloud.sharedInstance().getDevice(self.targetDevice.deviceId!) { device, error in
            if (self.canceled) {
                return
            }

            if (error == nil) {
                device!.rename(name) { error in
                    if error == nil {
                        onComplete(nil)
                        self.stepComplete()
                    } else {
                        onComplete(.UnableToRenameDevice)
                        return
                    }
                }
            } else {
                onComplete(.UnableToRenameDevice)
                return
            }
        }
    }



    //MARK:OfferToAddOneMoreDevice
    private func stepOfferToAddOneMoreDevice() {
        //disconnect current device
        if (self.targetDevice.transceiver != nil) {
            self.log("Dropping connection to target device")
            let connection = self.targetDevice.transceiver!.connection
            self.targetDevice.transceiver = nil
            self.bluetoothManager.dropConnection(with: connection)
        }

        self.delegate.meshSetupDidRequestToAddOneMoreDevice()
    }


    func setAddOneMoreDevice(addOneMoreDevice: Bool) -> MeshSetupFlowError? {
        guard currentCommand == .OfferToAddOneMoreDevice else {
            return .IllegalOperation
        }

        if (addOneMoreDevice) {
            self.currentStep = 0
            self.currentFlow = preflow
            self.runCurrentStep()
        } else {
            self.finishSetup()
        }

        return nil
    }


    //MARK: OfferToFinishSetupEarly
    private func stepOfferToFinishSetupEarly() {
        self.delegate.meshSetupDidRequestToFinishSetupEarly()
    }

    func setFinishSetupEarly(finish: Bool) -> MeshSetupFlowError? {
        guard currentCommand == .OfferToFinishSetupEarly else {
            return .IllegalOperation
        }

        if (finish) {
            self.finishSetup()
        } else {
            self.stepComplete()
        }

        return nil
    }

    //MARK: OfferSelectOrCreateNetwork
    private func stepOfferSelectOrCreateNetwork() {
        //we might retry step because scan network failed.. so we only test for this condition and ignore password/name condition
        //adding more devices to same network
        if (self.selectedNetworkInfo != nil) {
            self.stepComplete()
            return
        }

        self.delegate.meshSetupDidEnterState(state: .TargetGatewayDeviceScanningForNetworks)
        self.scanNetworks(onComplete: self.getUserMeshSetupChoice)
    }

    private func getUserMeshSetupChoice() {
        self.delegate.meshSetupDidRequestToSelectOrCreateNetwork(availableNetworks: self.targetDevice.networks!)
    }

    func setSelectOrCreateNetwork(selectedNetwork: MeshSetupNetworkInfo?) -> MeshSetupFlowError? {
        guard currentCommand == .OfferSelectOrCreateNetwork else {
            return .IllegalOperation
        }

        if let selectedNetwork = selectedNetwork {
            self.selectedNetworkInfo = selectedNetwork
            self.stepComplete()
        } else {
            //TODO: split into three steps
            self.delegate.meshSetupDidRequestToEnterNewNetworkNameAndPassword()
        }

        return nil
    }

    func setNewNetwork(name: String, password: String) -> MeshSetupFlowError? {
        guard currentCommand == .OfferSelectOrCreateNetwork else {
            return .IllegalOperation
        }

        guard self.validateNetworkName(name) else {
            return .NameTooShort
        }

        guard self.validateNetworkPassword(password) else {
            return .PasswordTooShort
        }

        self.log("set network name: \(name) password: \(password)")
        self.newNetworkName = name
        self.newNetworkPassword = password

        self.stepComplete()

        return nil
    }



    //MARK: CreateNetwork
    private func stepCreateNetwork() {
        self.delegate.meshSetupDidEnterState(state: .CreateNetworkStarted)

        self.targetDevice.transceiver!.sendCreateNetwork(name: self.newNetworkName!, password: self.newNetworkPassword!) { result, networkInfo in
            self.log("targetDevice.sendCreateNetwork: \(result.description()), networkInfo: \(networkInfo as Optional)")
            if (self.canceled) {
                return
            }
            if (result == .NONE) {
                self.log("Setting current target device as commissioner device")
                self.commissionerDevice = self.targetDevice
                self.selectedNetworkInfo = networkInfo!
                self.selectedNetworkPassword = self.newNetworkPassword
                self.targetDevice = MeshDevice()

                self.delegate.meshSetupDidEnterState(state: .CreateNetworkStep1Done)
                self.delegate.meshSetupDidEnterState(state: .CreateNetworkStep2Done)
                self.delegate.meshSetupDidEnterState(state: .CreateNetworkStep3Done)
                self.delegate.meshSetupDidEnterState(state: .CreateNetworkCompleted)

                self.delegate.meshSetupDidCreateNetwork(network: networkInfo!)

                self.stepComplete()
            } else {
                self.handleBluetoothErrorResult(result)
            }
        }
    }
}