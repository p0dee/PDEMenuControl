//
//  Utils.swift
//  PDEMenuBar
//
//  Created by Takeshi Tanaka on 2019/03/05.
//  Copyright © 2019 p0dee. All rights reserved.
//

import UIKit

extension UIImage {
    
    static func strechableRoundedRect(height: CGFloat) -> UIImage? {
        let size = CGSize(width: height + 1, height: height)
        UIGraphicsBeginImageContextWithOptions(size, false, UIScreen.main.scale)
        guard let ctx = UIGraphicsGetCurrentContext() else {
            return nil
        }
        let path = UIBezierPath(roundedRect: .init(origin: .zero, size: size), cornerRadius: height / 2)
        ctx.addPath(path.cgPath)
        UIColor.black.setFill()
        ctx.drawPath(using: .fill)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        let inset = height / 2
        return image?.resizableImage(withCapInsets: .init(top: 0, left: inset, bottom: 0, right: inset))
    }
    
}

extension UIView {
   
    func snapshot() -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(bounds.size, false, UIScreen.main.scale)
        let image: UIImage?
        if drawHierarchy(in: self.bounds, afterScreenUpdates: false) {
            image = UIGraphicsGetImageFromCurrentImageContext()
        } else {
            image = nil
        }
        UIGraphicsEndImageContext()
        return image
    }
    
}
