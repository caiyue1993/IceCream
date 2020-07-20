//
//  TestMenuView.swift
//  IceCream-SwiftUIExample
//
//  Created by Bo Frese on 30/6-20.
//  Copyright © 2020 i-con.dk. All rights reserved.
//

import SwiftUI

struct TestMenuView: View {
    @ObservedObject var persons        = BindableResults(Person.all)
    @ObservedObject var deletedPersons = BindableResults(Person.allDeleted)
    @ObservedObject var cats           = BindableResults(Cat.all)
    @ObservedObject var deletedCats    = BindableResults(Cat.allDeleted)

    let app = UIApplication.shared.delegate as! AppDelegate

    func refresh() {
        // Just an experiment - Should not be needed, as the results should automatically update
        persons.refresh()
        deletedPersons.refresh()
        cats.refresh()
        deletedCats.refresh()
    }
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Statistics:").font(.headline) ) {
                    Text("Owners: \(persons.results.count) (+ \(deletedPersons.results.count) deleted)")
                    Text("Cats: \(cats.results.count) (+ \(deletedCats.results.count) deleted)")
                }
                
                Section(header: Text("Test Data:").font(.headline) ) {
                    ButtonView(text: "Add 10 New Owners with Cats", imageSystemName:"person.badge.plus") {
                        TestData.addRandomPeople(10, maxCats: 3)
                    }
                    ButtonView(text: "Add 100 New Owners with Cats", imageSystemName:"person.badge.plus") {
                        TestData.addRandomPeople(100, maxCats: 3)
                    }
                    ButtonView(text: "REMOVE 10 Owners with their Cats", imageSystemName:"person.badge.minus", color: .red) {
                        TestData.removeRandomPeople(10)
                    }
                    ButtonView(text: "REMOVE 100 Owners with their Cats", imageSystemName:"person.badge.minus", color: .red) {
                        TestData.removeRandomPeople(100)
                    }
                    ButtonView(text: "REMOVE ALL Owners with NO Cats", imageSystemName:"person.badge.minus", color: .red) {
                        TestData.removeOwnersWithNoCats()
                    }
                    ButtonView(text: "REMOVE ALL Cats with NO Owner", imageSystemName:"person.badge.minus", color: .red) {
                        TestData.removeCatsWithNoOwners()
                    }
                }
                
                Section(header: Text("IceCream:").font(.headline) ) {
                    ButtonView(text: "Pull", imageSystemName:"arrow.down") {
                        self.app.syncEngine?.pull()
                    }
                    ButtonView(text: "Push All", imageSystemName:"arrow.up") {
                        self.app.syncEngine?.pull()
                    }

                }
                
            }.navigationBarTitle("Test Lab")
             .navigationBarItems(trailing: refreshButton )
        }
    }
    var refreshButton: some View {
        Button(action: { self.refresh() } ) {
            Image(systemName: "goforward").font(.system(size: 16, weight: .regular))
        }
    }
}

struct ButtonView: View {
    var text: String
    var imageSystemName: String
    var color: Color = Color.accentColor
    var action: () -> Void
    var body: some View {
        Button(action: { self.action() } ) {
                HStack {
                    Image(systemName: imageSystemName).font(.system(size: 16, weight: .regular))
                    Text(text)
                }.foregroundColor(color)
        }.buttonStyle(BorderlessButtonStyle())
    }
}

struct TestMenuView_Previews: PreviewProvider {
    static var previews: some View {
        TestMenuView()
    }
}
