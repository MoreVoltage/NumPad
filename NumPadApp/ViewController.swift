//
//  ViewController.swift
//  NumPadApp
//
//  Created by Lasha Efremidze on 1/17/16.
//  Copyright © 2016 Lasha Efremidze. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    
    @IBOutlet weak var tableView: UITableView! {
        didSet {
            tableView.dataSource = self
            
            tableView.tableHeaderView = UIView()
            tableView.tableFooterView = UIView()
            
            tableView.estimatedRowHeight = 44
            tableView.rowHeight = UITableViewAutomaticDimension
            
            tableView.keyboardDismissMode = .Interactive
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }
    
}

// MARK: - UITableViewDataSource
extension ViewController: UITableViewDataSource {
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 2
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        switch indexPath.row {
        case 0:
            let cell = UITableViewCell(style: .Default, reuseIdentifier: nil)
            cell.textLabel?.text = "Go to Settings → General → Keyboard → Keyboards → Add New Keyboard"
            cell.textLabel?.numberOfLines = 0
            return cell
        case 1:
            let cell = TextFieldCell(style: .Default, reuseIdentifier: nil)
            cell.textField.placeholder = "Test me"
            return cell
        default: break
        }
        
        return UITableViewCell()
    }
    
}

// MARK: - TextFieldCell
private class TextFieldCell: UITableViewCell {
    
    let textField = UITextField()
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }
    
    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }
    
    func setup() {
        textField.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(textField)
        
        let views = ["textField": textField]
        addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("H:|-20-[textField]|", options: [], metrics: nil, views: views))
        addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("V:|[textField]|", options: [], metrics: nil, views: views))
    }
    
}
