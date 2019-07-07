//
//  PatternView.swift
//  LEDLights
//
//  Created by Anuv Gupta on 6/21/19.
//  Copyright © 2019 Anuv Gupta. All rights reserved.
//

import UIKit
import Foundation

class PatternView: UIView {
    
    // instance data
    public var data: Pattern?
    let deleteButtonWidth: CGFloat = 90
    var shouldSetupConstraints: Bool = true
    // ui elements
    public let buttonView: UIButton = UIButton()
    public let deleteView: UIButton = UIButton()
    var buttonViewLeftConstraint: NSLayoutConstraint?
    var buttonViewRightConstraint: NSLayoutConstraint?
    
    // init setup
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        deleteView.configureForAutoLayout()
        deleteView.contentHorizontalAlignment = .center
        deleteView.setTitle("Delete", for: .normal)
        deleteView.setTitleColor(UIColor.white, for: .normal)
        if let title = deleteView.titleLabel {
            title.font = UIFont.systemFont(ofSize: 16, weight: .light)
        }
        deleteView.setBackgroundColor(color: deleteRed, forState: .normal)
        self.addSubview(deleteView)
        
        buttonView.configureForAutoLayout()
        buttonView.contentHorizontalAlignment = .left
        buttonView.setTitleColor(UIColor.black, for: .normal)
        if let title = buttonView.titleLabel {
            title.font = UIFont.systemFont(ofSize: 20, weight: .light)
        }
        buttonView.titleEdgeInsets.left -= 20.0
        if let image = UIImage(named: "next_b.png") {
            buttonView.setImage(image.alpha(0.5), for: .normal)
        }
        buttonView.imageView?.contentMode = .scaleAspectFit
        buttonView.imageEdgeInsets = UIEdgeInsets(top: 24.0, left: frame.size.width - 40, bottom: 24.0, right: 15);
        buttonView.setBackgroundColor(color: UIColor.white, forState: .normal)
        buttonView.setBackgroundColor(color: UIColor(red: 0.92, green: 0.92, blue: 0.92, alpha: 1), forState: .highlighted)
        self.addSubview(buttonView)
    }
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    // constraints update
    override func updateConstraints() {
        if shouldSetupConstraints {
            deleteView.autoMatch(.height, to: .height, of: self)
            deleteView.autoSetDimension(.width, toSize: deleteButtonWidth)
            deleteView.autoPinEdge(.top, to: .top, of: self)
            deleteView.autoPinEdge(.bottom, to: .bottom, of: self)
            deleteView.autoPinEdge(.left, to: .left, of: self)
            
            buttonView.autoMatch(.height, to: .height, of: self)
            buttonView.autoPinEdge(.top, to: .top, of: self)
            buttonView.autoPinEdge(.bottom, to: .bottom, of: self)
            buttonViewRightConstraint = buttonView.autoPinEdge(.right, to: .right, of: self, withOffset: 0)
            buttonViewLeftConstraint = buttonView.autoPinEdge(.left, to: .left, of: self, withOffset: 0)
            
            shouldSetupConstraints = false
        }
        super.updateConstraints()
    }
    // add bottom border to view
    func addBorder() {
        let border = CALayer()
        border.borderColor = UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1).cgColor
        border.frame = CGRect(x: 0, y: self.frame.size.height - 1, width: self.frame.size.width, height: 1.0)
        border.borderWidth = 1.0
        self.layer.addSublayer(border)
        self.layer.masksToBounds = true
    }
    // load data into pattern
    func load(data: Pattern) {
        self.data = data
        buttonView.setTitle(data.name, for: .normal)
    }
    // set button frame
    func setFrame(frame: CGRect) {
        buttonView.frame = frame
    }
    // get id
    func getID() -> String {
        if let d = self.data {
            return d.id
        }
        return ""
    }
    // get name
    func getName() -> String {
        if let d = self.data {
            return d.name
        }
        return ""
    }
    // show/hide delete button
    func showDeleteView() {
        setButtonViewLeftOffset(deleteButtonWidth)
    }
    func hideDeleteView() {
        setButtonViewLeftOffset(0)
    }
    // shift main button view
    private func setButtonViewLeftOffset(_ left: CGFloat) {
        if let leftConstraint = buttonViewLeftConstraint {
            if let rightConstraint = buttonViewRightConstraint {
                UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0, animations: {
                    leftConstraint.constant = left
                    rightConstraint.constant = -1 * left
                    self.buttonView.layoutIfNeeded()
                })
            }
        }
    }
}
