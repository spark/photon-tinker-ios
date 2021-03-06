//
// Created by Raimundas Sakalauskas on 2019-03-15.
// Copyright (c) 2019 Particle. All rights reserved.
//

import Foundation

class Gen3SetupControlPanelMeshViewController : Gen3SetupControlPanelRootViewController {
    private let refreshControl = UIRefreshControl()

    override var allowBack: Bool {
        get {
            return true
        }
        set {
            super.allowBack = newValue
        }
    }
    override var customTitle: String {
        return Gen3SetupStrings.ControlPanel.Mesh.Title
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        self.prepareContent()
        self.tableView.reloadData()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        if #available(iOS 10.0, *) {
            tableView.refreshControl = refreshControl
        } else {
            tableView.addSubview(refreshControl)
        }

        refreshControl.tintColor = ParticleStyle.SecondaryTextColor
        refreshControl.addTarget(self, action: #selector(refreshData(_:)), for: .valueChanged)
    }

    @objc private func refreshData(_ sender: Any) {
        self.fadeContent(animated: true, showSpinner: false)
        self.callback(.mesh)
    }

    override func resume(animated: Bool) {
        self.prepareContent()

        super.resume(animated: animated)

        self.tableView.refreshControl?.endRefreshing()
    }

    override func prepareContent() {
        if (self.context.targetDevice.meshNetworkInfo != nil) {
            cells = [[.meshInfoNetworkName, .meshInfoNetworkID, .meshInfoNetworkExtPanID, .meshInfoNetworkPanID, .meshInfoNetworkChannel, .meshInfoNetworkDeviceCount], [.meshInfoDeviceRole], [.actionLeaveMeshNetwork]]
        } else {
            cells = [[.meshInfoNetworkName], [.actionAddToMeshNetwork]]
        }
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
            case 0:
                return Gen3SetupStrings.ControlPanel.Mesh.NetworkInfo
            case 1:
                if (self.context.targetDevice.meshNetworkInfo != nil) {
                    return Gen3SetupStrings.ControlPanel.Mesh.DeviceInfo
                } else {
                    return ""
                }
            default:
                return ""
        }

    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return UITableView.automaticDimension
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let command = cells[indexPath.section][indexPath.row]

        if (command == .actionLeaveMeshNetwork) {
            let alert = UIAlertController(title: Gen3SetupStrings.ControlPanel.Prompt.LeaveNetworkTitle, message: Gen3SetupStrings.ControlPanel.Prompt.LeaveNetworkText, preferredStyle: .alert)

            alert.addAction(UIAlertAction(title: Gen3SetupStrings.ControlPanel.Action.LeaveNetwork, style: .default) { action in
                super.tableView(tableView, didSelectRowAt: indexPath)
            })

            alert.addAction(UIAlertAction(title: Gen3SetupStrings.ControlPanel.Action.DontLeaveNetwork, style: .cancel) { action in

            })

            self.present(alert, animated: true)
        } else {
            super.tableView(tableView, didSelectRowAt: indexPath)
        }
    }
}
