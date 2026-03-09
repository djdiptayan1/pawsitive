//
//  AppTab.swift
//  pawsitive-app
//
//  Created by Diptayan Jash on 09/03/26.
//

import Foundation
import SwiftUI

struct AppTab: Identifiable {

    let id = UUID()
    let title: String
    let systemImage: String
    let view: AnyView
}
