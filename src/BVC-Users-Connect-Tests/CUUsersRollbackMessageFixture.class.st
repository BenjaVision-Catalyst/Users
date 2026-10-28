"
Native qualification adapter that raises after insertion for its explicitly marked rollback input. No production or wire-selected execution policy.
"
Class {
	#name : 'CUUsersRollbackMessageFixture',
	#superclass : 'CUCreateUserMessageWork',
	#category : 'BVC-Users-Connect-Tests',
	#package : 'BVC-Users-Connect-Tests'
}

{ #category : 'execution' }
CUUsersRollbackMessageFixture >> executeInContext: context [
 | input result |
 input := self user. result := super executeInContext: context.
 (input notNil and: [input name endsWith: ':rollback']) ifTrue: [self error: 'Qualification failure after Users insertion.'].
 ^ result
]
