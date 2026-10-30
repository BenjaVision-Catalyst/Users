Class {
	#name : 'CUUsersPublicationTestWork',
	#superclass : 'CUUpdateLiveUserWork',
	#instVars : [
		'afterBody'
	],
	#category : 'BVC-Users-Connect-Tests',
	#package : 'BVC-Users-Connect-Tests'
}

{ #category : 'tests - publication' }
CUUsersPublicationTestWork >> afterBody: block [
 afterBody := block
]

{ #category : 'tests - publication' }
CUUsersPublicationTestWork >> executeInContext: context [
 | result |
 result := super executeInContext: context.
 afterBody ifNotNil: [afterBody value: result value: context].
 ^ result
]
