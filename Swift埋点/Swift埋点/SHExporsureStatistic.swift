//
//  SHExporsureStatistic.swift
//  Swift埋点
//
//  Created by Demon on 2019/12/2.
//  Copyright © 2019 Demon. All rights reserved.
//

import Foundation
import UIKit

extension NSObject {
    //方法替换
    fileprivate static func swizzleMethod(target: NSObject.Type, _ left: Selector, _ right: Selector) {
        guard let originalMethod = class_getInstanceMethod(target, left), let swizzledMethod = class_getInstanceMethod(target, right) else { return }
        let didAddMethod = class_addMethod(target, left, method_getImplementation(swizzledMethod), method_getTypeEncoding(swizzledMethod))
        if didAddMethod {
            class_replaceMethod(target, right, method_getImplementation(originalMethod), method_getTypeEncoding(originalMethod))
        } else {
            method_exchangeImplementations(originalMethod, swizzledMethod);
        }
    }
}


private var SH_VIEWVISIBLE = 0
private var SH_TRACKHASPERFORM = 0
private var SH_TRACKMODEL = 0
private var SH_EXPORSURE_PROTOCOL = 0
class SHExporsureStatistic {
    
    static func registerExporsure() {
        NSObject.swizzleMethod(target: UIScrollView.self, NSSelectorFromString("_scrollViewDidEndDeceleratingForDelegate"), #selector(UIScrollView.sh_scrollViewDidEndDeceleratingForDelegate))
        NSObject.swizzleMethod(target: UIScrollView.self, NSSelectorFromString("_scrollViewDidEndDraggingForDelegateWithDeceleration:"), #selector(UIScrollView.sh_scrollViewDidEndDraggingForDelegateWithDeceleration(_:)))
        NSObject.swizzleMethod(target: UIScrollView.self, NSSelectorFromString("_delegateScrollViewAnimationEnded"), #selector(UIScrollView.sh_delegateScrollViewAnimationEnded))
        NSObject.swizzleMethod(target: UIView.self, #selector(setter: UIView.isHidden), #selector(UIView.sh_isHidden(_:)))
//        NSObject.swizzleMethod(target: UIView.self, #selector(UIView.didMoveToWindow), #selector(UIView.sh_didMoveToWindow))
        NSObject.swizzleMethod(target: UIView.self, #selector(setter: UIView.frame), #selector(UIView.sh_frame(_:)))
        NSObject.swizzleMethod(target: UIView.self, #selector(UIView.addSubview(_:)), #selector(UIView.sh_addSubView(_:)))
        NSObject.swizzleMethod(target: UIViewController.self, #selector(UIViewController.viewDidLoad), #selector(UIViewController.sh_viewDidLoad))
    }
}

extension UIView {
    
    var sh_viewVisible: Bool {
        get {
            guard let result = objc_getAssociatedObject(self, &SH_VIEWVISIBLE) as? Bool else { return false }
            return result
        }
        set {
            if !self.sh_viewVisible && newValue {
                if let trackModel = self.sh_trackModel {
                    print(trackModel.description)
                }
            }
            objc_setAssociatedObject(self, &SH_VIEWVISIBLE, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_ASSIGN)
        }
    }
    
    private weak var sh_observe: SHExporsureStatisticProtocol? {
        get {
            return objc_getAssociatedObject(self, &SH_EXPORSURE_PROTOCOL) as? SHExporsureStatisticProtocol
        }
        set {
            objc_setAssociatedObject(self, &SH_EXPORSURE_PROTOCOL, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_ASSIGN)
        }
    }
    
    fileprivate var sh_track_has_perform: Bool {
        get {
            guard let result = objc_getAssociatedObject(self, &SH_TRACKHASPERFORM) as? Bool else { return false }
            return result
        }
        set {
            objc_setAssociatedObject(self, &SH_TRACKHASPERFORM, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_ASSIGN)
        }
    }
    
    fileprivate var sh_trackModel: SHViewTrackModel? {
        get {
            return objc_getAssociatedObject(self, &SH_TRACKMODEL) as? SHViewTrackModel
        }
        set {
            objc_setAssociatedObject(self, &SH_TRACKMODEL, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    func sh_trackTag(observe _observe: SHExporsureStatisticProtocol, identifier _identifier: String, param _param: [String: String]) {
        let model = SHViewTrackModel(_identifier, _param)
        if model.isEqual(self.sh_trackModel) { return }
        self.sh_observe = _observe
        self.sh_trackModel = model
        self.sh_viewVisible = false
        self.sh_updateViewVisible()
    }
    
    @objc fileprivate func sh_didMoveToWindow() {
        self.sh_didMoveToWindow()
        self.sh_updateViewVisible()
    }
    
    @objc fileprivate func sh_addSubView(_ subView: UIView) {
        self.sh_addSubView(subView)
        self.sh_updateViewVisible()
    }
    
    @objc fileprivate func sh_frame(_ frame: CGRect) {
        self.sh_frame(frame)
        self.sh_updateViewVisible()
    }
    
    @objc fileprivate func sh_isHidden(_ hidden: Bool) {
        self.sh_isHidden(hidden)
        self.sh_updateViewVisible()
    }
    
    fileprivate func sh_updateViewVisible() {
        if let obs = self.getCurrentVC(), obs.sh_viewVisibleAuth() {
                self.sh_checkoutAuth()
        }
    }
    
    private func sh_checkoutAuth() {
        if self.sh_track_has_perform { return }
        self.sh_track_has_perform = true
        if self.sh_viewVisibleAuth() {
            self.perform(#selector(sh_calculateViewVisible), with: nil, afterDelay: 0, inModes: [RunLoop.Mode.default])
        }
        for subView in self.subviews {
            subView.sh_checkoutAuth()
        }
    }
    
    @objc private func sh_calculateViewVisible() {
        self.sh_track_has_perform = false
//        self.sh_viewVisible = self.sh_isDisplayInScreen()
        self.sh_isDisplayInScreen()
    }
    
    @discardableResult
    func sh_isDisplayInScreen() -> Bool {
        if self.isHidden || self.alpha < 0.01 || self.window == nil {
            return false
        }
        
        //iOS11 以下 特殊处理 UITableViewWrapperView 需要使用的supview
        //UITableviewWrapperview 的大小为tableView 在屏幕中出现第一个完整的屏幕大小的视图
        //并且会因为contentOffset的改变而改变，所以UITableviewWrapperview会滑出屏幕，这样因为self.superview.hlj_viewVisible 这个条件导致 他下面的子试图都被判定为不可见，因此将cell的父试图为UITableViewWrapperView的时候，使用tableView 计算
        var view = self
        if String(describing: type(of: view)) == "UITableViewWrapperView" {
            if let sView = self.superview {
                view = sView
            }
        }
        
        guard let delegate = UIApplication.shared.delegate else { return false }
        guard let wd = delegate.window else { return false }
        let rect = view.convert(view.bounds, to: wd)
        let screenRect = UIScreen.main.bounds
        let intersectionRect = screenRect.intersects(rect)
//        screenRect.intersects(rect) 给出矩形大小
        if intersectionRect {
            self.sh_viewVisible = intersectionRect // 做的是单次曝光
        }
        return intersectionRect
    }
    
    func getCurrentVC() -> SHExporsureStatisticProtocol? {
        var nxt = self.next
        while nxt != nil {
            if nxt is UIViewController {
                return nxt as? UIViewController
            }
            nxt = nxt?.next
        }
        return nil
    }
}

extension UIScrollView {
    
    @objc fileprivate func sh_scrollViewDidEndDeceleratingForDelegate() {
        self.sh_scrollViewDidEndDeceleratingForDelegate()
        self.sh_updateViewVisible()
        print("自动停止")
    }
    
    @objc fileprivate func sh_scrollViewDidEndDraggingForDelegateWithDeceleration(_ object: Bool) {
        self.sh_scrollViewDidEndDraggingForDelegateWithDeceleration(object)
        self.sh_updateViewVisible()
        print("拖拽停止")
    }
    
    @objc fileprivate func sh_delegateScrollViewAnimationEnded() {
        self.sh_delegateScrollViewAnimationEnded()
        self.sh_updateViewVisible()
        print("动画停止")
    }
}

@objc protocol SHExporsureStatisticProtocol {
    func sh_viewVisibleAuth() -> Bool
}

private var SH_VIEWDIDLOAD_TIMESTAMP = 0

extension UIViewController: SHExporsureStatisticProtocol {
    
    private var timestamp: String {
        get {
            return (objc_getAssociatedObject(self, &SH_VIEWDIDLOAD_TIMESTAMP) as? String) ?? ""
        }
        set {
            objc_setAssociatedObject(self, &SH_VIEWDIDLOAD_TIMESTAMP, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_COPY_NONATOMIC)
        }
    }
    
    func sh_viewVisibleAuth() -> Bool {
        return false
    }
    
    @objc func sh_viewDidLoad() {
        self.sh_viewDidLoad()
        self.timestamp = Date().milliStamp
    }
    
    func uniqueId() -> String {
        return String(describing: type(of: self)) + "." + "\(self.timestamp)"
    }
}

extension UIView: SHExporsureStatisticProtocol {
    
    func sh_viewVisibleAuth() -> Bool {
        return true
    }
}

extension Date {
 
    /// 获取当前 毫秒级 时间戳 - 13位
    fileprivate var milliStamp : String {
        let timeInterval: TimeInterval = self.timeIntervalSince1970
        let millisecond = CLongLong(round(timeInterval*1000))
        return "\(millisecond)"
    }
}

public class SHViewTrackModel: NSObject {
    
    public var identifier: String
    public var param: [String: String]
    
    init(_ identifier: String, _ param: [String: String]) {
        self.identifier = identifier
        self.param = param
        super.init()
    }
    
    override public func isEqual(_ object: Any?) -> Bool {
        guard let obj = object as? SHViewTrackModel else { return false }
        if self.identifier == obj.identifier && self.param == obj.param {
            return true
        }
        return false
    }
    
    public override var description: String {
        return "\(self.identifier)---\(self.param)"
    }
}
