//
//  PersonListView.swift
//  IceCream-SwiftUIExample
//
//  Created by Bo Frese on 30/6-20.
//  Copyright © 2020 i-con.dk. All rights reserved.
//

import SwiftUI
import RealmSwift

struct PersonListView: View {
    @ObservedObject var persons = BindableResults(Person.all)
    
    var body: some View {
        NavigationView {
            List {
                Text("Number of owners: \(persons.results.count)").font(.caption)
                ForEach(persons.results) { person in
                    person.unfrozen().map { observablePerson in  // The swiftUI version of "if let"  :-)
                        NavigationLink(destination: PersonView(person: observablePerson)) {
                            PersonRowView(person: person)
                        }
                    }
                    
                }.onDelete(perform: self.persons.delete )
                Button(action: { TestData.addRandomPeople(1, minCats: 1, maxCats: 3) } ) {
                    HStack {
                        Text("Add new Owner with Pets")
                        addPersonImage
                    }
                }.buttonStyle(BorderlessButtonStyle())
            }.navigationBarTitle("Pet Owners")
            .navigationBarItems(
                leading:  Button(action: { TestData.addRandomPeople(1)  } ) { addPersonImage },
                trailing: EditButton()
            )
        }
    }
    var addPersonImage: some View {
        Image(systemName: "person.badge.plus").font(.system(size: 16, weight: .regular))
    }

}

struct PersonRowView: View {
    var person: Person
    var body: some View {
        VStack(alignment: .leading) {
            Text(person.name).font(.headline)
        }
    }
}


// MARK: - PREVIEW
struct PersonListView_Previews: PreviewProvider {
    static var previews: some View {
        PersonListView()
    }
}

