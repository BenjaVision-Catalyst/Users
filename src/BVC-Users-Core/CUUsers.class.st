"
Single entry point for the Catalyst Users API. On first access, AllUsers holds a shared temporary collection with admin (the super user) and unknownUser. It remains intact on subsequent access and reloads until tenant-owned storage replaces it. GemStone callers own repository transactions.
"
Class {
	#name : 'CUUsers',
	#superclass : 'Object',
	#classVars : [
		'AllUsers'
	],
	#category : 'BVC-Users-Core',
	#package : 'BVC-Users-Core'
}

{ #category : 'adding' }
CUUsers class >> addUser: aUser [
 ^ self allUsers add: aUser
]

{ #category : 'accessing' }
CUUsers class >> admin [
 ^ self allUsers detect: [:user | user name = 'admin']
]

{ #category : 'accessing' }
CUUsers class >> allUsers [
 "Create the temporary store and its two defaults only on first access."
 ^ AllUsers ifNil: [AllUsers := self newAllUsers]
]

{ #category : 'private' }
CUUsers class >> newAllUsers [
 ^ OrderedCollection
  with: (CUUser new name: 'admin'; isSuperUser: true; yourself)
  with: (CUUser new name: 'unknownUser'; isSuperUser: false; yourself)
]

{ #category : 'accessing' }
CUUsers class >> unknownUser [
 ^ self allUsers detect: [:user | user name = 'unknownUser']
]
