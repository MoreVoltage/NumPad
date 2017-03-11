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

class KeyboardViewController: UIInputViewController {
    
    @IBOutlet weak var collectionView: UICollectionView! {
        didSet {
            collectionView.allowsSelection = false
            collectionView.isScrollEnabled = false
            collectionView.backgroundColor = UIColor.cache.theme.border
            collectionView.layer.borderColor = UIColor.cache.theme.border.cgColor
            collectionView.layer.borderWidth = 1
            collectionView.register(Cell.self, forCellWithReuseIdentifier: String(describing: Cell.self))
        }
    }
    
    lazy var items: [[Item]] = [
        [Item(title: "1"), Item(title: "2"), Item(title: "3"), Item(title: ",", font: .text, backgroundColor: UIColor.cache.theme.background3)],
        [Item(title: "4"), Item(title: "5"), Item(title: "6"), Item(title: "Space", font: .text, backgroundColor: UIColor.cache.theme.background3)],
        [Item(title: "7"), Item(title: "8"), Item(title: "9"), Item(title: ".", font: .text, backgroundColor: UIColor.cache.theme.background3)],
        [Item(imageName: "next"), Item(title: "0"), Item(imageName: "back"), Item(title: "Enter", font: .text, backgroundColor: UIColor.cache.theme.background3)]
    ]
    
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
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        collectionView.collectionViewLayout.invalidateLayout()
    }
    
//    override func updateViewConstraints() {
//        super.updateViewConstraints()
//        
//        // Add custom view sizing constraints here
//    }
    
    deinit {
        print("\(self) deinit")
    }
    
}

extension KeyboardViewController {
    
    @IBAction func longPressed(recognizer: UILongPressGestureRecognizer) {
        switch recognizer.state {
        case .began:
            timer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(self.backspace), userInfo: nil, repeats: true)
        case .ended:
            timer?.invalidate()
            timer = nil
        default: break
        }
    }
    
    @IBAction func backspace(sender: Any) {
        self.textDocumentProxy.deleteBackward()
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
        let item = items[indexPath.section][indexPath.item]
        cell.configure(item)
        cell.buttonTapped = { [unowned self] button in
            switch (indexPath.section, indexPath.row) {
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
        }
        cell.buttonTouchDown = { button in
            if UIDevice.cache.hasOpenAccess {
                UIDevice.current.playInputClick()
            }
        }
        switch (indexPath.section, indexPath.row) {
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
    
    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
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
