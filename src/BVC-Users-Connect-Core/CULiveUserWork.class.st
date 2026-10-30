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

{ #category : 'result publication' }
CULiveUserWork >> executeInContext: context [
 | caller capability completion |
 caller := CCObjectCaller from: context.
 ^ [probe == true ifTrue: [true] ifFalse: [
  capability := context capability: CUUsersCapability.
  completion := context envelope resultCompletion.
  (completion isKindOf: CUUsersMutationResultCompletion)
   ifTrue: [capability liveUser: change operation: self class operation principal: caller identity completion: completion in: context]
   ifFalse: [capability liveUser: change operation: self class operation principal: caller identity]]]
 ensure: [change := nil]
]

{ #category : 'live users' }
CULiveUserWork >> message: request [
 change := request
]

{ #category : 'live users' }
CULiveUserWork >> probe: value [
 probe := value
]
