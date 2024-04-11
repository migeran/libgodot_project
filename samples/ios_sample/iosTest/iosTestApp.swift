//
//  iosTestApp.swift
//  iosTest
//
//  Created by Koncz Gábor on 2024. 03. 11..
//

import SwiftUI

@main
struct iosTestApp: App {
    
    init() {
        setenv("MVK_CONFIG_FULL_IMAGE_VIEW_SWIZZLE", "1", 1);
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
