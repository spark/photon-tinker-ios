//
// Created by Raimundas Sakalauskas on 2019-03-02.
// Copyright (c) 2019 spark. All rights reserved.
//

import Foundation

protocol MeshSetupStepDelegate {
    func stepCompleted(_ sender: MeshSetupStep)
    func rewindTo(_ sender: MeshSetupStep, step: MeshSetupStep.Type) -> MeshSetupStep
    func fail(withReason reason: MeshSetupFlowError, severity: MeshSetupErrorSeverity, nsError: Error?)
}

class MeshSetupStep: NSObject {
    var context: MeshSetupContext!

    func log(_ message: String) {
        ParticleLogger.logInfo("MeshSetupFlow", format: message, withParameters: getVaList([]))
    }

    func run(context: MeshSetupContext) {
        self.context = context

        self.start()
    }

    func stepCompleted() {
        self.context.stepDelegate.stepCompleted(self)

        self.context = nil
    }

    func reset() {
        //clear step flags
    }

    func start() {
        //entry to the step
    }

    func retry() {
        self.start()
    }

    func handleBluetoothErrorResult(_ result: ControlReplyErrorType) {
        if (self.context.canceled) {
            return
        }

        if (result == .TIMEOUT && !self.context.bluetoothReady) {
            self.fail(withReason: .BluetoothDisabled)
        } else if (result == .TIMEOUT) {
            self.fail(withReason: .BluetoothTimeout)
        } else if (result == .INVALID_STATE) {
            self.fail(withReason: .InvalidDeviceState, severity: .Fatal)
        } else {
            self.fail(withReason: .BluetoothError)
        }
    }

    func fail(withReason reason: MeshSetupFlowError, severity: MeshSetupErrorSeverity = .Error, nsError: Error? = nil) {
        self.context.stepDelegate.fail(withReason: reason, severity: severity, nsError: nsError)
    }

    func handleBluetoothConnectionManagerError(_ error: BluetoothConnectionManagerError) -> Bool {
        return false
    }

    func handleBluetoothConnectionManagerConnectionCreated(_ connection: MeshSetupBluetoothConnection) -> Bool {
        return false
    }

    func handleBluetoothConnectionManagerConnectionBecameReady(_ connection: MeshSetupBluetoothConnection) -> Bool {
        return false
    }

    func handleBluetoothConnectionManagerConnectionDropped(_ connection: MeshSetupBluetoothConnection) -> Bool {
        return false
    }




}