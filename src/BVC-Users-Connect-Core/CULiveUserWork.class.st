"
Installed live User operation. Actual caller comes from verified Runtime context. No replay or transport state in persistent Users.
"
Class {
	#name : 'CULiveUserWork',
	#superclass : 'CUUsersWorkUnit',
	#instVars : [
		'change',
		'probe'
	],
	#category : 'BVC-Users-Connect-Core',
	#package : 'BVC-Users-Connect-Core'
}

{ #category : 'contracts' }
CULiveUserWork class >> allowsConflictReplay [
 ^ false
]

{ #category : 'contracts' }
CULiveUserWork class >> requiresTransaction [
 ^ true
]

{ #category : 'live users' }
CULiveUserWork >> executeInContext: context [
 | caller |
 caller := CCObjectCaller from: context.
 ^ [probe == true ifTrue: [true] ifFalse: [(context capability: CUUsersCapability) liveUser: change operation: self class operation principal: caller identity]] ensure: [change := nil]
]

{ #category : 'live users' }
CULiveUserWork >> message: request [
 change := request
]

{ #category : 'live users' }
CULiveUserWork >> probe: value [
 probe := value
]
