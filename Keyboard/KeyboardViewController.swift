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

private let keyboardHeight: CGFloat = 250

class KeyboardViewController: InputViewController {
    
    fileprivate lazy var collectionView: UICollectionView = { [unowned self] in
        let layout = UICollectionViewFlowLayout()
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.allowsSelection = false
        collectionView.isScrollEnabled = false
        collectionView.backgroundColor = KeyboardTheme.scheme.border
        collectionView.layer.borderColor = KeyboardTheme.scheme.border.cgColor
        collectionView.layer.borderWidth = 1
        collectionView.register(Cell.self, forCellWithReuseIdentifier: String(describing: Cell.self))
        self.inputView!.addSubview(collectionView)
        collectionView.constrainToEdges()
        return collectionView
    }()
    
    fileprivate lazy var items: [[Item]] = Item.all(type: KeyboardType.selected)
    
    fileprivate var timer: Timer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        runAnalytics()
        
        _ = collectionView
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        collectionView.collectionViewLayout.invalidateLayout()
    }
    
    @IBAction func longPressed(recognizer: UILongPressGestureRecognizer) {
        switch recognizer.state {
        case .began:
            timer = Timer.every(0.1) { [weak self] in
                self?.textDocumentProxy.deleteBackward()
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
        cell.configure(item, touchDown: { [weak self] in self?.touchDown(position) }, tapped: { [weak self] in self?.tapped(position) })
        switch (item.title, item.imageName) {
        case (_, "next"?):
            if #available(iOSApplicationExtension 11.0, *) {
                cell.button.isHidden = !needsInputModeSwitchKey
            }
            if #available(iOSApplicationExtension 10.0, *) {
                cell.button.addTarget(self, action: #selector(handleInputModeList), for: .allTouchEvents)
            }
        case (_, "back"?):
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
        switch KeyboardType.selected {
        case .math, .finance:
            if indexPath.section == 0 {
                size.width /= numberOfColumns
            } else {
                fallthrough
            }
        default:
            let smallWidth = size.width / (numberOfColumns * 1.6)
            if indexPath.item == Int(numberOfColumns) - 1 {
                size.width = smallWidth
            } else {
                size.width = (size.width - smallWidth) / (numberOfColumns - 1)
            }
        }
        size.height /= numberOfRows
        return size
    }
    
}

// MARK: - Helpers
private extension KeyboardViewController {
    
    var _hasFullAccess: Bool {
        if #available(iOSApplicationExtension 11.0, *) {
            return hasFullAccess
        } else {
            return UIDevice.current.hasOpenAccess
        }
    }
    
    func touchDown(_ position: Position) {
        if _hasFullAccess {
            UIDevice.current.playInputClick()
        }
    }
    
    func tapped(_ position: Position) {
        let item = items[position.0][position.1]
        switch (item.title, item.imageName) {
        case ("Space"?, _): self.textDocumentProxy.insertText(" ")
        case (_, "next"?): self.advanceToNextInputMode()
        case (_, "back"?): self.textDocumentProxy.deleteBackward()
        case ("Enter"?, _): self.textDocumentProxy.insertText("\n")
        default: _ = item.title.map { self.textDocumentProxy.insertText($0) }
        }
        if _hasFullAccess {
            _ = (item.title ?? item.imageName).map {
                Answers.logCustomEvent(withName: "clicked", customAttributes: ["value" : $0])
            }
        }
    }
    
    func runAnalytics() {
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
        if _hasFullAccess {
            Once.run
        }
    }
    
}
