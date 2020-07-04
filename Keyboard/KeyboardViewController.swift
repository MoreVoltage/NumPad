//
//  KeyboardViewController.swift
//  Keyboard
//
//  Created by Lasha Efremidze on 2/19/17.
//  Copyright © 2017 MoreVoltage. All rights reserved.
//

import UIKit

typealias Position = (Int, Int)

//private enum Screen {
//    static var bounds: CGRect { return UIScreen.main.bounds }
//    static var isPortrait: Bool { return bounds.width < bounds.height }
//    static var keyboardHeight: CGFloat {
//        return isPortrait ? 258 : 206
//    }
//    static func keyboardHeight(_ count: Int) -> CGFloat {
//        return (keyboardHeight / 5) * CGFloat(count)
//    }
//    static func keyboardSize(_ count: Int) -> CGSize {
//        return CGSize(width: isPortrait ? bounds.width : bounds.height, height: keyboardHeight(count))
//    }
//}

class KeyboardViewController: InputViewController {
    
    lazy var stackView: StackView = { [unowned self] in
        let stackView = StackView()
//        stackView.frame.size = Screen.keyboardSize(items.count)
        stackView.backgroundColor = KeyboardTheme.scheme.border
//        stackView.layer.borderColor = KeyboardTheme.scheme.border.cgColor
        stackView.addGestureRecognizer({
            let gesture = UIPanGestureRecognizer(target: self, action: #selector(panned(recognizer:)))
            gesture.maximumNumberOfTouches = 1
            return gesture
        }())
        self.inputView?.addSubview(stackView)
        stackView.edgesToSuperview()
        return stackView
    }()
    
    private lazy var items: [[Item]] = Item.all(type: KeyboardType.selected)
    
    override func viewDidLoad() {
        super.viewDidLoad()
                
        reloadItems()
        runAnalytics()
    }
    
//    override func viewWillAppear(_ animated: Bool) {
//        super.viewWillAppear(animated)
//
//        updateHeight()
//    }
    
//    override func updateViewConstraints() {
//        super.updateViewConstraints()
//
//        guard heightConstraint != nil, let view = inputView, view.frame.width != 0, view.frame.height != 0 else { return }
//
//        updateHeight()
//    }
    
//    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
//        super.viewWillTransition(to: size, with: coordinator)
//
//        coordinator.animate(alongsideTransition: { context in
//            self.updateHeight()
//        }, completion: { context in })
//    }
    
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
            for cell in stackView.cells {
                let containsPoint = cell.frame.contains(point)
                switch recognizer.state {
                case .changed:
                    cell._isHighlighted = containsPoint
                case .ended where containsPoint:
                    cell.sendActions(for: .touchUpInside)
                    fallthrough
                default:
                    cell._isHighlighted = false
                }
            }
        default: break
        }
    }
    
//    func updateHeight() {
//        height = Screen.keyboardHeight(items.count)
//    }
    
    func reloadItems() {
        items = Item.all(type: .selected)
        stackView.configure(items, keyboardType: .selected, roundedCorners: Keyboard.hasRoundedCorners, grid: Keyboard.hasGrid, block: { (position, item, cell) in
            switch (item.title, item.imageName) {
            case (_, "next"?):
//                if #available(iOSApplicationExtension 11.0, *) {
//                    cell.isHidden = !needsInputModeSwitchKey
//                }
                cell.addTarget(self, action: #selector(handleInputModeList), for: .allTouchEvents)
            case (_, "back"?):
                cell.addTarget(self, action: #selector(longPressed), forContinuousPressWithTimeInterval: 0.1)
            default: break
            }
        }, touchDown: { [weak self] (position, item) in self?.touchDown(position) }, tapped: { [weak self] (position, item) in self?.tapped(position) })
    }
    
}

// MARK: - Helpers
private extension KeyboardViewController {
    
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
//    var height: CGFloat = 0 {
//        didSet {
//            guard height != oldValue else { return }
//            if heightConstraint == nil {
//                heightConstraint = inputView?.height(height, priority: .required - 1)
//                inputView?.translatesAutoresizingMaskIntoConstraints = true
//            } else {
//                heightConstraint.constant = height
//            }
//        }
//    }
//    var heightConstraint: NSLayoutConstraint!
}
