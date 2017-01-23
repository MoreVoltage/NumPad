//
//  NumPad.swift
//  NumPad
//
//  Created by Lasha Efremidze on 1/9/16.
//  Copyright © 2016 Lasha Efremidze. All rights reserved.
//

import UIKit

// MARK: - Position
public struct Position {
    let row: Int
    let column: Int
}

// MARK: - NumPadDataSource
public protocol NumPadDataSource: class {
    func numberOfRowsInNumberPad(_ numPad: NumPad) -> Int
    func numPad(_ numPad: NumPad, numberOfColumnsInRow row: Int) -> Int
}

// MARK: - NumPadDelegate
public protocol NumPadDelegate: class {
    func numPad(_ numPad: NumPad, willDisplayButton button: UIButton, forPosition position: Position)
    func numPad(_ numPad: NumPad, sizeForButtonAtPosition position: Position, defaultSize size: CGSize) -> CGSize
    func numPad(_ numPad: NumPad, buttonTappedAtPosition position: Position)
}

public extension NumPadDelegate {
    func numPad(_ numPad: NumPad, willDisplayButton button: UIButton, forPosition position: Position) {}
    func numPad(_ numPad: NumPad, sizeForButtonAtPosition position: Position, defaultSize size: CGSize) -> CGSize { return size }
    func numPad(_ numPad: NumPad, buttonTappedAtPosition position: Position) {}
}

// MARK: - NumPad
open class NumPad: UIView {

    let collectionView = UICollectionView(frame: CGRect(), collectionViewLayout: UICollectionViewFlowLayout())
    
    weak open var dataSource: NumPadDataSource?
    weak open var delegate: NumPadDelegate?
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    func setup() {
        guard let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout else { return }
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .clear
        collectionView.allowsSelection = false
        collectionView.isScrollEnabled = false
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(Cell.self)
        addSubview(collectionView)
        
        let views = ["collectionView": collectionView]
        addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[collectionView]|", options: [], metrics: nil, views: views))
        addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[collectionView]|", options: [], metrics: nil, views: views))
    }
    
    override open func layoutSubviews() {
        super.layoutSubviews()
        
        collectionView.collectionViewLayout.invalidateLayout()
    }
    
}

// MARK: - UICollectionViewDataSource
extension NumPad: UICollectionViewDataSource {
    
    public func numberOfSections(in collectionView: UICollectionView) -> Int {
        return numberOfRows()
    }
    
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return numberOfColumnsInRow(section)
    }
    
    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell: Cell = collectionView.dequeueReusableCell(forIndexPath: indexPath)
        cell.delegate = self
        return cell
    }
    
}

// MARK: - UICollectionViewDelegate
extension NumPad: UICollectionViewDelegate {

    public func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard let button = (cell as? Cell)?.button else { return }
        let position = positionForIndexPath(indexPath)
        delegate?.numPad(self, willDisplayButton: button, forPosition: position)
    }
    
}

// MARK: - UICollectionViewDelegateFlowLayout
extension NumPad: UICollectionViewDelegateFlowLayout {
    
    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let numberOfRows = CGFloat(self.numberOfRows())
        let numberOfColumns = CGFloat(self.numberOfColumnsInRow(indexPath.section))
        
        let width = collectionView.frame.width / numberOfColumns
        let height = collectionView.frame.height / numberOfRows
        let size = CGSize(width: width, height: height)
        
        let position = positionForIndexPath(indexPath)
        return delegate?.numPad(self, sizeForButtonAtPosition: position, defaultSize: size) ?? size
    }
    
}

// MARK: - CellDelegate
extension NumPad: CellDelegate {
    
    func cell(_ cell: Cell, buttonTapped button: UIButton) {
        guard let indexPath = collectionView.indexPath(for: cell) else { return }
        let position = positionForIndexPath(indexPath)
        delegate?.numPad(self, buttonTappedAtPosition: position)
    }
    
}

// MARK: - Helpers
public extension NumPad {
    
    func indexForPosition(_ position: Position) -> Int {
        var index = (0..<position.row).map { numberOfColumnsInRow($0) }.reduce(0, +)
        index += position.column
        return index
    }
    
    func buttonForPosition(_ position: Position) -> UIButton? {
        let indexPath = indexPathForPosition(position)
        let cell = collectionView.cellForItem(at: indexPath)
        return (cell as? Cell)?.button
    }
    
}

extension NumPad {
    
    func indexPathForPosition(_ position: Position) -> IndexPath {
        return IndexPath(item: position.column, section: position.row)
    }
    
    func positionForIndexPath(_ indexPath: IndexPath) -> Position {
        return Position(row: indexPath.section, column: indexPath.item)
    }
    
    func numberOfRows() -> Int {
        return dataSource?.numberOfRowsInNumberPad(self) ?? 0
    }
    
    func numberOfColumnsInRow(_ row: Int) -> Int {
        return dataSource?.numPad(self, numberOfColumnsInRow: row) ?? 0
    }
    
}

// MARK: - CellDelegate
protocol CellDelegate: class {
    func cell(_ cell: Cell, buttonTapped button: UIButton)
}

// MARK: - Cell
class Cell: UICollectionViewCell {
    
    let button = UIButton(type: .custom)
    
    weak var delegate: CellDelegate?
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    func setup() {
        button.translatesAutoresizingMaskIntoConstraints = false
        button.titleLabel?.textAlignment = .center
        button.addTarget(self, action: #selector(Cell.buttonTapped(_:)), for: .touchUpInside)
        contentView.addSubview(button)
        
        let views = ["button": button]
        addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|-1-[button]|", options: [], metrics: nil, views: views))
        addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-1-[button]|", options: [], metrics: nil, views: views))
    }
    
    @IBAction func buttonTapped(_ button: UIButton) {
        delegate?.cell(self, buttonTapped: button)
    }
    
}

// MARK: - ReusableView
protocol ReusableView: class {
    static var defaultReuseIdentifier: String { get }
}

extension ReusableView where Self: UIView {
    static var defaultReuseIdentifier: String {
        return NSStringFromClass(self)
    }
}

extension Cell: ReusableView {}

// MARK: - Extensions
extension UICollectionView {
    
    func register<T: UICollectionViewCell>(_: T.Type) where T: ReusableView {
        self.register(T.self, forCellWithReuseIdentifier: T.defaultReuseIdentifier)
    }
    
    func dequeueReusableCell<T: UICollectionViewCell>(forIndexPath indexPath: IndexPath) -> T where T: ReusableView {
        guard let cell = self.dequeueReusableCell(withReuseIdentifier: T.defaultReuseIdentifier, for: indexPath) as? T else {
            fatalError("Could not dequeue cell with identifier: \(T.defaultReuseIdentifier)")
        }
        return cell
    }
    
}
