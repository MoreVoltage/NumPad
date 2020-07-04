//
//  KeyboardViewController.swift
//  Keyboard
//
//  Created by Lasha Efremidze on 2/19/17.
//  Copyright © 2017 MoreVoltage. All rights reserved.
//

import UIKit

class KeyboardViewController: UIInputViewController {
    
    lazy var stackView: StackView = { [unowned self] in
        let stackView = StackView()
        stackView.backgroundColor = KeyboardTheme.scheme.border
        stackView.addGestureRecognizer({
            let gesture = UIPanGestureRecognizer(target: self, action: #selector(panned))
            gesture.maximumNumberOfTouches = 1
            return gesture
        }())
        self.inputView?.addSubview(stackView)
        stackView.edgesToSuperview()
        return stackView
    }()
    
    lazy var items: [[Item]] = Item.all(type: KeyboardType.selected)
    
    var maxWidth: CGFloat {
        guard let bounds = self.inputView?.bounds, !bounds.isEmpty else { return UIScreen.main.bounds.width }
        return bounds.width
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        reloadItems()
        runAnalytics()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        coordinator.animate(alongsideTransition: { context in
            self.reloadItems()
        }, completion: { context in })
    }
    
    deinit {
        print("\(self) deinit")
    }
    
    @IBAction func longPressed(sender: UIButton) {
        guard self.textDocumentProxy.hasText else { return }
        self.textDocumentProxy.deleteBackward()
        playClick()
    }
    
    @IBAction func panned(recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
        case .changed, .ended:
            let point = recognizer.location(in: recognizer.view)
            for cell in stackView.cells {
                let frame = cell.convert(cell.bounds, to: stackView)
                let containsPoint = frame.contains(point)
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
    
    func reloadItems() {
        items = Item.all(type: .selected)
        stackView.configure(items, keyboardType: .selected, roundedCorners: Keyboard.hasRoundedCorners, grid: Keyboard.hasGrid, width: maxWidth, block: { (position, item, cell) in
            switch (item.title, item.imageName) {
            case (_, "next"?):
//                cell.isHidden = !needsInputModeSwitchKey
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
        sendAnalytics(item: item)
    }
    
    func playClick() {
        guard hasFullAccess else { return }
        UIDevice.current.playInputClick()
    }
    
    func runAnalytics() {
        guard hasFullAccess else { return }
        Analytics.start
    }
    
    func sendAnalytics(item: Item) {
        guard hasFullAccess else { return }
        (item.title ?? item.imageName).map {
            Analytics.logEvent(name: "clicked", attributes: [Analytics.ParameterValue: $0])
        }
    }
    
}
