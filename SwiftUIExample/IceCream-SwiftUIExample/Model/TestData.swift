//
//  TestData.swift
//  IceCream-SwiftUIExample
//
//  Created by Bo Frese on 8/7-20.
//  Copyright © 2020 i-con.dk. All rights reserved.
//

import Foundation
import IceCream
import UIKit

/// This is a collection of convenience methods to generate test data for the App
final class TestData {
    
    /// Add a given number of people with cats to Realm
    static func addRandomPeople(_ numberOfPeople: Int = 1, minCats: Int = 0, maxCats: Int = 0) {
        background() {          // Run this in the backround so we don't block the main / UI thread
            realmWrite { r in   // Make all writes in the same Realm transaction
                for _ in 0..<numberOfPeople {
                    let person = makeRandomPerson(cats: Int.random(in: minCats ... maxCats))
                    person.save()
                }
            }
        }
    }
    
    /// Remove a given number of people with cats from Realm
    static func removeRandomPeople(_ numberOfPeople: Int = 0) {
        let people = Person.all
        let numToDelete = min( people.count, numberOfPeople)
        background() {          // Run this in the backround so we don't block the main / UI thread
            realmWrite { r in   // Make all writes in the same Realm transaction
                for _ in 0..<numToDelete {
                    if let person = people.first {
                        person.cascadingDelete()
                    }
                }
            }
        }
    }
    
    /// Return a randomly created person with a given number of cats
    static func makeRandomPerson(cats number_of_cats: Int = 0) -> Person {
        let person    = Person()
        let firstname = FIRST_NAMES.randomElement() ?? "John"
        let lastname  = LAST_NAMES.randomElement()  ?? "Doe"
        person.name   = "\(firstname) \(lastname)"
        
        for _ in 0..<number_of_cats {
            let cat = makeRandomCat(owner: person)
            cat.save()
        }
        return person
    }

    static func makeRandomCat(owner: Person?) -> Cat {
        let cat  = Cat()
        cat.name = CAT_NAMES.randomElement() ?? "Miv"
        cat.age = Int.random(in: 1 ..< 15)
        let image_name = CAT_PHOTO_NAMES.randomElement() ?? "cat1"
        let data = UIImage(named: image_name)!.jpegData(compressionQuality: 1.0)
        cat.avatar = CreamAsset.create(object: cat, propName: Cat.AVATAR_KEY, data: data!)
        if let person = owner {
            person.addCat(cat: cat)
        }
        return cat
    }
    
    static func removeOwnersWithNoCats() {
        let people = Person.allWithNoCats()
        background() {
            realmWrite { r in  // Make all writes in the same Realm transaction
                for person in people {
                    person.cascadingDelete()
                }
            }
        }
    }
    static func removeCatsWithNoOwners() {
        let cats = Cat.allWithNoOwner()
        let num_to_delete = cats.count
        background() {
            realmWrite { r in  // Make all writes in the same Realm transaction
                for _ in 0 ... num_to_delete {
                    if var cat = cats.first {
                        cat.delete()
                    }
                }
            }
        }
    }

 

}

// MARK: - Helper methods

// From https://stackoverflow.com/a/40997652/7216150
/// Run some block of code on the backround queue, with an optional completion block to run in the main thread when finished.
func background(delay: Double = 0.0, background: (()->Void)? = nil, completion: (() -> Void)? = nil) {
    DispatchQueue.global(qos: .background).async {
        background?()
        if let completion = completion {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: {
                completion()
            })
        }
    }
}


// MARK: - Example Test Data

let FIRST_NAMES = [
    "Liam", "Noah", "William", "James", "Oliver", "Benjamin", "Elijah",
    "Lucas", "Mason", "Logan", "Alexander", "Ethan", "Jacob", "Michael",
    "Daniel", "Henry", "Jackson", "Sebastian", "Aiden", "Matthew",
    "Samuel", "David", "Joseph", "Carter", "Owen", "Wyatt", "John",
    "Jack", "Luke", "Jayden", "Dylan", "Grayson", "Levi", "Isaac",
    "Gabriel", "Julian", "Mateo", "Anthony", "Jaxon", "Lincoln", "Joshua",
    "Christopher", "Andrew", "Theodore", "Caleb", "Ryan", "Asher",
    "Nathan", "Thomas", "Leo", "Isaiah", "Charles", "Josiah", "Hudson",
    "Christian", "Hunter", "Connor", "Eli", "Ezra", "Aaron", "Landon",
    "Adrian", "Jonathan", "Nolan", "Jeremiah", "Easton", "Elias",
    "Colton", "Cameron", "Carson", "Robert", "Angel", "Maverick",
    "Nicholas", "Dominic", "Jaxson", "Greyson", "Adam", "Ian", "Austin",
    "Santiago", "Jordan", "Cooper", "Brayden", "Roman", "Evan", "Ezekiel",
    "Xavier", "Jose", "Jace", "Jameson", "Leonardo", "Bryson", "Axel",
    "Everett", "Parker", "Kayden", "Miles", "Sawyer",
    "Emma", "Olivia", "Ava", "Isabella", "Sophia", "Charlotte", "Mia",
    "Amelia", "Harper", "Evelyn", "Abigail", "Emily", "Elizabeth",
    "Mila", "Ella", "Avery", "Sofia", "Camila", "Aria", "Scarlett",
    "Victoria", "Madison", "Luna", "Grace", "Chloe", "Penelope", "Layla",
    "Riley", "Zoey", "Nora", "Lily", "Eleanor", "Hannah", "Lillian",
    "Addison", "Aubrey", "Ellie", "Stella", "Natalie", "Zoe", "Leah",
    "Hazel", "Violet", "Aurora", "Savannah", "Audrey", "Brooklyn",
    "Bella", "Claire", "Skylar", "Lucy", "Paisley", "Everly", "Anna",
    "Caroline", "Nova", "Genesis", "Emilia", "Kennedy", "Samantha",
    "Maya", "Willow", "Kinsley", "Naomi", "Aaliyah", "Elena", "Sarah",
    "Ariana", "Allison", "Gabriella", "Alice", "Madelyn", "Cora", "Ruby",
    "Eva", "Serenity", "Autumn", "Adeline", "Hailey", "Gianna",
    "Valentina", "Isla", "Eliana", "Quinn", "Nevaeh", "Ivy", "Sadie",
    "Piper", "Lydia", "Alexa", "Josephine", "Emery", "Julia", "Delilah",
    "Arianna", "Vivian", "Kaylee", "Sophie", "Brielle",
]

let LAST_NAMES = [
    "Smith", "Martinez", "Hernandez", "Lopez", "Gonzalez", "Wilson",
    "Anderson", "Thomas", "Taylor", "Moore", "Jackson", "Johnson",
    "Martin", "Lee", "Perez", "Thompson", "White", "Harris", "Sanchez",
    "Clark", "Ramirez", "Lewis", "Williams", "Robinson", "Walker",
    "Young", "Allen", "King", "Wright", "Scott", "Torres", "Nguyen",
    "Hill", "Brown", "Flores", "Green", "Adams", "Nelson", "Baker",
    "Hall", "Rivera", "Campbell", "Mitchell", "Carter", "Jones",
    "Roberts", "Garcia", "Miller", "Davis", "Rodriguez"
]

let CAT_NAMES = [
    "Luna", "Bella", "Lily", "Lucy", "Kitty", "Callie", "Nala", "Zoe",
    "Chloe", "Sophie", "Daisy", "Stella", "Cleo", "Lola", "Gracie",
    "Mia", "Molly", "Penny", "Willow", "Olive", "Kiki", "Pepper",
    "Princess", "Rosie", "Ellie", "Maggie", "Coco", "Piper", "Lulu",
    "Sadie", "Izzy", "Ginger", "Abby", "Sasha", "Pumpkin", "Ruby",
    "Shadow", "Phoebe", "Millie", "Roxy", "Minnie", "Baby", "Fiona",
    "Jasmine", "Penelope", "Sassy", "Charlie", "Oreo", "Mittens", "Boo"
]

/// List of random cat photos.
/// All Photos are from Unsplash: https://unsplash.com/s/photos/cat
let CAT_PHOTO_NAMES = Array(1...11).map { "cat\($0)" }
