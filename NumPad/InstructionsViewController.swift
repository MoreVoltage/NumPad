//
//  InstructionsViewController.swift
//  NumPad
//
//  Created by Lasha Efremidze on 2/19/17.
//  Copyright © 2017 MoreVoltage. All rights reserved.
//

import UIKit

class InstructionsViewController: UITableViewController {
    
    fileprivate let items = [Item(title: "Open the Settings App", imageName: "tap"), Item(title: "Tap General", imageName: "tap"), Item(title: "Tap Keyboard", imageName: "tap"), Item(title: "Tap Keyboards", imageName: "tap"), Item(title: "Tap Add New Keyboard...", imageName: "tap"), Item(title: "Tap \(Bundle.main.bundleName!)", imageName: "tap"), Item(title: "Tap \(Bundle.main.bundleName!) again", imageName: "tap"), Item(title: "Turn on Allow Full Access", imageName: "switch")]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.interactiveNavigationBarHidden = false
        
        self.navigationItem.title = "Instructions"
        
        self.tableView.backgroundColor = .white
        self.tableView.tableHeaderView = UIView()
        self.tableView.tableFooterView = {
            let view = UIView()
            view.frame.size.height = 84
            let button = UIButton(type: .system)
            button.layer.cornerRadius = 4
            button.layer.masksToBounds = true
            button.backgroundImage = UIImage(color: .myBlue)
            button.titleColor = .white
            button.title = "Go to settings"
            button.addTarget(self, action: #selector(buttonTapped), for: .touchUpInside)
            view.addSubview(button)
            button.constrain {[
                $0.topAnchor.constraint(equalTo: $0.superview!.topAnchor, constant: 20),
                $0.leadingAnchor.constraint(equalTo: $0.superview!.leadingAnchor, constant: 10),
                $0.bottomAnchor.constraint(equalTo: $0.superview!.bottomAnchor, constant: -20),
                $0.trailingAnchor.constraint(equalTo: $0.superview!.trailingAnchor, constant: -10)
            ]}
            return view
        }()
    }
    
    @IBAction func buttonTapped(sender: UIButton) {
        if #available(iOS 10.0, *) {
            _ = URL(string: "App-Prefs:root=General&path=Keyboard/KEYBOARDS").map { UIApplication.shared.open($0) }
        } else {
            _ = URL(string: "prefs:root=General&path=Keyboard/KEYBOARDS").map { UIApplication.shared.openURL($0) }
        }
    }
    
}

// MARK: - UITableViewDataSource
extension InstructionsViewController {
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let reuseIdentifier = String(describing: Cell.self)
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier) ?? Cell(style: .default, reuseIdentifier: reuseIdentifier)
        cell.selectionStyle = .none
        cell.imageView?.image = UIImage(named: items[indexPath.row].imageName)
        cell.imageView?.tintColor = .myBlue
        cell.imageView?.contentMode = .center
        cell.textLabel?.text = items[indexPath.row].title
        return cell
    }
    
}

// MARK: - UITableViewDelegate
extension InstructionsViewController {
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        cell.separatorInset.left = 54
        cell.preservesSuperviewLayoutMargins = false
        cell.layoutMargins = UIEdgeInsets()
    }
    
}

private class Cell: UITableViewCell {
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        imageView?.center.x = 26
        imageView?.center.y = contentView.center.y
        
        textLabel?.frame.origin.x = 54
    }
    
}

private struct Item {
    let title: String
    let imageName: String
}
