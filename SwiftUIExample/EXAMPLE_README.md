# SwiftUI based IceCream Example

The IceCream-SwiftUIExample App was created with these goals in mind:

- It should serve as a useful **simple** playground to use as base for experimentation, stress testing, hunting down bugs, error handling etc. rather than using your complex real life app for that. So the functionality and UI are kept fairly basic

- It should serve as a relatively 'complete' example, that allows you to see how it all works together. Possibly to serve as a 'blueprint' on a SwiftUI + Realm + IceCream app. 

- It should have as few dependencies as possible. Ideally only Realm and IceCream - to keep it simple, and not promote the use of any specific library or framework..


## Install dependencies:

The Example app uses Swift Package Manager to intall IceCream and Realm. So it should all work automagically. It uses the IceCream in the parrent directory, to make it easy to use for experimentation on the IceCream core itself.

## Update Team and Bundle ID

Before you are able to compile and run this on your own maching you need to :

In the 'TARGETS: IceCream_Example' 
- update the 'Team' field to your own team
- Update the 'Bundle Identifier' to your own unique Bundle ID for the Example_app

## TODO:

- There should be more error handling. Hooking into, displaying, and handeling errors that occur in IceCream / CloudKit



