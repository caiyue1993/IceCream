//
//  CatListView.swift
//  IceCream-SwiftUIExample
//
//  Created by Bo Frese on 30/6-20.
//  Copyright © 2020 i-con.dk. All rights reserved.
//

import SwiftUI

struct CatListView: View {
    @ObservedObject var cats = BindableResults(Cat.all)

    var body: some View {
        NavigationView {
            List {
                HStack {
                    Text("Number of cats: \(cats.results.count)").font(.caption)
                }
                ForEach(cats.results) { cat in
                    CatRowView(cat: cat )
                }.onDelete(perform: self.cats.delete )
                 
            }.navigationBarTitle("Cats")
             .navigationBarItems(trailing: EditButton() )
        }
    }
}

struct CatRowView: View {
    var cat: Cat
    var body: some View {
        HStack {
            Image(uiImage: UIImage(data: cat.avatar_data!)! )
                .resizable()
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.gray, lineWidth: 2))
                .frame(width: 50, height: 50)
            
            VStack(alignment: .leading) {
                Text("\(cat.name) (age: \(cat.age))").font(.headline)
                Text("Owner: \(cat.owner?.name ?? "none") ").font(.subheadline)
            }
        }
    }
}
 




// MARK: - PREVIEW
struct CatListView_Previews: PreviewProvider {
    static var previews: some View {
        CatListView()
    }
}

