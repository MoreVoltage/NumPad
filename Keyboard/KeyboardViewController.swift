//
//  KeyboardViewController.swift
//  Keyboard
//
//  Created by Lasha Efremidze on 2/19/17.
//  Copyright © 2017 MoreVoltage. All rights reserved.
//

import UIKit

typealias Position = (Int, Int)

private enum Screen {
    static var bounds: CGRect { return UIScreen.main.bounds }
    static var isPortrait: Bool { return bounds.width < bounds.height }
    static var keyboardHeight: CGFloat {
        return isPortrait ? 258 : 206
    }
    static func keyboardHeight(_ count: Int) -> CGFloat {
        return (keyboardHeight / 5) * CGFloat(count)
    }
    static func keyboardSize(_ count: Int) -> CGSize {
        return CGSize(width: isPortrait ? bounds.width : bounds.height, height: keyboardHeight(count))
    }
}

class KeyboardViewController: InputViewController {
    
    private lazy var collectionView: UICollectionView = { [unowned self] in
        let layout = UICollectionViewFlowLayout()
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.frame.size = Screen.keyboardSize(items.count)
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.allowsSelection = false
        collectionView.isScrollEnabled = false
        collectionView.backgroundColor = KeyboardTheme.scheme.border
        collectionView.layer.borderColor = KeyboardTheme.scheme.border.cgColor
        collectionView.layer.borderWidth = 1
        collectionView.register(Cell.self, forCellWithReuseIdentifier: String(describing: Cell.self))
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(panned(recognizer:)))
        panGesture.maximumNumberOfTouches = 1
        collectionView.addGestureRecognizer(panGesture)
        self.inputView?.addSubview(collectionView)
        collectionView.edgesToSuperview()
        return collectionView
    }()
    
    private lazy var items: [[Item]] = Item.all(type: KeyboardType.selected)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        _ = collectionView
        
        runAnalytics()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        updateHeight()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        collectionView.collectionViewLayout.invalidateLayout()
    }
    
    override func updateViewConstraints() {
        super.updateViewConstraints()
        
        guard heightConstraint != nil, let view = inputView, view.frame.width != 0, view.frame.height != 0 else { return }
        
        updateHeight()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        coordinator.animate(alongsideTransition: { context in
            self.updateHeight()
        }, completion: { context in })
    }
    
    deinit {
        print("\(self) deinit")
    }
    
    @IBAction func longPressed(sender: UIButton) {
        guard self.textDocumentProxy.hasText else { return }
        playClick()
        self.textDocumentProxy.deleteBackward()
    }
    
    @IBAction func panned(recognizer: UIPanGestureRecognizer) {
        let point = recognizer.location(in: self.view)
        switch recognizer.state {
        case .changed, .ended:
            for cell in collectionView.visibleCells as! [Cell] {
                let containsPoint = cell.frame.contains(point)
                switch recognizer.state {
                case .changed:
                    cell.button._isHighlighted = containsPoint
                case .ended where containsPoint:
                    cell.button.sendActions(for: .touchUpInside)
                    fallthrough
                default:
                    cell.button._isHighlighted = false
                }
            }
        default: break
        }
    }
    
    func updateHeight() {
        height = Screen.keyboardHeight(items.count)
    }
    
    func reloadItems() {
        items = Item.all(type: .selected)
        collectionView.reloadData()
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
        cell.configure(item, roundedCorners: Keyboard.hasRoundedCorners, touchDown: { [weak self] in self?.touchDown(position) }, tapped: { [weak self] in self?.tapped(position) })
        switch (item.title, item.imageName) {
        case (_, "next"?):
//            if #available(iOSApplicationExtension 11.0, *) {
//                cell.button.isHidden = !needsInputModeSwitchKey
//            }
                cell.button.addTarget(self, action: #selector(handleInputModeList), for: .allTouchEvents)
        case (_, "back"?):
            cell.button.addTarget(self, action: #selector(longPressed), forContinuousPressWithTimeInterval: 0.1)
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
        size.width -= 1 // FIXME
        size.height -= 1 // FIXME
        switch KeyboardType.selected {
        case .math, .math2, .finance:
            if indexPath.section == 0 {
                size.width /= numberOfColumns
            } else {
                fallthrough
            }
        default:
            let smallWidth = size.width / (numberOfColumns * 1.4)
            if indexPath.item == Int(numberOfColumns) - 1 {
                size.width = smallWidth
            } else {
                size.width = (size.width - smallWidth) / (numberOfColumns - 1)
            }
        }
        size.height /= numberOfRows
//        size.width = floor(size.width) // FIXME
//        size.height = floor(size.height) // FIXME
        size.width = max(0, size.width) // FIXME
        size.height = max(0, size.height) // FIXME
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
        playClick()
    }
    
    func tapped(_ position: Position) {
        let item = items[position.0][position.1]
        switch (item.title, item.imageName) {
        case ("Space"?, _): self.textDocumentProxy.insertText(" ")
        case ("Enter"?, _): self.textDocumentProxy.insertText("\n")
        case (_, "next"?): self.advanceToNextInputMode()
        case (_, "back"?): self.textDocumentProxy.deleteBackward()
        case (_, "math"?), (_, "math2"?): KeyboardType.selected.toggleMath(); reloadItems()
        default: item.title.map(self.textDocumentProxy.insertText)
        }
        if _hasFullAccess {
            (item.title ?? item.imageName).map {
                Analytics.logEvent(name: "clicked", attributes: [Analytics.ParameterValue: $0])
            }
        }
    }
    
    func playClick() {
        guard _hasFullAccess else { return }
        UIDevice.current.playInputClick()
    }
    
    func runAnalytics() {
        guard _hasFullAccess else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            Analytics.start
        }
    }
    
}

class InputViewController: UIInputViewController {
    // https://stackoverflow.com/questions/24167909/ios-8-custom-keyboard-changing-the-height
    var height: CGFloat = 0 {
        didSet {
            guard height != oldValue else { return }
            if heightConstraint == nil {
                heightConstraint = inputView?.height(height, priority: .required - 1)
                inputView?.translatesAutoresizingMaskIntoConstraints = true
            } else {
                heightConstraint.constant = height
            }
        }
    }
    var heightConstraint: NSLayoutConstraint!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        UserDefaults.synchronize()
    }
}
