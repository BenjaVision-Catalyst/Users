"
Inert live User command. Operation identity is scoped to verified caller by the service; it never selects authority or supplies a capability.
"
Class {
	#name : 'CUUserChange',
	#superclass : 'Object',
	#instVars : [
		'userIdentifier',
		'operationIdentifier',
		'expectedRevision',
		'name'
	],
	#category : 'BVC-Users-Core',
	#package : 'BVC-Users-Core'
}

{ #category : 'live users' }
CUUserChange >> expectedRevision [
 ^ expectedRevision ifNil: [0]
]

{ #category : 'live users' }
CUUserChange >> expectedRevision: value [
 expectedRevision := value
]

{ #category : 'live users' }
CUUserChange >> name [
 ^ name ifNil: ['']
]

{ #category : 'live users' }
CUUserChange >> name: value [
 name := value
]

{ #category : 'live users' }
CUUserChange >> operationIdentifier [
 ^ operationIdentifier ifNil: ['']
]

{ #category : 'live users' }
CUUserChange >> operationIdentifier: value [
 operationIdentifier := value
]

{ #category : 'live users' }
CUUserChange >> userIdentifier [
 ^ userIdentifier ifNil: ['']
]

{ #category : 'live users' }
CUUserChange >> userIdentifier: value [
 userIdentifier := value
]
