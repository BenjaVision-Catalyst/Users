"
Connect construction adapter for the existing Users create operation. Retains the Users WorkUnit capability and transaction contracts. Probe execution is read-only; the actual handler remains CUUsersService.
"
Class {
	#name : 'CUCreateUserMessageWork',
	#superclass : 'CUCreateUserWorkUnit',
	#instVars : [
		'probe'
	],
	#category : 'BVC-Users-Connect-Core',
	#package : 'BVC-Users-Connect-Core'
}

{ #category : 'execution' }
CUCreateUserMessageWork >> executeInContext: context [
 CCObjectCaller from: context.
 ^ [probe == true ifTrue: [true] ifFalse: [super executeInContext: context]]
  ensure: [self user: nil]
]

{ #category : 'object messaging' }
CUCreateUserMessageWork >> message: aUser [
 self user: aUser
]

{ #category : 'object messaging' }
CUCreateUserMessageWork >> probe: aBoolean [
 probe := aBoolean
]
