"
Inert createUser: request for the exact named Users service. Returns its ordinary CUUser result. Requires a repository transaction on GemStone and never authorizes automatic replay.
"
Class {
	#name : 'CUCreateUserWorkUnit',
	#superclass : 'CUUsersWorkUnit',
	#instVars : [
		'user'
	],
	#category : 'BVC-Users-Runtime',
	#package : 'BVC-Users-Runtime'
}

{ #category : 'contracts' }
CUCreateUserWorkUnit class >> allowsConflictReplay [
 ^ false
]

{ #category : 'contracts' }
CUCreateUserWorkUnit class >> requiresTransaction [
 ^ true
]

{ #category : 'instance creation' }
CUCreateUserWorkUnit class >> user: aUser [
 ^ self new user: aUser; yourself
]

{ #category : 'execution' }
CUCreateUserWorkUnit >> executeInContext: context [
 ^ (context capability: CUUsersCapability) createUser: user
]

{ #category : 'accessing' }
CUCreateUserWorkUnit >> user [
 ^ user
]

{ #category : 'accessing' }
CUCreateUserWorkUnit >> user: aUser [
 user := aUser
]
