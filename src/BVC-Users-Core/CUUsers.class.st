"
Single entry point for the Catalyst Users API. AllUsers holds the shared temporary user collection until tenant-owned storage replaces it. Collection initialization is lazy and never resets existing entries. GemStone callers own their repository transactions.
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
CUUsers class >> allUsers [
 "Shared temporary storage until users belong to tenants."
 ^ AllUsers ifNil: [AllUsers := OrderedCollection new]
]
