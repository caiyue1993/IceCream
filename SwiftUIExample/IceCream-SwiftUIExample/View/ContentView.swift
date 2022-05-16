//
//  ContentView.swift
//  IceCream-SwiftUIExample
//
//  Created by Bo Frese on 30/6-20.
//  Copyright © 2020 i-con.dk. All rights reserved.
//

import SwiftUI

/// A simple Tab View to contain the main UI Screens
struct ContentView: View {
    @State private var selection = 0
    
    var body: some View {
        TabView(selection: $selection){
            PersonListView()
                .tabItem {
                    VStack {
                        Image(systemName: "person.fill").font(.system(size: 16, weight: .regular))
                        Text("Owners")
                    }
                }
                .tag(0)
            
            CatListView()
                .tabItem {
                    VStack {
                        Image(systemName: "eye.fill").font(.system(size: 16, weight: .regular))
                        Text("Cats")
                    }
                }
                .tag(1)
            
            TestMenuView()
                .tabItem {
                    VStack {
                        Image(systemName: "hammer.fill").font(.system(size: 16, weight: .regular))
                        Text("Test!")
                    }
                }
                .tag(2)
            
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}


