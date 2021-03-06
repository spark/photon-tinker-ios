//
// Created by Raimundas Sakalauskas on 9/20/18.
// Copyright (c) 2018 Particle. All rights reserved.
//

import UIKit

class Gen3SetupSelectOrCreateNetworkViewController: Gen3SetupSelectNetworkViewController {

    override class var nibName: String {
        return "Gen3SetupNetworkListWithCreateView"
    }

    @IBOutlet weak var createNetworkButton: ParticleAlternativeButton!
    



    override func setStyle() {
        super.setStyle()
        createNetworkButton.setStyle(font: ParticleStyle.BoldFont, size: ParticleStyle.RegularSize)
    }

    override func setContent() {
        titleLabel.text = Gen3SetupStrings.CreateOrSelectNetwork.Title
        createNetworkButton.setTitle(Gen3SetupStrings.CreateOrSelectNetwork.CreateNetwork, for: .normal)
    }

    @IBAction func createNetworkButtonTapped(_ sender: Any) {
        self.callback(nil)

        self.fade()
    }

    override func resume(animated: Bool) {
        super.resume(animated: animated)

        ParticleSpinner.hide(view, animated: animated)
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        super.tableView(tableView, didSelectRowAt: indexPath)

        self.fade()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        addFadableViews()
    }

    private func addFadableViews() {
        if viewsToFade == nil {
            viewsToFade = [UIView]()
        }

        viewsToFade!.append(titleLabel)
        viewsToFade!.append(networksTableView)
        viewsToFade!.append(createNetworkButton)
    }



}
