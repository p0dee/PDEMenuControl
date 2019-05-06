//
//  PDEMenuControl.swift
//  PDEMenuControl
//
//  Created by Takeshi Tanaka on 2019/03/05.
//  Copyright © 2019 p0dee. All rights reserved.
//

import UIKit

public protocol PDEMenuControlDelegate: class {
    func menuControl(_ menuControl: PDEMenuControl, didTapSelectionAt index: Int)
}

open class PDEMenuControl: UIControl {
    
    public struct Config {
        public var itemSpacing: CGFloat
        public var indicatorSidePadding: CGFloat
        public var fillsAllItemsInBounds: Bool
        public var fillsItemsEqually: Bool
        public var generatesHapticFeedback: Bool
        public var labelAttributes: [NSAttributedString.Key : Any]
        public var indicatorFillColor: UIColor
        public var makesHighlightedTitleColorVibrant: Bool
        
        public struct DynamicIndicatorGradientConfig {
            
            public typealias GradientStartEndColorsFunction = ((_ value: CGFloat) -> (start: UIColor, end: UIColor))
            
            public enum GradientAxis {
                case horizontal, vertical
            }
            
            public var axis: GradientAxis
            public var startEndColors: GradientStartEndColorsFunction
            public var animationTimingFunction: CAMediaTimingFunction
            
            public init(axis: GradientAxis, animationTimingFunction: CAMediaTimingFunction, startEndColors: @escaping GradientStartEndColorsFunction) {
                self.axis = axis
                self.startEndColors = startEndColors
                self.animationTimingFunction = animationTimingFunction
            }
            
            public static let `default`: DynamicIndicatorGradientConfig = .init(axis: .vertical, animationTimingFunction: CAMediaTimingFunction(name: .easeOut)) { _ in (.gray, UIColor.darkGray) }
        }
        
        public var dynamicIndicatorGradientConfig: DynamicIndicatorGradientConfig?
        
        public init(itemSpacing: CGFloat, indicatorSidePadding: CGFloat, fillsAllItemsInBounds: Bool, fillsItemsEqually: Bool, generatesHapticFeedback: Bool, labelAttributes: [NSAttributedString.Key : Any], indicatorFillColor: UIColor, makesHighlightedTitleColorVibrant: Bool) {
            self.itemSpacing = itemSpacing
            self.indicatorSidePadding = indicatorSidePadding
            self.fillsAllItemsInBounds = fillsAllItemsInBounds
            self.fillsItemsEqually = fillsItemsEqually
            self.generatesHapticFeedback = generatesHapticFeedback
            self.labelAttributes = labelAttributes
            self.indicatorFillColor = indicatorFillColor
            self.dynamicIndicatorGradientConfig = nil
            self.makesHighlightedTitleColorVibrant = makesHighlightedTitleColorVibrant
        }
        
        public static let `default`: Config = .init(itemSpacing: 20, indicatorSidePadding: 12, fillsAllItemsInBounds: false, fillsItemsEqually: false, generatesHapticFeedback: true, labelAttributes: [:], indicatorFillColor: .init(red: 0.0, green: 0.5, blue: 1.0, alpha: 1.0), makesHighlightedTitleColorVibrant: false)
        
        //internal
        enum IndicatorFillMode {
            case singleColor, gradient
        }
        enum HighlightedTitleColorMode {
            case alwaysWhite, vibrantWithBakcgroundColor
        }
        
        var highlightedTitleColorMode: HighlightedTitleColorMode {
            return makesHighlightedTitleColorVibrant ? .vibrantWithBakcgroundColor : .alwaysWhite
        }
        
        var indicatorFillMode: IndicatorFillMode {
            if dynamicIndicatorGradientConfig != nil {
                return .gradient
            } else {
                return .singleColor
            }
        }
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
    //dynamic gradient
    private var indicatorDynamicGradientView: UIView?
    private var indicatorDynamicGradientLayer: CAGradientLayer?
    private var indicatorDynamicGradientMask: UIImageView?
    
    let config: Config
    
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
    
    public weak var delegate: PDEMenuControlDelegate?
    
    public var animatorParametersWithValue: ((_ oldValue: CGFloat, _ newValue: CGFloat) -> (duration: TimeInterval, timingParameters: UITimingCurveProvider)?)? = { old, new in
        let gap = new - old
        let leaps = abs(new - old) < 1 && round(new) != round(old)
        let duration: TimeInterval = {
            if leaps {
                return 0.22
            }
            switch abs(gap) {
            case 0..<0.2: return 0
            case ..<0.5: return 0.2
            default: return 0.4
            }
        }()
        if duration > 0 {
            return (duration, UISpringTimingParameters(dampingRatio: 1.0, initialVelocity: .zero))
        } else {
            return nil
        }
    }
    
    public var value: CGFloat = .init(IndexCache.initial.current) {
        didSet {
            let current = indexCache.current
            let nearest = Int(round(value))
            if config.generatesHapticFeedback, let latest = indexCache.latestNearest, latest != nearest {
                let haptic = UISelectionFeedbackGenerator()
                haptic.selectionChanged()
            }
            indexCache.updateLatestNearest(to: nearest)
            if abs(value - CGFloat(current)) >= 1 {
                indexCache.updateCurrent(to: nearest)
            }
            let currentIdxRect: CGRect = menuView.labelFrame(forIndex: indexCache.current) ?? .zero
            let nearestIdxRect: CGRect = menuView.labelFrame(forIndex: nearest) ?? .zero
            let indFr = indicatorFrameWidth(currentIndex: indexCache.current, rect: currentIdxRect, nearestIndex: nearest, rect: nearestIdxRect, elasticityMaxWidth: 30, value: value).insetBy(dx: -config.indicatorSidePadding, dy: 0)
            
            func updateFrames() {
                indicatorView.frame = indFr.intersection(CGRect(origin: .zero, size: scrollView.contentSize).insetBy(dx: -config.indicatorSidePadding, dy: 0)) //エッジからさらに奥にスクロールした際にインジケータが見切れないようにするため
                menuViewSnapshotMaskImageView.frame = indicatorView.frame
                let sideInset = (scrollView.bounds.width - indicatorView.bounds.width - scrollView.contentInset.right - scrollView.contentInset.left) / 2
                scrollView.scrollRectToVisible(indicatorView.frame.insetBy(dx: -sideInset, dy: 0), animated: false)
                updateIndicatorGradient() //TODO: incorrect calling due to updating not only frames
                updateHighlightedTitleColor() //TODO: incorrect calling due to updating not only frames
            }
            if let paramsFunc = animatorParametersWithValue, let params = paramsFunc(oldValue, value) {
                let animator = UIViewPropertyAnimator(duration: params.duration, timingParameters: params.timingParameters)
                animator.addAnimations {
                    updateFrames()
                }
                animator.startAnimation()
            } else {
                updateFrames()
            }
            sendActions(for: .valueChanged)
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
    
    override open func layoutSubviews() {
        super.layoutSubviews()
        updateMenuContentWidth()
        scrollView.frame = bounds.insetBy(dx: config.indicatorSidePadding, dy: 0)
        let indImage = UIImage.strechableRoundedRect(height: menuView.bounds.height)?.withRenderingMode(.alwaysTemplate)
        indicatorView.image = indImage
        if #available(iOS 11.0, *) {
            menuViewSnapshotMaskImageView.image = indicatorView.image
        } else {
            //DO NOTHING (snapshot views don't work correctly on iOS 10.X)
        }
        if config.indicatorFillMode == .gradient {
            indicatorDynamicGradientMask?.image = indicatorView.image
        }
        DispatchQueue.main.async {
            let latestValue = self.value
            self.value = latestValue
            self.updateOverlayIndicatorMask()
        }
        if let gradView = indicatorDynamicGradientView, let gradLayer = indicatorDynamicGradientLayer {
            gradLayer.frame = gradView.bounds
        }
    }
    
    private var maxIndex: CGFloat {
        return CGFloat(items.count)
    }
    
    public init(configure: Config) {
        self.config = configure
        super.init(frame: .zero)
        setUpViews()
        if let gradConfig = configure.dynamicIndicatorGradientConfig {
            setUpDynamicGradientView(config: gradConfig)
        }
        setUpConstraints()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setUpViews() {
        clipsToBounds = true
        scrollView.delegate = self
        addSubview(scrollView)
        menuView.labelAttributes = config.labelAttributes
        menuView.stackView.distribution = config.fillsItemsEqually ? .fillEqually : .fillProportionally
        menuView.stackView.spacing = config.itemSpacing
        scrollView.addSubview(menuView)
        scrollView.addSubview(indicatorBaseView)
        scrollView.clipsToBounds = false
        scrollView.showsHorizontalScrollIndicator = false
        indicatorView.tintColor = {
            switch config.indicatorFillMode {
            case .singleColor:  return config.indicatorFillColor
            case .gradient:     return .clear
            }
        }()
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
    
    private func setUpDynamicGradientView(config: Config.DynamicIndicatorGradientConfig) {
        let gradView = UIView()
        gradView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        gradView.frame = bounds
        let gradLayer = CAGradientLayer()
        gradLayer.fillMode = .removed
        gradLayer.locations = [NSNumber(value: 0), NSNumber(value: 1)]
        insertSubview(gradView, belowSubview: scrollView)
        let gradMask = UIImageView()
        insertSubview(gradMask, belowSubview: scrollView)
        gradView.layer.addSublayer(gradLayer)
        gradView.mask = gradMask
        indicatorDynamicGradientView = gradView
        indicatorDynamicGradientLayer = gradLayer
        indicatorDynamicGradientMask = gradMask
    }
    
    private func updateIndicatorGradient() {
        guard let layer = indicatorDynamicGradientLayer, let mask = indicatorDynamicGradientMask else {
            return
        }
        guard let fr = indicatorView.superview?.convert(indicatorView.frame, to: self) else {
            return
        }
        guard let cfg = config.dynamicIndicatorGradientConfig else {
            return
        }
        let (startClr, endClr) = cfg.startEndColors(value)
        mask.frame = fr
        let start = fr.minX / bounds.width
        let end = fr.maxX / bounds.width
        CATransaction.begin()
        CATransaction.setAnimationTimingFunction(cfg.animationTimingFunction)
        switch cfg.axis {
        case .horizontal:
            layer.startPoint = .init(x: start, y: 0)
            layer.endPoint = .init(x: end, y: 0)
        case .vertical:
            layer.startPoint = .init(x: 0, y: 0)
            layer.endPoint = .init(x: 0, y: 1)
        }
        
        layer.colors = [startClr.cgColor, endClr.cgColor]
        CATransaction.commit()
    }
    
    private func updateHighlightedTitleColor(animated: Bool = true) {
        let clr: UIColor = {
            switch config.highlightedTitleColorMode {
            case .alwaysWhite:
                return .white
            case .vibrantWithBakcgroundColor:
                let bgClr: UIColor = {
                    switch config.indicatorFillMode {
                    case .singleColor: return config.indicatorFillColor
                    case .gradient:    return config.dynamicIndicatorGradientConfig?.startEndColors(value).start ?? .white
                    }
                }()
                var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0
                bgClr.getHue(&h, saturation: &s, brightness: &b, alpha: nil)
                return UIColor(hue: h, saturation: min(1.0, s + 0.5), brightness: b - 0.4, alpha: 1)
            }
        }()
        if menuViewSnapshotImageView.tintColor == clr {
            return
        }
        let animator = UIViewPropertyAnimator(duration: 0.1, dampingRatio: 1.0) {
            self.menuViewSnapshotImageView.tintColor = clr
        }
        animator.startAnimation()
    }
    
    private func setUpConstraints() {
    }
    
    private func updateMenuContentWidth() {
        let estimatedWidth: CGFloat
        if config.fillsAllItemsInBounds {
            estimatedWidth = bounds.width - config.indicatorSidePadding * 2
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
        if let index = index {
            value = CGFloat(index)
            delegate?.menuControl(self, didTapSelectionAt: index)
        }
    }
    
}

extension PDEMenuControl: UIScrollViewDelegate {
    
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if config.dynamicIndicatorGradientConfig == nil {
            return
        }
        updateIndicatorGradient()
        updateHighlightedTitleColor()
    }
    
}

private class MenuLabelsView: UIView {
    
    let stackView = UIStackView()
    
    var items: [String] = [] {
        didSet {
            constructLabels()
        }
    }
    
    var labelAttributes: [NSAttributedString.Key : Any]?
    
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
            label.attributedText = .init(string: item, attributes: labelAttributes)
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
