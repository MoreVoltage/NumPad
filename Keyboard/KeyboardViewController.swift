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
    
    @IBOutlet fileprivate weak var collectionView: UICollectionView! {
        didSet {
            collectionView.allowsSelection = false
            collectionView.isScrollEnabled = false
            collectionView.backgroundColor = Keyboard.Theme.scheme.border
            collectionView.layer.borderColor = Keyboard.Theme.scheme.border.cgColor
            collectionView.layer.borderWidth = 1
            collectionView.register(Cell.self, forCellWithReuseIdentifier: String(describing: Cell.self))
        }
    }
    
    fileprivate lazy var items: [[Item]] = Item.all()
    
    fileprivate var timer: Timer?
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
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
        
        if UIDevice.current.hasOpenAccess {
            Once.run
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        collectionView.collectionViewLayout.invalidateLayout()
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

// MARK: - UICollectionViewDataSource
extension KeyboardViewController: UICollectionViewDataSource {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return items.count
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return items[section].count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: String(describing: Cell.self), for: indexPath) as! Cell
        let position = (indexPath.section, indexPath.item)
        let item = items[position.0][position.1]
        cell.configure(item, touchDown: {
            if UIDevice.current.hasOpenAccess {
                UIDevice.current.playInputClick()
            }
        }, tapped: { [unowned self] in
            switch position {
            case (1, 3): self.textDocumentProxy.insertText(" ")
            case (3, 0): self.advanceToNextInputMode()
            case (3, 2): self.textDocumentProxy.deleteBackward()
            case (3, 3): self.textDocumentProxy.insertText("\n")
            default: _ = item.title.map { self.textDocumentProxy.insertText($0) }
            }
            if UIDevice.current.hasOpenAccess {
                _ = (item.title ?? item.imageName).map {
                    Answers.logCustomEvent(withName: "clicked", customAttributes: ["value" : $0])
                }
            }
        })
        switch position {
        case (3, 0):
            if #available(iOSApplicationExtension 10.0, *) {
                cell.button.addTarget(self, action: #selector(handleInputModeList), for: .allTouchEvents)
            }
        case (3, 2):
            cell.button.addGestureRecognizer(UILongPressGestureRecognizer(target: self, action: #selector(longPressed)))
        default: break
        }
        return cell
    }
    
}

// MARK: - UICollectionViewDelegateFlowLayout
extension KeyboardViewController: UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let numberOfRows = CGFloat(items.count)
        let numberOfColumns = CGFloat(items[indexPath.section].count)
        var size = collectionView.bounds.size
        let smallWidth = size.width / (numberOfColumns * 1.6)
        if indexPath.row == 3 {
            size.width = smallWidth
        } else {
            size.width = (size.width - smallWidth) / (numberOfColumns - 1)
        }
        size.height /= numberOfRows
        return size
    }
    
}
