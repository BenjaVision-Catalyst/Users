"
Exact-name lookup through the named authoritative Users capability. Uses the existing repository transaction and never automatically replays.
"
Class {
	#name : 'CUGetUserWorkUnit',
	#superclass : 'CUUsersWorkUnit',
	#instVars : [
		'name'
	],
	#category : 'BVC-Users-Runtime',
	#package : 'BVC-Users-Runtime'
}

{ #category : 'contracts' }
CUGetUserWorkUnit class >> allowsConflictReplay [
 ^ false
]

{ #category : 'instance creation' }
CUGetUserWorkUnit class >> named: exactName [
 ^ self new name: exactName; yourself
]

{ #category : 'contracts' }
CUGetUserWorkUnit class >> requiresTransaction [
 ^ true
]

{ #category : 'execution' }
CUGetUserWorkUnit >> executeInContext: context [
 ^ (context capability: CUUsersCapability) getUser: name
]

{ #category : 'accessing' }
CUGetUserWorkUnit >> name [
 ^ name
]

{ #category : 'accessing' }
CUGetUserWorkUnit >> name: exactName [
 name := exactName
]
