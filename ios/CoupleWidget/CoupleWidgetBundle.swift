//
//  CoupleWidgetBundle.swift
//  CoupleWidget
//
//  Created by JUNGMIN on 3/23/26.
//

import WidgetKit
import SwiftUI

@main
struct CoupleWidgetBundle: WidgetBundle {
    var body: some Widget {
        CoupleWidget()
        CoupleWidgetControl()
        CoupleWidgetLiveActivity()
    }
}
