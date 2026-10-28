"
Test-only probe of Runtime service/capability binding. Has no domain mutation or account data.
"
Class {
	#name : 'CUUsersBindingTestWorkUnit',
	#superclass : 'CUUsersWorkUnit',
	#instVars : [
		'executed',
		'serviceIdentifier'
	],
	#category : 'BVC-Users-Tests',
	#package : 'BVC-Users-Tests'
}

{ #category : 'execution' }
CUUsersBindingTestWorkUnit >> executeInContext: context [
(context capability: CUUsersCapability) class == CUUsersCapability ifFalse: [self error: 'Users capability was not bound'].
 executed := true. serviceIdentifier := context envelope serviceIdentifier copy.
 ^ #usersCapabilityBound
]

{ #category : 'accessing' }
CUUsersBindingTestWorkUnit >> executed [
^ executed == true
]

{ #category : 'accessing' }
CUUsersBindingTestWorkUnit >> serviceIdentifier [
^ serviceIdentifier copy
]
