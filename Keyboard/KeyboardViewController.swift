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
            collectionView.backgroundColor = UIColor.theme.border
            collectionView.layer.borderColor = UIColor.theme.border.cgColor
            collectionView.layer.borderWidth = 1
            collectionView.register(Cell.self, forCellWithReuseIdentifier: String(describing: Cell.self))
        }
    }
    
    let items: [[Item]] = [
        [Item(title: "1"), Item(title: "2"), Item(title: "3"), Item(title: ",", font: .text, backgroundColor: UIColor.theme.background3)],
        [Item(title: "4"), Item(title: "5"), Item(title: "6"), Item(title: "Space", font: .text, backgroundColor: UIColor.theme.background3)],
        [Item(title: "7"), Item(title: "8"), Item(title: "9"), Item(title: ".", font: .text, backgroundColor: UIColor.theme.background3)],
        [Item(imageName: "next"), Item(title: "0"), Item(imageName: "back"), Item(title: "Enter", font: .text, backgroundColor: UIColor.theme.background3)]
    ]
    
    fileprivate var timer: Timer?
    
    override func updateViewConstraints() {
        super.updateViewConstraints()
        
        // Add custom view sizing constraints here
        collectionView.collectionViewLayout.invalidateLayout()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        Fabric.with([Crashlytics.self])
    }
    
    override func textWillChange(_ textInput: UITextInput?) {
        // The app is about to change the document's contents. Perform any preparation here.
    }
    
    override func textDidChange(_ textInput: UITextInput?) {
        // The app has just changed the document's contents, the document context has been updated.
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
        cell.button.title = item.title
        cell.button.titleLabel?.font = item.font
        cell.button.titleColor = UIColor.theme.foreground
        cell.button.tintColor = UIColor.theme.foreground
        cell.button.image = item.imageName.flatMap { UIImage(named: $0) }
        cell.button.setBackgroundImage(UIImage(color: item.backgroundColor), for: .normal)
        cell.button.setBackgroundImage(UIImage(color: item.backgroundColor.darkened(amount: 0.1)), for: .highlighted)
        cell.button.setBackgroundImage(UIImage(color: item.backgroundColor.darkened(amount: 0.1)), for: .selected)
        cell.buttonTapped = { [unowned self] button in
            switch (indexPath.section, indexPath.row) {
            case (1, 3): self.textDocumentProxy.insertText(" ")
            case (3, 0): self.advanceToNextInputMode()
            case (3, 2): self.textDocumentProxy.deleteBackward()
            case (3, 3): self.textDocumentProxy.insertText("\n")
            default: _ = item.title.map { self.textDocumentProxy.insertText($0) }
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
        size.width /= numberOfColumns
        size.height /= numberOfRows
        return size
    }
    
}
