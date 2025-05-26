//
//  HomeHub.swift
//  NGDigital
//
//  Created by Marlon on 5/26/25.
//

import SwiftUI

struct HomeHub: View {
    @State var selection:Int = 0
    @EnvironmentObject var gk:GateKeeper
    @State private var selectedTab: Int = 0

        var body: some View {
            ZStack(alignment: .bottom) {
                Group {
                    switch selectedTab {
                    case 0:
                        ZStack{Color.blue.ignoresSafeArea()
                            SocialView()
                        }
                    case 1:
                        Color.purple.ignoresSafeArea()
                    case 2:
                        Color.orange.ignoresSafeArea()
                    case 3:
                        Color.blue.ignoresSafeArea()
                    default:
                        Color.black.ignoresSafeArea()
                    }
                }

                ParamountPlusTabBarView(
                    selectedTab: $selectedTab,
                    profileImageURL: "https://platform.polygon.com/wp-content/uploads/sites/2/chorus/uploads/chorus_asset/file/25543078/TDW_14349_R.jpg?quality=90&strip=all&crop=0%2C0%2C100%2C100&w=2400"
                )
            }
        }
//    var body: some View {
//
//        TabView(selection: $selection) {
//            SocialView().tabItem {
//                Image(systemName: "house")
//                      Text("Home") }.tag(1)
//
//            Text("Tab Content 2..I have no idea what this will be but at somepoint after I finish the first tab I can move on to this one.").tabItem { Text("Tab Label 2") }.tag(2)
//
//            Text("This will be the tab that is the user tab, profile and all kind of user settings will go here, at least I know this much lol.").tabItem {
//                Image(systemName: "person").foregroundColor(.white)
//                Text("Me") }.tag(3)
//        }
//    }
}

struct HomeHub_Previews: PreviewProvider {
    static var previews: some View {
        HomeHub()
    }
}

