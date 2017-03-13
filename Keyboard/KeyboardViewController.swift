//
//  KeyboardViewController.swift
//  Keyboard
//
//  Created by Lasha Efremidze on 2/19/17.
//  Copyright © 2017 MoreVoltage. All rights reserved.
//

import UIKit
import Fabric
import Crashlytics
import SwiftyTimer

class KeyboardViewController: InputViewController {
    
    @IBOutlet weak var stackView: StackView! {
        didSet {
            stackView.backgroundColor = UIColor.cache.theme.border
            stackView.layer.borderColor = UIColor.cache.theme.border.cgColor
            stackView.layer.borderWidth = 1
            stackView.configure(Item.all(), block: { [unowned self] position, item, cell in
                switch position {
                case (3, 0):
                    if #available(iOSApplicationExtension 10.0, *) {
                        cell.button.addTarget(self, action: #selector(self.handleInputModeList), for: .allTouchEvents)
                    }
                case (3, 2):
                    cell.button.addGestureRecognizer(UILongPressGestureRecognizer(target: self, action: #selector(self.longPressed)))
                default: break
                }
            }, touchDown: { position, item in
                if UIDevice.cache.hasOpenAccess {
                    UIDevice.current.playInputClick()
                }
            }, tapped: { [unowned self] position, item in
                switch position {
                case (1, 3): self.textDocumentProxy.insertText(" ")
                case (3, 0): self.advanceToNextInputMode()
                case (3, 2): self.textDocumentProxy.deleteBackward()
                case (3, 3): self.textDocumentProxy.insertText("\n")
                default: _ = item.title.map { self.textDocumentProxy.insertText($0) }
                }
                if UIDevice.cache.hasOpenAccess {
                    _ = (item.title ?? item.imageName).map {
                        Answers.logCustomEvent(withName: "clicked", customAttributes: ["value" : $0])
                    }
                }
            })
        }
    }
    
    fileprivate var timer: Timer?
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        UIDevice.cache.refresh()
        UIColor.cache.refresh()
        
        struct Once {
            static let run: Void = {
                #if DEBUG
                    Crashlytics.sharedInstance().debugMode = true
                #endif
                Fabric.with([Crashlytics.self])
                #if DEBUG
                    Fabric.sharedSDK().debug = true
                #endif
            }()
        }
        
        if UIDevice.cache.hasOpenAccess {
            Once.run
        }
    }
    
    @IBAction func longPressed(recognizer: UILongPressGestureRecognizer) {
        switch recognizer.state {
        case .began:
            timer = Timer.every(0.1) { [unowned self] in
                self.textDocumentProxy.deleteBackward()
            }
        case .ended:
            timer?.invalidate()
        default: break
        }
    }
    
}
