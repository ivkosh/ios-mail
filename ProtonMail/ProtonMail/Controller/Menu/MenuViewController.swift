//
//  MenuViewController.swift
//  ProtonMail
//
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of ProtonMail.
//
//  ProtonMail is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  ProtonMail is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with ProtonMail.  If not, see <https://www.gnu.org/licenses/>.


import UIKit
import CoreData

class MenuViewController: UIViewController, ViewModelProtocol, CoordinatedNew {
    /// those two are optional
    typealias viewModelType = MenuViewModel
    typealias coordinatorType = MenuCoordinatorNew
    
    private var viewModel : MenuViewModel!
    private var coordinator : MenuCoordinatorNew?
    
    func set(viewModel: MenuViewModel) {
        self.viewModel = viewModel
    }
    func set(coordinator: MenuCoordinatorNew) {
        self.coordinator = coordinator
    }
    func getCoordinator() -> CoordinatorNew? {
        return self.coordinator
    }
    
    // MARK - Views Outlets
    @IBOutlet weak var displayNameLabel: UILabel!
    @IBOutlet weak var emailLabel: UILabel!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var headerView: UIView!
    @IBOutlet weak var snoozeButton: UIButton!
    
    @available(iOS 10.0, *)
    private lazy var notificationsSnoozer = NotificationsSnoozer()
    
    //
    private var signingOut: Bool                 = false
    
    // MARK: - Constants
    private let kMenuCellHeight: CGFloat         = 44.0
    private let kMenuOptionsWidth: CGFloat       = 300.0 //227.0
    private let kMenuOptionsWidthOffset: CGFloat = 80.0
    private let kMenuTableCellId: String  = "menu_table_cell"
    private let kLabelTableCellId: String = "menu_label_cell"
    
    // temp vars
    private var sectionClicked : Bool  = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        assert(viewModel != nil, "viewModel can't be empty")
        assert(coordinator != nil, "coordinator can't be empty")
        
        //table view delegates
        self.tableView.dataSource = self
        self.tableView.delegate = self
        
        //update rear view reveal width based on screen size
        self.updateRevealWidth()
        
        //setup labels fetch controller
        self.viewModel.setupLabels(delegate: self)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        //update rear view reveal width based on screen size
        self.updateRevealWidth()
        
        ///TODO::fixme forgot the reason
        self.revealViewController().frontViewController.view.accessibilityElementsHidden = true
        self.view.accessibilityElementsHidden = false
        self.view.becomeFirstResponder()
        self.revealViewController().frontViewController.view.isUserInteractionEnabled = false
        self.revealViewController().view.addGestureRecognizer(self.revealViewController().panGestureRecognizer())
        
        
        self.sectionClicked = false
        
        self.viewModel.updateMenuItems()
        
        updateEmailLabel()
        updateDisplayNameLabel()
        self.tableView.reloadData()
        
        if #available(iOS 10.0, *), Constants.Feature.snoozeOn {
            self.setupSnoozeButton()
            self.snoozeButton.accessibilityHint = LocalString._double_tap_to_setup
        } else {
            self.snoozeButton.isHidden = true
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.revealViewController().frontViewController.view.isUserInteractionEnabled = true
    }
    
    override var preferredStatusBarStyle : UIStatusBarStyle {
        return .lightContent
    }
    
    // MARK: - Methods
    
    func updateDisplayNameLabel() {
        let displayName = sharedUserDataService.defaultDisplayName
        if !displayName.isEmpty {
            displayNameLabel.text = displayName
        } else {
            displayNameLabel.text = emailLabel.text
        }
    }
    
    func updateEmailLabel() {
        emailLabel.text = sharedUserDataService.defaultEmail
    }
    
    func updateRevealWidth() {
        let w = UIScreen.main.bounds.width
        let offset =  (w - kMenuOptionsWidthOffset)
        self.revealViewController().rearViewRevealWidth = kMenuOptionsWidth > offset ? offset : kMenuOptionsWidth
    }
    
    func handleSignOut(_ sender : UIView?) {
        let alertController = UIAlertController(title: LocalString._logout_confirmation, message: nil, preferredStyle: .actionSheet)
        alertController.addAction(UIAlertAction(title: LocalString._sign_out, style: .destructive, handler: { (action) -> Void in
            self.signingOut = true
            UserTempCachedStatus.backup()
            sharedUserDataService.signOut(true)
            userCachedStatus.signOut()
        }))
        alertController.popoverPresentationController?.sourceView = sender ?? self.view
        alertController.popoverPresentationController?.sourceRect = (sender == nil ? self.view.frame : sender!.bounds)
        alertController.addAction(UIAlertAction(title: LocalString._general_cancel_button, style: .cancel, handler: nil))
        self.sectionClicked = false
        self.present(alertController, animated: true, completion: nil)
    }
}

@available(iOS 10.0, *)
extension MenuViewController : OptionsDialogPresenter {
    func toSettings() {
        let deepLink = DeepLink(MenuCoordinatorNew.Destination.settings.rawValue)
        deepLink.append(.init(name: SettingsCoordinator.Destination.snooze.rawValue))
        self.coordinator?.follow(deepLink)
    }
    
    private func setupSnoozeButton(switchedOn: Bool? = nil) {
        self.snoozeButton.isSelected = switchedOn ?? self.notificationsSnoozer.isSnoozeActive(at: Date())
        self.snoozeButton.accessibilityLabel = self.snoozeButton.isSelected ? LocalString._notifications_are_snoozed : LocalString._notifications_snooze_off
    }
    
    @IBAction func presentQuickSnoozeOptions(sender: UIButton?) {
        let dialog = self.notificationsSnoozer.quickOptionsDialog(for: Date(), toPresentOn: self) { switchedOn in
            self.setupSnoozeButton(switchedOn: switchedOn)
        }
        self.present(dialog, animated: true, completion: nil)
    }
}

extension MenuViewController: UITableViewDelegate {
    func closeMenu() {
        self.revealViewController().revealToggle(animated: true)
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return self.viewModel.sectionCount()
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return kMenuCellHeight
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if self.sectionClicked {
            return
        }
        self.sectionClicked = true
        let s = indexPath.section
        let row = indexPath.row
        let section = self.viewModel.section(at: s)
        switch section {
        case .inboxes:
            let obj = self.viewModel.item(inboxes: row).menuToLabel
            self.coordinator?.go(to: .mailbox, sender: obj)
        case .others:
            let item = self.viewModel.item(others: row)
            if item == .signout {
                tableView.deselectRow(at: indexPath, animated: true)
                let cell = tableView.cellForRow(at: indexPath)
                self.handleSignOut(cell)
            } else if item == .settings {
                self.coordinator?.go(to: .settings)
            } else if item == .bugs {
                self.coordinator?.go(to: .bugs)
            } else if item == .contacts {
                self.coordinator?.go(to: .contacts)
            } else if item == .feedback {
                //self.performSegue(withIdentifier: kSegueToFeedback, sender: indexPath)
            } else if item == .lockapp {
                keymaker.lockTheApp() // remove mainKey from memory
                let _ = UnlockManager.shared.isUnlocked() // provoke mainKey obtaining
                self.sectionClicked = false
                self.closeMenu()
            } else if item == .servicePlan {
                self.coordinator?.go(to: .plan)
            }
        case .labels:
            let obj = self.viewModel.label(at: row)
            self.coordinator?.go(to: .label, sender: obj)
        default:
            break
        }
    }
}

extension MenuViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let section = self.viewModel.section(at: section)
        switch section {
        case .inboxes:
            return self.viewModel.inboxesCount()
        case .others:
            return self.viewModel.othersCount()
        case .labels:
            return self.viewModel.labelsCount()
        default:
            return 0
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let s = indexPath.section
        let row = indexPath.row
        let section = self.viewModel.section(at: s)
        switch section {
        case .inboxes:
            let cell = tableView.dequeueReusableCell(withIdentifier: kMenuTableCellId, for: indexPath) as! MenuTableViewCell
            cell.configCell(self.viewModel.item(inboxes: row))
            cell.configUnreadCount()
            return cell
        case .others:
            let cell = tableView.dequeueReusableCell(withIdentifier: kMenuTableCellId, for: indexPath) as! MenuTableViewCell
            cell.configCell(self.viewModel.item(others: row))
            cell.hideCount()
            return cell
        case .labels:
            let cell = tableView.dequeueReusableCell(withIdentifier: kLabelTableCellId, for: indexPath) as! MenuLabelViewCell
            if let data = self.viewModel.label(at: row) {
                cell.configCell(data)
                cell.configUnreadCount()
            }
            return cell
        default:
            let cell: MenuTableViewCell = tableView.dequeueReusableCell(withIdentifier: kMenuTableCellId, for: indexPath) as! MenuTableViewCell
            return cell
        }
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        let s = self.viewModel.section(at: section)
        switch s {
        case .labels:
            return 0.0
        default:
            return 1.0
        }
    }
}

extension MenuViewController: NSFetchedResultsControllerDelegate {
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        if !signingOut {
            tableView.endUpdates()
        }
    }
    
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        if !signingOut {
            tableView.beginUpdates()
        }
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange sectionInfo: NSFetchedResultsSectionInfo, atSectionIndex sectionIndex: Int, for type: NSFetchedResultsChangeType) {
        if !signingOut {
            switch(type) {
            case .delete:
                tableView.deleteSections(IndexSet(integer: sectionIndex), with: .fade)
            case .insert:
                tableView.insertSections(IndexSet(integer: sectionIndex), with: .fade)
            default:
                return
            }
        }
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        if !signingOut {
            switch(type) {
            case .delete:
                if let indexPath = indexPath {
                    tableView.deleteRows(at: [IndexPath(row: indexPath.row, section: 2)], with: UITableView.RowAnimation.fade)
                }
            case .insert:
                if let newIndexPath = newIndexPath {
                    tableView.insertRows(at: [IndexPath(row: newIndexPath.row, section: 2)], with: UITableView.RowAnimation.fade)
                }
            case .move:
                if let indexPath = indexPath {
                    if let newIndexPath = newIndexPath {
                        tableView.moveRow(at: IndexPath(row: indexPath.row, section: 2), to: IndexPath(row: newIndexPath.row, section: 2))
                    }
                }
            case .update:
                if let indexPath = indexPath {
                    let index = IndexPath(row: indexPath.row, section: 2)
                    if let cell = tableView.cellForRow(at: index) as? MenuLabelViewCell {
                        if let data = self.viewModel.label(at: index.row) {
                            cell.configCell(data)
                            cell.configUnreadCount()
                        }
                    }
                }
            }
        }
    }
}

extension MenuViewController: Deeplinkable {
    var deeplinkNode: DeepLink.Node {
        return DeepLink.Node(name: String(describing: MenuViewController.self))
    }
}
