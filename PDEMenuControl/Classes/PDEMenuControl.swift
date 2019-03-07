//
//  PDEMenuControl.swift
//  PDEMenuControl
//
//  Created by Takeshi Tanaka on 2019/03/05.
//  Copyright © 2019 p0dee. All rights reserved.
//

import UIKit

public class PDEMenuControl: UIControl {
    
    public struct Configure {
        public let itemSpacing: CGFloat
        public let indicatorSidePadding: CGFloat
        public let fillsAllItemsInBounds: Bool
        public let fillsItemsEqually: Bool
        
        public init(itemSpacing: CGFloat, indicatorSidePadding: CGFloat, fillsAllItemsInBounds: Bool, fillsItemsEqually: Bool) {
            self.itemSpacing = itemSpacing
            self.indicatorSidePadding = indicatorSidePadding
            self.fillsAllItemsInBounds = fillsAllItemsInBounds
            self.fillsItemsEqually = fillsItemsEqually
        }
        
        public static let `default`: Configure = .init(itemSpacing: 20, indicatorSidePadding: 12, fillsAllItemsInBounds: false, fillsItemsEqually: false)
    }
    
    public enum LayoutMode {
        case fill, equalWidth(width: CGFloat)
    }
    
    private let scrollView = UIScrollView()
    private let menuView = MenuLabelsView()
    private let indicatorBaseView = UIView()
    private let indicatorView = UIImageView()
    private let menuViewSnapshotImageView = UIImageView()
    private let menuViewSnapshotMaskImageView = UIImageView()
    
    let configure: Configure
    
    public var items: [String] = [] {
        didSet {
            menuView.items = items
            value = 0
            setNeedsLayout()
        }
    }
    
    private struct IndexCache {
        private(set) var latestNearest: Int?
        private(set) var current: Int = 0
        
        mutating func updateLatestNearest(to index: Int?) {
            latestNearest = index
        }
        
        mutating func updateCurrent(to index: Int) {
            current = index
        }
        
        static let initial = IndexCache(latestNearest: nil, current: 0)
    }
    
    private var indexCache: IndexCache = .initial
    
    public var value: CGFloat = .init(IndexCache.initial.current) {
        didSet {
            let current = indexCache.current
            let nearest = Int(round(value))
            if let latest = indexCache.latestNearest, latest != nearest {
                let haptic = UISelectionFeedbackGenerator()
                haptic.selectionChanged()
            }
            indexCache.updateLatestNearest(to: nearest)
            if abs(value - CGFloat(current)) >= 1 {
                indexCache.updateCurrent(to: nearest)
            }
            let currentIdxRect: CGRect = menuView.labelFrame(forIndex: indexCache.current) ?? .zero
            let nearestIdxRect: CGRect = menuView.labelFrame(forIndex: nearest) ?? .zero
            let indFr = indicatorFrameWidth(currentIndex: indexCache.current, rect: currentIdxRect, nearestIndex: nearest, rect: nearestIdxRect, elasticityMaxWidth: 15, value: value).insetBy(dx: -configure.indicatorSidePadding, dy: 0)
            indicatorView.frame = indFr.intersection(CGRect(origin: .zero, size: scrollView.contentSize).insetBy(dx: -configure.indicatorSidePadding, dy: 0)) //エッジからさらに奥にスクロールした際にインジケータが見切れないようにするため
            menuViewSnapshotMaskImageView.frame = indicatorView.frame
            scrollView.scrollRectToVisible(indicatorView.frame.insetBy(dx: -80, dy: 0), animated: false)
        }
    }
    
    private func indicatorFrameWidth(currentIndex i1: Int, rect r1: CGRect, nearestIndex i2: Int, rect r2: CGRect, elasticityMaxWidth we: CGFloat, value: CGFloat) -> CGRect {
        let v = value - round(value) // -0.5...0.5
        let x: CGFloat
        let w: CGFloat
        let e1 = we * abs(v) * 2 //進行方向側端の伸び幅
        let e2 = e1 / 2//進行方向反対側端の進み幅
        switch (i1 == i2, v >= 0) {
        case (true, true):
            w = r1.width + e1
            x = r1.minX + e2
        case (true, false):
            w = r1.width + e1
            x = r1.maxX - w - e2
        case (false, true):
            w = r2.width + e1
            x = r2.minX + e2
        case (false, false):
            w = r2.width + e1
            x = r2.maxX - w - e2
        }
        return .init(x: x, y: 0, width: w, height: r1.height)
    }
    
    override public func layoutSubviews() {
        super.layoutSubviews()
        updateMenuContentWidth()
        scrollView.frame = bounds.insetBy(dx: configure.indicatorSidePadding, dy: 0)
        indicatorView.tintColor = UIColor(red: 0xf0/255.0, green: 0x91/255.0, blue: 0x99/255.0, alpha: 1.0)//f09199
        indicatorView.image = UIImage.strechableRoundedRect(height: menuView.bounds.height)?.withRenderingMode(.alwaysTemplate)
        menuViewSnapshotMaskImageView.image = indicatorView.image
        DispatchQueue.main.async {
            self.updateOverlayIndicatorMask()
        }
    }
    
    private var maxIndex: CGFloat {
        return CGFloat(items.count)
    }
    
    public init(configure: Configure) {
        self.configure = configure
        super.init(frame: .zero)
        setUpViews()
        setUpConstraints()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setUpViews() {
        clipsToBounds = true
        addSubview(scrollView)
        menuView.stackView.distribution = configure.fillsItemsEqually ? .fillEqually : .fillProportionally
        menuView.stackView.spacing = configure.itemSpacing
        scrollView.addSubview(menuView)
        scrollView.addSubview(indicatorBaseView)
        scrollView.clipsToBounds = false
        scrollView.showsHorizontalScrollIndicator = false
        indicatorBaseView.addSubview(indicatorView)
        menuViewSnapshotImageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        menuViewSnapshotImageView.frame = indicatorBaseView.bounds
        menuViewSnapshotImageView.tintColor = .white
        indicatorBaseView.addSubview(menuViewSnapshotImageView)
        indicatorBaseView.addSubview(menuViewSnapshotMaskImageView)
        menuViewSnapshotImageView.mask = menuViewSnapshotMaskImageView
        //tap gesture
        let tap = UITapGestureRecognizer(target: self, action: #selector(didTapMenu(gesture:)))
        scrollView.addGestureRecognizer(tap)
    }
    
    private func setUpConstraints() {
    }
    
    private func updateMenuContentWidth() {
        let estimatedWidth: CGFloat
        if configure.fillsAllItemsInBounds {
            estimatedWidth = bounds.width
        } else {
            estimatedWidth = menuView.stackView.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize).width
            
        }
        let height = scrollView.bounds.height
        menuView.frame = .init(origin: .zero, size: .init(width: estimatedWidth, height: height))
        scrollView.contentSize = .init(width: estimatedWidth, height: height)
        menuViewSnapshotImageView.frame = menuView.bounds
    }
    
    private func updateOverlayIndicatorMask() {
        menuViewSnapshotImageView.image = menuView.stackView.snapshot()?.withRenderingMode(.alwaysTemplate)
    }
    
    @objc private func didTapMenu(gesture: UITapGestureRecognizer) {
        let point = convert(gesture.location(in: self), to: menuView.stackView)
        let index = menuView.stackView.arrangedSubviews.firstIndex {
            return $0.frame.contains(point)
        }
        if index != nil {
            sendActions(for: .valueChanged)
        }
    }
    
}

private class MenuLabelsView: UIView {
    
    let stackView = UIStackView()
    
    var items: [String] = [] {
        didSet {
            constructLabels()
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setUpViews()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setUpViews() {
        stackView.frame = bounds
        stackView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        stackView.axis = .horizontal
        addSubview(stackView)
    }
    
    private func constructLabels() {
        stackView.arrangedSubviews.forEach {
            stackView.removeArrangedSubview($0)
        }
        for (index, item) in items.enumerated() {
            let label = commonLabel()
            label.font = .systemFont(ofSize: 13)
            label.text = item
            label.tag = tagForLabel(index: index)
            stackView.addArrangedSubview(label)
        }
    }
    
    private func commonLabel() -> UILabel {
        let label = UILabel()
        label.textAlignment = .center
        return label
    }
    
    private func tagForLabel(index: Int) -> Int {
        return 100 + index
    }
    
    func labelFrame(forIndex index: Int) -> CGRect? {
        let tag = tagForLabel(index: index)
        guard let rect = stackView.viewWithTag(tag)?.frame else {
            return nil
        }
        return stackView.convert(rect, to: self) //TODO: cache
    }
    
}
