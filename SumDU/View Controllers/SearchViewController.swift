//
//  SearchViewController.swift
//  SumDU
//
//  Created by Yura Voevodin on 11.07.16.
//  Copyright © 2016 App Dev Academy. All rights reserved.
//

import Cartography
import UIKit
import SwiftyJSON

class SearchViewController: UIViewController {
    
    // MARK: - Constants
    
    private let scrollConstraintGroup = ConstraintGroup()
    
    // MARK: - Variables
    
    private var previousScrollPoint: CGFloat = 0.0
    private var needUpdateContent = true
    private var updateOnScroll = true
    private var parser = Parser()
    private var model = DataModel(auditoriums: [], groups: [], teachers: [], history: [], currentState: .Favorites)
    private var searchMode = false
    private var searchText: String?
    
    // MARK: - UI objects
    
    private let searchBarView = SearchBarView()
    private var menuCollectionView: UICollectionView!
    private let scrollLineView = UIView()
    private let scrollingIndicatorView = UIView()
    private var contentCollectionView: UICollectionView!
    
    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Data
        parser.dataListDelegate = self
        model.updateFromStorage()

        // UI
        initialSetup()
        
        if UIDevice.currentDevice().userInterfaceIdiom == .Pad {
            if let firstItem = model.history.first {
                let schedule = ScheduleViewController(data: firstItem)
                splitViewController?.viewControllers[1] = schedule
            }
        }
    }
    
    override func viewWillTransitionToSize(size: CGSize, withTransitionCoordinator coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransitionToSize(size, withTransitionCoordinator: coordinator)
        
        // Menu
        menuCollectionView.collectionViewLayout.invalidateLayout()
        
        // Content
        contentCollectionView.collectionViewLayout.invalidateLayout()
//        contentCollectionView.reloadData()
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        // Check if lists of Teachers, Groups and Auditoriums was updated more than 3 days ago
        let lastUpdatedDate = NSUserDefaults.standardUserDefaults().objectForKey(UserDefaultsKey.LastUpdatedAtDate.key) as? NSDate
        if (lastUpdatedDate == nil) || (lastUpdatedDate != nil && lastUpdatedDate!.compare(NSDate().dateBySubtractingDays(3)) == .OrderedAscending) {
            model.updateFromServer(with: parser)
        }
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        
        updateMenuScrollIndicator()
        preselectMenuItem()
    }
    
    // MARK: - Helpers
    
    private func initialSetup() {
        
        view.backgroundColor = UIColor.whiteColor()
        
        // Search bar
        searchBarView.delegate = self
        view.addSubview(searchBarView)
        constrain(searchBarView, view) { searchBarView, superview in
            
            searchBarView.top == superview.top + 30.0
            searchBarView.leading == superview.leading + 14.0
            searchBarView.trailing == superview.trailing
            searchBarView.height == SearchBarView.viewHeight
        }
        
        // Menu
        let flowLayout = UICollectionViewFlowLayout()
        flowLayout.scrollDirection = .Horizontal
        menuCollectionView = UICollectionView(frame: view.bounds, collectionViewLayout: flowLayout)
        menuCollectionView.registerClass(MenuCollectionViewCell.self, forCellWithReuseIdentifier: MenuCollectionViewCell.reuseIdentifier)
        menuCollectionView.delegate = self
        menuCollectionView.dataSource = self
        menuCollectionView.showsVerticalScrollIndicator = false
        menuCollectionView.showsHorizontalScrollIndicator = false
        menuCollectionView.pagingEnabled = true
        menuCollectionView.backgroundColor = UIColor.whiteColor()
        view.addSubview(menuCollectionView)
        constrain(searchBarView, menuCollectionView, view) {
            searchBarView, menuCollectionView, superview in
            
            menuCollectionView.top == searchBarView.bottom
            menuCollectionView.leading == superview.leading
            menuCollectionView.trailing == superview.trailing
            menuCollectionView.height == 62.0
        }
        
        // Scroll line
        scrollLineView.backgroundColor = Color.separator
        view.addSubview(scrollLineView)
        constrain(scrollLineView, menuCollectionView, view) {
            scrollLineView, menuCollectionView, superview in
            
            scrollLineView.top == menuCollectionView.bottom
            scrollLineView.leading == superview.leading
            scrollLineView.trailing == superview.trailing
            scrollLineView.height == 1.0
        }
        
        // Scrolling indocator
        scrollingIndicatorView.backgroundColor = Color.textBlack
        view.addSubview(scrollingIndicatorView)
        constrain(scrollingIndicatorView, scrollLineView, view) {
            scrollingIndicatorView, scrollLineView, superview in
            
            scrollingIndicatorView.bottom == scrollLineView.bottom
            scrollingIndicatorView.height == 2.0
        }
        
        // Content
        let contentFlowLayout = UICollectionViewFlowLayout()
        contentFlowLayout.scrollDirection = .Horizontal
        contentCollectionView = UICollectionView(frame: self.view.bounds, collectionViewLayout: contentFlowLayout)
//        contentCollectionView.scrollEnabled = false
        contentCollectionView.backgroundColor = UIColor.whiteColor()
        contentCollectionView.registerClass(TypeCollectionViewCell.self, forCellWithReuseIdentifier: TypeCollectionViewCell.reuseIdentifier)
        contentCollectionView.showsVerticalScrollIndicator = false
        contentCollectionView.showsHorizontalScrollIndicator = false
        contentCollectionView.delegate = self
        contentCollectionView.dataSource = self
        view.addSubview(contentCollectionView)
        constrain(scrollLineView, contentCollectionView, view) {
            scrollLineView, contentCollectionView, superview in
            
            contentCollectionView.top == scrollLineView.bottom
            contentCollectionView.leading == superview.leading
            contentCollectionView.trailing == superview.trailing
            contentCollectionView.bottom == superview.bottom
        }
    }
    
    private func labelWidth(text: String) -> CGFloat {
        let size = CGSize(width: CGFloat.max, height: MenuCollectionViewCell.cellHeight)
        let attributes = [NSFontAttributeName: FontManager.getFont(name: FontName.HelveticaNeueMedium, size: 17.0)]
        return text.boundingRectWithSize(size, options: .UsesLineFragmentOrigin, attributes: attributes, context: nil).size.width
    }
    
    /// Calculate spacing between items in menu
    private func interItemSpacing() -> CGFloat {
        let screenWidth = view.bounds.width
        var spacing = screenWidth
        spacing -= MenuCollectionViewCell.historyImageSize.width
        spacing -= labelWidth(State.Teachers.name)
        spacing -= labelWidth(State.Auditoriums.name)
        spacing -= labelWidth(State.Groups.name)
        return spacing/4.0
    }
    
    /// Update scroll indicator in menu
    private func updateMenuScrollIndicator() {
        let spacing = interItemSpacing()
        var leading: CGFloat = 0.0
        var width: CGFloat = labelWidth(model.currentState.name)
        let historyImageWidth = MenuCollectionViewCell.historyImageSize.width
        switch model.currentState {
            
        case .Favorites:
            leading = spacing/2
            width = historyImageWidth
            
        case .Teachers:
            leading = spacing + spacing/2
            leading += historyImageWidth
            
        case .Groups:
            leading = spacing*2 + spacing/2
            leading += historyImageWidth
            leading += labelWidth(State.Teachers.name)
            
        case .Auditoriums:
            leading = spacing*3 + spacing/2
            leading += historyImageWidth
            leading += labelWidth(State.Teachers.name)
            leading += labelWidth(State.Groups.name)
        }
        constrain(scrollingIndicatorView, view, replace: scrollConstraintGroup) { scrollingIndicatorView, superview in
            scrollingIndicatorView.leading == superview.leading + leading
            scrollingIndicatorView.width == width
        }
    }
    
    /// Select item in menu collection view
    private func preselectMenuItem() {
        let indexPath = NSIndexPath(forItem: model.currentState.rawValue, inSection: 0)
        menuCollectionView.selectItemAtIndexPath(indexPath, animated: true, scrollPosition: .None)
    }
    
    /// Reload current cell with content
    private func reloadCurrentContent() {
        let indexPath = NSIndexPath(forItem: model.currentState.rawValue, inSection: 0)
        contentCollectionView.reloadItemsAtIndexPaths([indexPath])
    }
    
    // MARK: - Actions
    
    /// Add new item to the history
    func addToHistory(item: ListData) {
        while model.history.count > 50 { model.history.removeFirst() }
        if !model.history.contains(item) { model.history.append(item) }
        ListData.saveToStorage(model.history, forKey: UserDefaultsKey.History.key)
    }
}

// MARK: - SearchBarViewDelegate

extension SearchViewController: SearchBarViewDelegate {
    
    func refreshContent(searchBarView view: SearchBarView) {
        model.updateFromServer(with: parser)
    }
    
    func searchBarView(searchBarView view: SearchBarView, searchWithText text: String?) {
        searchText = text
        reloadCurrentContent()
    }
    
    func searchBarView(searchBarView view: SearchBarView, searchMode: Bool) {
        self.searchMode = searchMode
        reloadCurrentContent()
    }
}

// MARK: - UICollectionViewDelegate

extension SearchViewController: UICollectionViewDelegate {
    
    func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        // Menu
        if collectionView == menuCollectionView {
            if let current = State(rawValue: indexPath.row) {
                model.currentState = current
                updateOnScroll = false
                
                // Update menu
                updateMenuScrollIndicator()
                UIView.animateWithDuration(0.3, animations: view.layoutIfNeeded)
                
                // Scroll to item in bottom collection view with content
                reloadCurrentContent()
                contentCollectionView.scrollToItemAtIndexPath(indexPath, atScrollPosition: .CenteredHorizontally, animated: true)
            }
        }
    }
}

// MARK: - UICollectionViewDataSource

extension SearchViewController: UICollectionViewDataSource {
    
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return 4
    }
    
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        // Menu
        if collectionView == menuCollectionView {
            let cell = collectionView.dequeueReusableCellWithReuseIdentifier(MenuCollectionViewCell.reuseIdentifier, forIndexPath: indexPath) as! MenuCollectionViewCell
            if indexPath.row != 0, let segment = State(rawValue: indexPath.row) {
                cell.update(with: segment.name)
            } else {
                cell.updateWithImage()
            }
            return cell
        } else {
            // Content
            let cell = collectionView.dequeueReusableCellWithReuseIdentifier(TypeCollectionViewCell.reuseIdentifier, forIndexPath: indexPath) as! TypeCollectionViewCell
            let data = model.currentDataBySections(searchText)
            if indexPath.row == 0 && data.count == 0 && !searchMode {
                cell.updateWithImage()
            } else {
                cell.update(with: data, search: searchMode, searchText: searchText, viewController: self)
            }
            return cell
        }
    }
}

// MARK: - UICollectionViewDelegateFlowLayout

extension SearchViewController: UICollectionViewDelegateFlowLayout {
    
    func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAtIndex section: Int) -> CGFloat {
        return 0.0
    }
    
    func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAtIndex section: Int) -> CGFloat {
        return 0.0
    }
    
    func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAtIndexPath indexPath: NSIndexPath) -> CGSize {
        // Menu
        if collectionView == menuCollectionView, let type = State(rawValue: indexPath.row) {
            let spacing = interItemSpacing()
            let cellHeight = MenuCollectionViewCell.cellHeight
            switch type {
            case .Favorites:
                return CGSize(width: MenuCollectionViewCell.historyImageSize.width + spacing, height: cellHeight)
            case .Auditoriums, .Groups, .Teachers:
                return CGSize(width: labelWidth(type.name) + spacing, height: cellHeight)
            }
        } else if collectionView == contentCollectionView {
            // Content
            return CGSizeMake(collectionView.bounds.size.width, collectionView.bounds.size.height)
        }
        return CGSizeMake(0.0, 0.0)
    }
}

// MARK: - UIScrollViewDelegate

extension SearchViewController: UIScrollViewDelegate {
    
    func scrollViewWillEndDragging(scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        
        let pageWidth = contentCollectionView.bounds.size.width
        let currentOffset = scrollView.contentOffset.x
        let targetOffset = targetContentOffset.memory.x
        var newTargetOffset: CGFloat = 0.0
        if (targetOffset > currentOffset) {
            newTargetOffset = ceil(currentOffset/pageWidth)*pageWidth
        } else {
            newTargetOffset = floor(currentOffset/pageWidth)*pageWidth
        }
        if (newTargetOffset < 0) {
            newTargetOffset = 0
        } else if (newTargetOffset > scrollView.contentSize.width) {
            newTargetOffset = scrollView.contentSize.width
        }
        targetContentOffset.memory.x = currentOffset
        contentCollectionView.setContentOffset(CGPointMake(newTargetOffset, 0), animated: true)
        
        previousScrollPoint = newTargetOffset
        updateOnScroll = true
    }
    
    func scrollViewDidEndScrollingAnimation(scrollView: UIScrollView) {
        // Update state
        let pageNumber = round(scrollView.contentOffset.x / scrollView.frame.size.width)
        let indexPath = NSIndexPath(forItem: Int(pageNumber), inSection: 0)
        if let state = State(rawValue: indexPath.row) { model.currentState = state }
        // Update menu
        updateMenuScrollIndicator()
        UIView.animateWithDuration(0.3, animations: view.layoutIfNeeded)
        preselectMenuItem()
        needUpdateContent = true
    }
    
    func scrollViewDidScroll(scrollView: UIScrollView) {
        
        if !updateOnScroll { return }
        
        let currentOffset = scrollView.contentOffset.x
        let frameWidth = scrollView.frame.size.width
        
        if currentOffset > previousScrollPoint {
            let newStateIndex = ceil(currentOffset/frameWidth)
            if let state = State(rawValue: Int(newStateIndex)) { model.currentState = state }
        } else {
            let newStateIndex = floor(currentOffset/frameWidth)
            if let state = State(rawValue: Int(newStateIndex)) { model.currentState = state }
        }
        if needUpdateContent {
            reloadCurrentContent()
            needUpdateContent = false
        }
    }
}

// MARK: - ParserDataListDelegate

extension SearchViewController: ParserDataListDelegate {
    
    func getRelatedData(response: JSON, requestType: ListDataType) {
        UIApplication.sharedApplication().networkActivityIndicatorVisible = true
        var needToUpdateUI = false
        let records = ListData.from(json: response, type: requestType)
        
        switch requestType {
        case .Auditorium:
            model.auditoriums = records
            ListData.saveToStorage(model.auditoriums, forKey: UserDefaultsKey.Auditoriums.key)
            if model.currentState == .Auditoriums { needToUpdateUI = true }
        case .Group:
            model.groups = records
            ListData.saveToStorage(model.groups, forKey: UserDefaultsKey.Groups.key)
            if model.currentState == .Groups { needToUpdateUI = true }
        case .Teacher:
            model.teachers = records
            ListData.saveToStorage(model.teachers, forKey: UserDefaultsKey.Teachers.key)
            if model.currentState == .Teachers { needToUpdateUI = true }
        }
        // Update UI
        UIApplication.sharedApplication().networkActivityIndicatorVisible = false
        if needToUpdateUI { reloadCurrentContent() }
    }
}