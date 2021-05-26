//
//  PersonView.swift
//  IceCream-SwiftUIExample
//
//  Created by Bo Frese on 9/7-20.
//  Copyright © 2020 i-con.dk. All rights reserved.
//

import SwiftUI

struct PersonView: View {
    @ObservedObject var person: Person
    @ObservedObject var cats: BindableResults<Cat>

    init(person: Person) {
        self.person = person
        self.cats = person.observableListOfCats()
    }
    
    var body: some View {
        VStack(alignment: .center) {
            Text(person.name).font(.largeTitle)
            Text("Owns \(cats.results.count) Cats").font(.subheadline)
            List {
                ForEach(cats.results) { cat in
                    CatRowView(cat: cat)
                }.onDelete(perform: cats.delete )
            
                ButtonView(text: "Add a Cat", imageSystemName:"plus.app.fill") {
                    let cat = TestData.makeRandomCat(owner: self.person )
                    cat.save()
                }
            }.navigationBarItems(trailing: EditButton() )
        }
    }
}

// MARK: - PREVIEW

struct PersonView_Previews: PreviewProvider {
    static let person = TestData.makeRandomPerson()
    static var previews: some View {
        PersonView(person: person)
    }
}
