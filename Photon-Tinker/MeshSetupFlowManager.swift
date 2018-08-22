//
//  MeshSetupFlowManager.swift
//  Particle
//
//  Created by Ido Kleinman on 7/3/18.
//  Copyright © 2018 spark. All rights reserved.
//

import Foundation

// TODO: define flows
enum MeshSetupFlowType {
    case None
    case Detecting
    case InitialXenon
    case InitialArgon
    case InitialBoron
    case InitialESP32 // future
    case ModifyXenon // future
    case ModifyArgon // future
    case ModifyBoron // future
    case ModifyESP32 // future
    case Diagnostics // future
    
}


enum MeshSetupErrorSeverity {
    case Info
    case Warning
    case Error
    case Fatal
}

// TODO: aggregate all possible errors and attach string as data type
enum MeshSetupFlowErrorType {
    case CommissionerNetworksMismatch
    case BluetoothConnectionError
    case BluetoothConnectionManagerError
    case BluetoothNotReady
    case BluetoothDisabled
    case DeviceNotSupported
    case FlowNotSupported // (device already claimed or any other thing)
    case MessageTimeout
    case ParticleCloudClaimCodeFailed
    case ParticleCloudDeviceListFailed
    case JoinerAlreadyOnMeshNetwork
    case CouldNotClaimDevice // basically == device cloud connection timeout
    case CouldNotNameDevice
    case InvalidNetworkPassword
    case NotAuthenticated // tried StartCommissionerRequest but commissioner password was not provided
    case UnknownFlowError
    
    
}

// future
enum flowErrorAction {
    case Dialog
    case Pop
    case Fail
}


enum MeshSetupDeviceRole {
    case Joiner
    case Commissioner
}

protocol MeshSetupFlowManagerDelegate {
    //    required
    func flowError(error : String, severity : MeshSetupErrorSeverity, action : flowErrorAction) //
    // TODO: make these optional
    func scannedNetworks(networks: [String]?) // joiner returned detected mesh networks (or empty array if none)
    func flowManagerReady() // flow manager ready to start the flow
    func networkMatch() // commissioner network matches the user selection - can proceed to ask for password + commissioning
    func authSuccess()
    func joinerPrepared()
    func joinedNetwork()
    func deviceOnlineClaimed()
    func deviceNamed()
}

// Extension to protocol to create hack for optionals
/*
extension MeshSetupFlowManagerDelegate {
    func scannedNetworks(networks: [String]?) {}
    func flowManagerReady() {}
    func networkMatch() {}
}

*/

struct PeripheralCredentials {
    var name: String
    var secret: String
}

class MeshSetupFlowManager: NSObject, MeshSetupBluetoothConnectionManagerDelegate {
    
    var joinerProtocol : MeshSetupProtocolTransceiver?
    var commissionerProtocol : MeshSetupProtocolTransceiver?
    var joinerDeviceType : ParticleDeviceType?
    var commissionerDeviceType : ParticleDeviceType?
    var networkPassword : String? {
        didSet {
            self.currentFlow?.networkPassword = networkPassword
        }
    }
    var networkName : String? {
        didSet {
            self.currentFlow?.networkName = networkName
        }
    }
    var deviceName : String? {
        didSet {
            self.currentFlow?.deviceName = deviceName
        }
    }
    var delegate : MeshSetupFlowManagerDelegate?
    var bluetoothManagerReady = false


    var joinerPeripheralCredentials: PeripheralCredentials? {
        didSet {
            print("joinerPeripheralName didSet")
            self.createBluetoothConnection(with: joinerPeripheralCredentials!)
        }
    }
    var commissionerPeripheralCredentials: PeripheralCredentials? {
        didSet {
            print("commissionerPeripheralName didSet")
            self.createBluetoothConnection(with: commissionerPeripheralCredentials!)
        }
    }
    
    private var bluetoothManager : MeshSetupBluetoothConnectionManager?
    private var flowType : MeshSetupFlowType = .None // TODO: do we even need this?
    private var currentFlow : MeshSetupFlow?
    private var isReady : Bool = false
    
    // meant to be initialized after choosing device type + scanning sticker
    required init(delegate : MeshSetupFlowManagerDelegate) {
        super.init()
        self.delegate = delegate
        self.bluetoothManager = MeshSetupBluetoothConnectionManager(delegate : self)
    }
    
    func startFlow(with deviceType : ParticleDeviceType, as deviceRole : MeshSetupDeviceRole, dataMatrix : String) -> Bool {
        
        print("startFlow called - \(deviceRole)")
        if !bluetoothManagerReady {
            return false
        }
        // TODO: add support for "any" device type by scanning and pairing to SN suffix wildcard only (for commissioner) - TBD - break out to a seperate function
        let (serialNumber, mobileSecret) = self.processDataMatrix(dataMatrix: dataMatrix)
        switch deviceRole {
        case .Joiner :
            self.joinerPeripheralCredentials = PeripheralCredentials(name: deviceType.description+"-"+serialNumber.suffix(6), secret: mobileSecret)
            self.joinerDeviceType = deviceType
            self.flowType = .Detecting
        case .Commissioner :
            self.commissionerPeripheralCredentials = PeripheralCredentials(name: deviceType.description+"-"+serialNumber.suffix(6), secret: mobileSecret)
            self.commissionerDeviceType = deviceType
//            self.flowType = ...
        }
        
        return true

    }
    
    func bluetoothConnectionManagerReady() {
        print("bluetoothConnectionManagerReady")
        
        self.bluetoothManagerReady = true
        if (!self.isReady) {
            self.isReady = true
            self.delegate?.flowManagerReady()
        }
        
        
//        self.createBluetoothConnection(with: self.joinerPeripheralName!)
    }
    
    
    func bluetoothConnectionError(connection: MeshSetupBluetoothConnection, error: String, severity: MeshSetupErrorSeverity) {
        print("bluetoothConnectionError [\(connection.peripheralName ?? "peripheral")] \(severity): \(error)")
        self.delegate?.flowError(error: error, severity: severity, action: .Dialog) // TODO: figure out action per error
    }
    
    func bluetoothConnectionManagerError(error: String, severity: MeshSetupErrorSeverity) {
        print("bluetoothConnectionManagerError -- \(severity): \(error)")
        self.delegate?.flowError(error: error, severity: severity, action: .Dialog) // TODO: figure out action per error
        // TODO: analyze error and sometimes:
//        self.bluetoothManagerReady = false
    }
    
    func bluetoothConnectionCreated(connection: MeshSetupBluetoothConnection) {
        print("BLE connection with \(connection.peripheralName!) created")
        // waiting for connection ready
    }
//    func bluetoothConnectionCreated(connection: MeshSetupBluetoothConnection) {
    func bluetoothConnectionReady(connection: MeshSetupBluetoothConnection) {
        if let joiner = joinerPeripheralCredentials {
            if connection.peripheralName! == joiner.name {
                
                print("Joiner BLE connection with \(connection.peripheralName!) ready - setting up flow")
                
                
                switch self.joinerDeviceType! {
                case .xenon :
                    self.currentFlow = MeshSetupInitialXenonFlow(flowManager: self)
                    self.joinerProtocol = MeshSetupProtocolTransceiver(delegate: self.currentFlow!, connection: connection, role: .Joiner)
                    self.flowType = .InitialXenon
                    self.currentFlow!.start()
                default:
                    self.delegate?.flowError(error: "Device not supported yet", severity: .Fatal, action: .Fail)
                    return
                }
                // TODO: the right thing - pass the decision to current flow, stop being protocol delegate
//                self.joinerProtocol?.sendIsClaimed()
            }
        }
        
        if let comm = commissionerPeripheralCredentials {
            if connection.peripheralName! == comm.name {
                self.commissionerProtocol = MeshSetupProtocolTransceiver(delegate: self.currentFlow!, connection: connection, role : .Commissioner)
                print("Commissioner BLE connection with \(connection.peripheralName!) ready")
                self.currentFlow!.startCommissioner()
            }
        }


    }
    
    func createBluetoothConnection(with credentials: PeripheralCredentials) {
        let bleReady = self.bluetoothManager!.createConnection(with: credentials)
        if bleReady == false {
            // TODO: handle flow
            self.delegate?.flowError(error: "BLE is not ready to create connection with \(credentials)", severity: .Error, action: .Pop)
            print ("Bluetooth not ready")
        }
    }
    
    
    func bluetoothConnectionDropped(connection: MeshSetupBluetoothConnection) {

        print("Connection to \(connection.peripheralName!) was dropped")
        if let joiner = joinerPeripheralCredentials {
            if connection.peripheralName! == joiner.name {
                self.joinerProtocol = nil
                self.isReady = false // TODO: check this assumption
            }
        }
        
        if let comm = commissionerPeripheralCredentials {
            if connection.peripheralName! == comm.name {
                self.commissionerProtocol = nil
            }
        }

        // TODO: check if it was intentional or not via flow - if it wasn't then report an error
        self.delegate?.flowError(error: "BLE connection to \(connection.peripheralName!) was dropped", severity: .Error, action: .Fail) // TODO: figure out action per error


    }
    

    private func processDataMatrix(dataMatrix : String) -> (serialNumer : String, mobileSecret : String) {
        let arr = dataMatrix.split(separator: " ")
        let serialNumber = String(arr[0])//"12345678abcdefg"
        let mobileSecret = String(arr[1])//"ABCDEFGHIJKLMN"
        return (serialNumber, mobileSecret)
    }
    
    func abortFlow() {
        self.bluetoothManager?.dropAllConnections()
//        self.joinerProtocol = nil
//        self.commissionerProtocol = nil
    }
    
  
    
    func commissionDeviceToNetwork() {
        print("commissionDeviceToNetwork manager")
        self.currentFlow!.commissionDeviceToNetwork()
    }
  
    
    // MARK: MeshSetupBluetoothManaherDelegate
    func bluetoothDisabled() {
        self.flowType = .None
        self.delegate?.flowError(error: "Bluetooth is disabled, please enable bluetooth on your phone to setup your device", severity: .Fatal, action: .Fail)
//        self.delegate?.errorBluetoothDisabled()
    }
    
    
    

}
