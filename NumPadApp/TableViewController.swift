//
//  TableViewController.swift
//  NumPadApp
//
//  Created by Lasha Efremidze on 2/15/16.
//  Copyright © 2016 Lasha Efremidze. All rights reserved.
//

import UIKit

class TableViewController: UITableViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        style()
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        
        style()
    }
    
}

// MARK: - Style
extension TableViewController {
    
    func style() {
        self.title = "NumPad"
        
        self.tableView.backgroundColor = UIColor(white: 0.9, alpha: 1)
        self.tableView.estimatedRowHeight = 44
        self.tableView.rowHeight = UITableViewAutomaticDimension
        self.tableView.alwaysBounceVertical = false
        self.tableView.showsVerticalScrollIndicator = false
        self.tableView.allowsSelection = false
        self.tableView.separatorColor = .clearColor()
        self.tableView.tableHeaderView = {
            let view = UIView()
            view.frame.size = CGSize(width: tableView.bounds.width, height: 80)
            
            let button = UIButton(type: .System)
            button.layer.cornerRadius = 6
            button.layer.masksToBounds = true
            button.setTitle("Click here to go to keyboard settings", forState: .Normal)
            button.setTitleColor(.whiteColor(), forState: .Normal)
            button.setBackgroundImage(UIImage(color: .orangeColor()), forState: .Normal)
            button.addTarget(self, action: Selector("keyboardSettingsButtonTapped:"), forControlEvents: .TouchUpInside)
            button.sizeToFit()
            button.frame.size.width += 15
            button.frame.size.height += 15
            button.center = view.center
            view.addSubview(button)
            
            return view
        }()
        self.tableView.tableFooterView = {
            let view = UIView()
            view.frame.size = CGSize(width: tableView.bounds.width, height: tableView.bounds.maxY - tableView.rectForSection(0).maxY)
            
            let button = UIButton(type: .System)
            button.layer.cornerRadius = 6
            button.layer.masksToBounds = true
            button.setTitle("Send Feedback", forState: .Normal)
            button.setTitleColor(.whiteColor(), forState: .Normal)
            button.setBackgroundImage(UIImage(color: .orangeColor()), forState: .Normal)
            button.addTarget(self, action: Selector("feedbackButtonTapped:"), forControlEvents: .TouchUpInside)
            button.sizeToFit()
            button.frame.size.width += 15
            button.frame.size.height += 15
            button.center.x = view.center.x
            button.center.y = view.bounds.maxY - 60
            view.addSubview(button)
            
            return view
        }()
    }
    
}

// MARK: - Actions
extension TableViewController {
    
    @IBAction func keyboardSettingsButtonTapped(_: AnyObject) {
        if let settingsURL = NSURL(string: "prefs:root=General&path=Keyboard/KEYBOARDS") {
            UIApplication.sharedApplication().openURL(settingsURL)
        }
    }
    
    @IBAction func feedbackButtonTapped(_: AnyObject) {
        print("feedbackButtonTapped:")
    }
    
}

// MARK: - UITableViewDataSource
extension TableViewController {
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 3
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        switch indexPath.row {
        case 0:
            let cell = Cell(style: .Subtitle, reuseIdentifier: nil)
            cell.imageView?.image = UIImage(named: "multitasking")
            cell.textLabel?.text = "HINT"
            cell.detailTextLabel?.text = "use multitasking to see this list!"
            return cell
        case 1:
            let cell = Cell(style: .Default, reuseIdentifier: nil)
            cell.imageView?.image = UIImage(named: "plus")
            cell.textLabel?.text = "Tap \"Add New Keyboard\""
            return cell
        case 2:
            let cell = Cell(style: .Default, reuseIdentifier: nil)
            cell.imageView?.image = UIImage(named: "digits")
            cell.textLabel?.text = "Under \"Third Party Keyboards\",\nselect \(NSBundle.mainBundle().displayName!)"
            return cell
        default: return UITableViewCell()
        }
    }
    
}

// MARK: - Cell
class Cell: UITableViewCell {
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        initialize()
    }
    
    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        initialize()
    }
    
    func initialize() {
        self.backgroundColor = .clearColor()
        
        self.imageView?.contentMode = .ScaleAspectFit
        
        self.textLabel?.numberOfLines = 0
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        self.imageView?.frame.origin.x = 25
        self.imageView?.frame.size.width = 44
        self.textLabel?.frame.origin.x = 90
        self.detailTextLabel?.frame.origin.x = 90
    }
    
}

// MARK: - NSBundle
extension NSBundle {
    
    var displayName: String? {
        return infoDictionary?["CFBundleDisplayName"] as? String
    }
    
}

// MARK: - UIImage
extension UIImage {
    
    convenience init(color: UIColor, size: CGSize = CGSize(width: 1, height: 1)) {
        var rect = CGRectZero
        rect.size = size
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        color.setFill()
        UIRectFill(rect)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        self.init(CGImage: image.CGImage!)
    }
    
}