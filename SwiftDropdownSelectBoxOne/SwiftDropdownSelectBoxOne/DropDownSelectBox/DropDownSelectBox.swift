//
//  DropDownSelectBox.swift
//  SwiftDropdownSelectBoxOne
//
//  Created by NextDot on 2/2/16.
//  Copyright © 2016 RzRasel. All rights reserved.
//

import Foundation
import UIKit

public typealias Index = Int
public typealias Closure = () -> Void
public typealias SelectionClosure = (Index, String) -> Void
public typealias ConfigurationClosure = (Index, String) -> String
private typealias ComputeLayoutTuple = (x: CGFloat, y: CGFloat, width: CGFloat, offscreenHeight: CGFloat)

/// A Material Design drop down in replacement for `UIPickerView`.
public final class DropDownSelectBox: UIView {
    
    //TODO: handle iOS 7 landscape mode
    
    /// The dismiss mode for a drop down.
    public enum DismissMode {
        
        /// A tap outside the drop down is required to dismiss.
        case OnTap
        
        /// No tap is required to dismiss, it will dimiss when interacting with anything else.
        case Automatic
        
        /// Not dismissable by the user.
        case Manual
        
    }
    
    /// The direction where the drop down will show from the `anchorView`.
    public enum Direction {
        
        /// The drop down will show below the anchor view when possible, otherwise above if there is more place than below.
        case Any
        
        /// The drop down will show above the anchor view or will not be showed if not enough space.
        case Top
        
        /// The drop down will show below or will not be showed if not enough space.
        case Bottom
        
    }
    
    //MARK: - Properties
    
    /// The current visible drop down. There can be only one visible drop down at a time.
    public static weak var VisibleDropDown: DropDownSelectBox?
    
    //MARK: UI
    private let dismissableView = UIView()
    private let tableViewContainer = UIView()
    private let tableView = UITableView()
    
    /// The view to which the drop down will displayed onto.
    public weak var anchorView: UIView? {
        didSet { setNeedsUpdateConstraints() }
    }
    
    /**
     The possible directions where the drop down will be showed.
     
     See `Direction` enum for more info.
     */
    public var direction = Direction.Any
    
    /**
     The offset point relative to `anchorView` when the drop down is shown above the anchor view.
     
     By default, the drop down is showed onto the `anchorView` with the top
     left corner for its origin, so an offset equal to (0, 0).
     You can change here the default drop down origin.
     */
    public var topOffset: CGPoint = CGPointZero {
        didSet { setNeedsUpdateConstraints() }
    }
    
    /**
     The offset point relative to `anchorView` when the drop down is shown below the anchor view.
     
     By default, the drop down is showed onto the `anchorView` with the top
     left corner for its origin, so an offset equal to (0, 0).
     You can change here the default drop down origin.
     */
    public var bottomOffset: CGPoint = CGPointZero {
        didSet { setNeedsUpdateConstraints() }
    }
    
    /**
     The width of the drop down.
     
     Defaults to `anchorView.bounds.width - offset.x`.
     */
    public var width: CGFloat? {
        didSet { setNeedsUpdateConstraints() }
    }
    
    //MARK: Constraints
    private var heightConstraint: NSLayoutConstraint!
    private var widthConstraint: NSLayoutConstraint!
    private var xConstraint: NSLayoutConstraint!
    private var yConstraint: NSLayoutConstraint!
    
    //MARK: Appearance
    public override var backgroundColor: UIColor? {
        get { return tableView.backgroundColor }
        set { tableView.backgroundColor = newValue }
    }
    
    /**
     The background color of the selected cell in the drop down.
     
     Changing the background color automatically reloads the drop down.
     */
    public dynamic var selectionBackgroundColor = DPDSBConstant.UI.SelectionBackgroundColor {
        didSet { reloadAllComponents() }
    }
    
    /**
     The color of the text for each cells of the drop down.
     
     Changing the text color automatically reloads the drop down.
     */
    public dynamic var textColor = UIColor.blackColor() {
        didSet { reloadAllComponents() }
    }
    
    /**
     The font of the text for each cells of the drop down.
     
     Changing the text font automatically reloads the drop down.
     */
    public dynamic var textFont = UIFont.systemFontOfSize(15) {
        didSet { reloadAllComponents() }
    }
    
    //MARK: Content
    
    /**
    The data source for the drop down.
    
    Changing the data source automatically reloads the drop down.
    */
    public var dataSource = [String]() {
        didSet { reloadAllComponents() }
    }
    
    private var selectedRowIndex: Index?
    
    /**
     The format for the cells' text.
     
     By default, the cell's text takes the plain `dataSource` value.
     Changing `cellConfiguration` automatically reloads the drop down.
     */
    public var cellConfiguration: ConfigurationClosure? {
        didSet { reloadAllComponents() }
    }
    
    /// The action to execute when the user selects a cell.
    public var selectionAction: SelectionClosure?
    
    /// The action to execute when the user cancels/hides the drop down.
    public var cancelAction: Closure?
    
    /// The dismiss mode of the drop down. Default is `OnTap`.
    public var dismissMode = DismissMode.OnTap {
        willSet {
            if newValue == .OnTap {
                let gestureRecognizer = UITapGestureRecognizer(target: self, action: "dismissableViewTapped")
                dismissableView.addGestureRecognizer(gestureRecognizer)
            } else if let gestureRecognizer = dismissableView.gestureRecognizers?.first {
                dismissableView.removeGestureRecognizer(gestureRecognizer)
            }
        }
    }
    
    private var minHeight: CGFloat {
        return tableView.rowHeight
    }
    
    private var didSetupConstraints = false
    
    //MARK: - Init's
    
    deinit {
        stopListeningToNotifications()
    }
    
    /**
     Creates a new instance of a drop down.
     Don't forget to setup the `dataSource`,
     the `anchorView` and the `selectionAction`
     at least before calling `show()`.
     */
    public convenience init() {
        self.init(frame: CGRectZero)
    }
    
    /**
     Creates a new instance of a drop down.
     
     - parameter anchorView:        The view to which the drop down will displayed onto.
     - parameter selectionAction:   The action to execute when the user selects a cell.
     - parameter dataSource:        The data source for the drop down.
     - parameter topOffset:         The offset point relative to `anchorView` used when drop down is displayed on above the anchor view.
     - parameter bottomOffset:      The offset point relative to `anchorView` used when drop down is displayed on below the anchor view.
     - parameter cellConfiguration: The format for the cells' text.
     - parameter cancelAction:      The action to execute when the user cancels/hides the drop down.
     
     - returns: A new instance of a drop down customized with the above parameters.
     */
    public convenience init(anchorView: UIView, selectionAction: SelectionClosure? = nil, dataSource: [String] = [], topOffset: CGPoint? = nil, bottomOffset: CGPoint? = nil, cellConfiguration: ConfigurationClosure? = nil, cancelAction: Closure? = nil) {
        self.init(frame: CGRectZero)
        
        self.anchorView = anchorView
        self.selectionAction = selectionAction
        self.dataSource = dataSource
        self.topOffset = topOffset ?? CGPointZero
        self.bottomOffset = bottomOffset ?? CGPointZero
        self.cellConfiguration = cellConfiguration
        self.cancelAction = cancelAction
    }
    
    override public init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }
    
}

//MARK: - Setup

private extension DropDownSelectBox {
    
    func setup() {
        updateConstraintsIfNeeded()
        setupUI()
        
        dismissMode = .OnTap
        
        tableView.delegate = self
        tableView.dataSource = self
        
        tableView.registerNib(DropDownSelectBoxCell.Nib, forCellReuseIdentifier: DPDSBConstant.ReusableIdentifier.DropDownSelectBoxCell)
        
        startListeningToKeyboard()
    }
    
    func setupUI() {
        super.backgroundColor = UIColor.clearColor()
        
        tableViewContainer.layer.masksToBounds = false
        tableViewContainer.layer.cornerRadius = DPDSBConstant.UI.CornerRadius
        tableViewContainer.layer.shadowColor = DPDSBConstant.UI.Shadow.Color
        tableViewContainer.layer.shadowOffset = DPDSBConstant.UI.Shadow.Offset
        tableViewContainer.layer.shadowOpacity = DPDSBConstant.UI.Shadow.Opacity
        tableViewContainer.layer.shadowRadius = DPDSBConstant.UI.Shadow.Radius
        
        setupTableViewUI()
        
        setHiddentState()
        hidden = true
    }
    
    func setupTableViewUI() {
        backgroundColor = DPDSBConstant.UI.BackgroundColor
        tableView.rowHeight = DPDSBConstant.UI.RowHeight
        tableView.separatorColor = DPDSBConstant.UI.SeparatorColor
        tableView.separatorStyle = DPDSBConstant.UI.SeparatorStyle
        tableView.separatorInset = DPDSBConstant.UI.SeparatorInsets
        tableView.layer.cornerRadius = DPDSBConstant.UI.CornerRadius
        tableView.layer.masksToBounds = true
    }
    
}

//MARK: - UI

extension DropDownSelectBox {
    
    public override func updateConstraints() {
        if !didSetupConstraints {
            setupConstraints()
        }
        
        didSetupConstraints = true
        
        let layout = computeLayout()
        
        if !layout.canBeDisplayed {
            super.updateConstraints()
            hide()
            
            return
        }
        
        xConstraint.constant = layout.x
        yConstraint.constant = layout.y
        widthConstraint.constant = layout.width
        heightConstraint.constant = layout.visibleHeight
        
        tableView.scrollEnabled = layout.offscreenHeight > 0
        
        dispatch_async(dispatch_get_main_queue()) { [unowned self] in
            self.tableView.flashScrollIndicators()
        }
        
        super.updateConstraints()
    }
    
    private func setupConstraints() {
        translatesAutoresizingMaskIntoConstraints = false
        
        // Dismissable view
        addSubview(dismissableView)
        dismissableView.translatesAutoresizingMaskIntoConstraints = false
        
        addUniversalConstraints(format: "|[dismissableView]|", views: ["dismissableView": dismissableView])
        
        
        // Table view container
        addSubview(tableViewContainer)
        tableViewContainer.translatesAutoresizingMaskIntoConstraints = false
        
        xConstraint = NSLayoutConstraint(
            item: tableViewContainer,
            attribute: .Leading,
            relatedBy: .Equal,
            toItem: self,
            attribute: .Leading,
            multiplier: 1,
            constant: 0)
        addConstraint(xConstraint)
        
        yConstraint = NSLayoutConstraint(
            item: tableViewContainer,
            attribute: .Top,
            relatedBy: .Equal,
            toItem: self,
            attribute: .Top,
            multiplier: 1,
            constant: 0)
        addConstraint(yConstraint)
        
        widthConstraint = NSLayoutConstraint(
            item: tableViewContainer,
            attribute: .Width,
            relatedBy: .Equal,
            toItem: nil,
            attribute: .NotAnAttribute,
            multiplier: 1,
            constant: 0)
        tableViewContainer.addConstraint(widthConstraint)
        
        heightConstraint = NSLayoutConstraint(
            item: tableViewContainer,
            attribute: .Height,
            relatedBy: .Equal,
            toItem: nil,
            attribute: .NotAnAttribute,
            multiplier: 1,
            constant: 0)
        tableViewContainer.addConstraint(heightConstraint)
        
        // Table view
        tableViewContainer.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        
        tableViewContainer.addUniversalConstraints(format: "|[tableView]|", views: ["tableView": tableView])
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        
        // When orientation changes, layoutSubviews is called
        // We update the constraint to update the position
        setNeedsUpdateConstraints()
        
        let shadowPath = UIBezierPath(rect: tableViewContainer.bounds)
        tableViewContainer.layer.shadowPath = shadowPath.CGPath
    }
    
    private func computeLayout() -> (x: CGFloat, y: CGFloat, width: CGFloat, offscreenHeight: CGFloat, visibleHeight: CGFloat, canBeDisplayed: Bool, Direction: Direction) {
        var layout: ComputeLayoutTuple = (0, 0, 0, 0)
        var direction = self.direction
        
        if let window = UIWindow.visibleWindow() {
            switch direction {
            case .Any:
                layout = computeLayoutBottomDisplay(window: window)
                direction = .Bottom
                
                if layout.offscreenHeight > 0 {
                    let topLayout = computeLayoutForTopDisplay(window: window)
                    
                    if topLayout.offscreenHeight < layout.offscreenHeight {
                        layout = topLayout
                        direction = .Top
                    }
                }
            case .Bottom:
                layout = computeLayoutBottomDisplay(window: window)
                direction = .Bottom
            case .Top:
                layout = computeLayoutForTopDisplay(window: window)
                direction = .Top
            }
        }
        
        let visibleHeight = tableHeight - layout.offscreenHeight
        let canBeDisplayed = visibleHeight >= minHeight
        
        return (layout.x, layout.y, layout.width, layout.offscreenHeight, visibleHeight, canBeDisplayed, direction)
    }
    
    private func computeLayoutBottomDisplay(window window: UIWindow) -> ComputeLayoutTuple {
        var offscreenHeight: CGFloat = 0
        
        let anchorViewX = (anchorView?.windowFrame?.minX ?? 0)
        let anchorViewY = (anchorView?.windowFrame?.minY ?? 0)
        
        let x = anchorViewX + bottomOffset.x
        let y = anchorViewY + bottomOffset.y
        
        let maxY = y + tableHeight
        let windowMaxY = window.bounds.maxY - DPDSBConstant.UI.HeightPadding
        
        let keyboardListener = DPDSBKeyboardListener.sharedInstance
        let keyboardMinY = keyboardListener.keyboardFrame.minY - DPDSBConstant.UI.HeightPadding
        
        if keyboardListener.isVisible && maxY > keyboardMinY {
            offscreenHeight = abs(maxY - keyboardMinY)
        } else if maxY > windowMaxY {
            offscreenHeight = abs(maxY - windowMaxY)
        }
        
        let width = self.width ?? (anchorView?.bounds.width ?? 0) - bottomOffset.x
        
        return (x, y, width, offscreenHeight)
    }
    
    private func computeLayoutForTopDisplay(window window: UIWindow) -> ComputeLayoutTuple {
        var offscreenHeight: CGFloat = 0
        
        let anchorViewX = (anchorView?.windowFrame?.minX ?? 0)
        let anchorViewMaxY = (anchorView?.windowFrame?.maxY ?? 0)
        
        let x = anchorViewX + topOffset.x
        var y = (anchorViewMaxY + topOffset.y) - tableHeight
        
        let windowY = window.bounds.minY + DPDSBConstant.UI.HeightPadding
        
        if y < windowY {
            offscreenHeight = abs(y - windowY)
            y = windowY
        }
        
        let width = self.width ?? (anchorView?.bounds.width ?? 0) - topOffset.x
        
        return (x, y, width, offscreenHeight)
    }
    
}

//MARK: - Actions

extension DropDownSelectBox {
    
    /**
     Shows the drop down if enough height.
     
     - returns: Wether it succeed and how much height is needed to display all cells at once.
     */
    public func show() -> (canBeDisplayed: Bool, offscreenHeight: CGFloat?) {
        if self == DropDownSelectBox.VisibleDropDown {
            return (true, 0)
        }
        
        if let visibleDropDown = DropDownSelectBox.VisibleDropDown {
            visibleDropDown.cancel()
        }
        
        DropDownSelectBox.VisibleDropDown = self
        
        setNeedsUpdateConstraints()
        
        let visibleWindow = UIWindow.visibleWindow()
        visibleWindow?.addSubview(self)
        visibleWindow?.bringSubviewToFront(self)
        
        self.translatesAutoresizingMaskIntoConstraints = false
        visibleWindow?.addUniversalConstraints(format: "|[dropDown]|", views: ["dropDown": self])
        
        let layout = computeLayout()
        
        if !layout.canBeDisplayed {
            hide()
            return (layout.canBeDisplayed, layout.offscreenHeight)
        }
        
        hidden = false
        tableViewContainer.transform = DPDSBConstant.Animation.DownScaleTransform
        
        UIView.animateWithDuration(
            DPDSBConstant.Animation.Duration,
            delay: 0,
            options: DPDSBConstant.Animation.EntranceOptions,
            animations: { [unowned self] in
                self.setShowedState()
            },
            completion: nil)
        
        selectRowAtIndex(selectedRowIndex)
        
        return (layout.canBeDisplayed, layout.offscreenHeight)
    }
    
    /// Hides the drop down.
    public func hide() {
        if self == DropDownSelectBox.VisibleDropDown {
            /*
            If one drop down is showed and another one is not
            but we call `hide()` on the hidden one:
            we don't want it to set the `VisibleDropDown` to nil.
            */
            DropDownSelectBox.VisibleDropDown = nil
        }
        
        if hidden {
            return
        }
        
        UIView.animateWithDuration(
            DPDSBConstant.Animation.Duration,
            delay: 0,
            options: DPDSBConstant.Animation.ExitOptions,
            animations: { [unowned self] in
                self.setHiddentState()
            },
            completion: { [unowned self] finished in
                self.hidden = true
                self.removeFromSuperview()
            })
    }
    
    private func cancel() {
        hide()
        cancelAction?()
    }
    
    private func setHiddentState() {
        alpha = 0
    }
    
    private func setShowedState() {
        alpha = 1
        tableViewContainer.transform = CGAffineTransformIdentity
    }
    
}

//MARK: - UITableView

extension DropDownSelectBox {
    
    /**
     Reloads all the cells.
     
     It should not be necessary in most cases because each change to
     `dataSource`, `textColor`, `textFont`, `selectionBackgroundColor`
     and `cellConfiguration` implicitly calls `reloadAllComponents()`.
     */
    public func reloadAllComponents() {
        if #available(iOS 9, *) {
            setupTableViewUI()
        }
        
        tableView.reloadData()
        setNeedsUpdateConstraints()
    }
    
    /// (Pre)selects a row at a certain index.
    public func selectRowAtIndex(index: Index?) {
        if let index = index {
            tableView.selectRowAtIndexPath(
                NSIndexPath(forRow: index, inSection: 0),
                animated: false,
                scrollPosition: .Middle)
        } else {
            deselectRowAtIndexPath(selectedRowIndex)
        }
        
        selectedRowIndex = index
    }
    
    public func deselectRowAtIndexPath(index: Index?) {
        selectedRowIndex = nil
        
        guard let index = index
            where index > 0
            else { return }
        
        tableView.deselectRowAtIndexPath(NSIndexPath(forRow: index, inSection: 0), animated: true)
    }
    
    /// Returns the index of the selected row.
    public var indexForSelectedRow: Index? {
        return tableView.indexPathForSelectedRow?.row
    }
    
    /// Returns the selected item.
    public var selectedItem: String? {
        guard let row = tableView.indexPathForSelectedRow?.row else { return nil }
        
        return dataSource[row]
    }
    
    /// Returns the height needed to display all cells.
    private var tableHeight: CGFloat {
        return tableView.rowHeight * CGFloat(dataSource.count)
    }
    
}

//MARK: - UITableViewDataSource - UITableViewDelegate

extension DropDownSelectBox: UITableViewDataSource, UITableViewDelegate {
    
    public func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataSource.count
    }
    
    public func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier(DPDSBConstant.ReusableIdentifier.DropDownSelectBoxCell, forIndexPath: indexPath) as! DropDownSelectBoxCell
        
        cell.optionLabel.textColor = textColor
        cell.optionLabel.font = textFont
        cell.selectedBackgroundColor = selectionBackgroundColor
        
        if let cellConfiguration = cellConfiguration {
            let index = indexPath.row
            cell.optionLabel.text = cellConfiguration(index, dataSource[index])
        } else {
            cell.optionLabel.text = dataSource[indexPath.row]
        }
        
        return cell
    }
    
    public func tableView(tableView: UITableView, willDisplayCell cell: UITableViewCell, forRowAtIndexPath indexPath: NSIndexPath) {
        cell.selected = indexPath.row == selectedRowIndex
    }
    
    public func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        selectedRowIndex = indexPath.row
        selectionAction?(selectedRowIndex!, dataSource[selectedRowIndex!])
        hide()
    }
    
}

//MARK: - Auto dismiss

extension DropDownSelectBox {
    
    public override func hitTest(point: CGPoint, withEvent event: UIEvent?) -> UIView? {
        let view = super.hitTest(point, withEvent: event)
        
        if dismissMode == .Automatic && view === dismissableView {
            cancel()
            return nil
        } else {
            return view
        }
    }
    
    @objc
    private func dismissableViewTapped() {
        cancel()
    }
    
}

//MARK: - Keyboard events

extension DropDownSelectBox {
    
    /**
     Starts listening to keyboard events.
     Allows the drop down to display correctly when keyboard is showed.
     */
    public static func startListeningToKeyboard() {
        DPDSBKeyboardListener.sharedInstance.startListeningToKeyboard()
    }
    
    private func startListeningToKeyboard() {
        DPDSBKeyboardListener.sharedInstance.startListeningToKeyboard()
        
        NSNotificationCenter.defaultCenter().addObserver(
            self,
            selector: "keyboardUpdate",
            name: UIKeyboardDidShowNotification,
            object: nil)
        NSNotificationCenter.defaultCenter().addObserver(
            self,
            selector: "keyboardUpdate",
            name: UIKeyboardDidHideNotification,
            object: nil)
    }
    
    private func stopListeningToNotifications() {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    @objc
    private func keyboardUpdate() {
        self.setNeedsUpdateConstraints()
    }
    
}