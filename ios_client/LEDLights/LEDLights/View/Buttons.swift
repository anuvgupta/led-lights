//
//  Buttons
//  LEDLights
//
//  Created by Anuv Gupta on 7/2/19.
//  Copyright © 2019 Anuv Gupta. All rights reserved.
//

import UIKit
import Foundation

enum HandleEvent {
    case began, moved, ended
}
class HandleButton: UIButton {

    var parentColorView: PatternColorView?
    var touchHandler: ((PatternColorView?, HandleEvent, CGPoint) -> Void)?
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        let touch = touches.first
        let location = touch?.location(in: self.superview);
        if let loc = location {
            if let han = self.touchHandler {
                han(parentColorView, .began, loc)
            }
        }
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
        let touch = touches.first
        let location = touch?.location(in: self.superview);
        if let loc = location {
            if let han = self.touchHandler {
                han(parentColorView, .moved, loc)
            }
        }
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        let touch = touches.first
        let location = touch?.location(in: self.superview);
        if let loc = location {
            if let han = self.touchHandler {
                han(parentColorView, .ended, loc)
            }
        }
    }
    
}
