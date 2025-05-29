//
//  NGDigitalApp.swift
//  NGDigital
//
//  Created by Marlon on 5/26/25.
//

import SwiftUI

@main
struct NGDigitalApp: App {
    @StateObject var gk = GateKeeper()
    init() {
            let appearance = UITabBarAppearance()
            appearance.configureWithDefaultBackground()
            
            // 👇 Create a glassy blur effect
            let blurEffect = UIBlurEffect(style: .systemUltraThinMaterial)
            let blurView = UIVisualEffectView(effect: blurEffect)
            blurView.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 80)
            
            // 🔹 Set background color with transparency (optional, helps on lighter blur styles)
            appearance.backgroundColor = UIColor.clear.withAlphaComponent(0.3)
            
            // 🔹 Use backgroundEffect to assign the blur
            appearance.backgroundEffect = blurEffect
            
            // Icon & title colors
            appearance.stackedLayoutAppearance.selected.iconColor = UIColor.white
            appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor.white]
            
            appearance.stackedLayoutAppearance.normal.iconColor = UIColor.lightGray
            appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.lightGray]

            // Apply the appearance
            let tabBar = UITabBar.appearance()
            tabBar.standardAppearance = appearance
            if #available(iOS 15.0, *) {
                tabBar.scrollEdgeAppearance = appearance
            }
        }
    var body: some Scene {
        WindowGroup {
            if gk.appSettings.authToken.isEmpty{
                LoginView()
            }else{
            ContentView().environmentObject(gk)
            }
            
        }
    }
}
