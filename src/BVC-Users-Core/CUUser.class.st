"
A Catalyst Users model object. A name labels the user; isSuperUser identifies the designated super user. Identity, tenant ownership and further domain state will extend this model.
"
Class {
	#name : 'CUUser',
	#superclass : 'Object',
	#instVars : [
		'name',
		'superUser',
		'userIdentifier',
		'revision',
		'creationIdentifier',
		'creationPrincipal',
		'creationName'
	],
	#category : 'BVC-Users-Core',
	#package : 'BVC-Users-Core'
}

{ #category : 'live users' }
CUUser >> creationIdentifier [
 ^ creationIdentifier ifNil: ['']
]

{ #category : 'live users' }
CUUser >> creationIdentifier: key principal: owner name: initialName [
 creationIdentifier ifNotNil: [self error: 'Creation receipt is immutable.'].
 creationIdentifier := key copy. creationPrincipal := owner copy. creationName := initialName copy
]

{ #category : 'live users' }
CUUser >> creationName [
 ^ creationName ifNil: ['']
]

{ #category : 'live users' }
CUUser >> creationPrincipal [
 ^ creationPrincipal ifNil: ['']
]

{ #category : 'live users' }
CUUser >> ensureIdentity [
 userIdentifier ifNil: [userIdentifier := UUID new asString36. revision := 1]. ^ self
]

{ #category : 'testing' }
CUUser >> isSuperUser [
 ^ superUser ifNil: [false]
]

{ #category : 'accessing' }
CUUser >> isSuperUser: value [
 (userIdentifier notNil and: [self isSuperUser ~= value]) ifTrue: [revision := self revision + 1].
 superUser := value
]

{ #category : 'accessing' }
CUUser >> name [
 ^ name
]

{ #category : 'accessing' }
CUUser >> name: value [
 (userIdentifier notNil and: [name ~= value]) ifTrue: [revision := self revision + 1].
 name := value
]

{ #category : 'live users' }
CUUser >> revision [
 ^ revision ifNil: [0]
]

{ #category : 'live users' }
CUUser >> revision: value [
 (value isInteger and: [value >= 0]) ifFalse: [self error: 'Revision required.'].
 revision := value
]

{ #category : 'live users' }
CUUser >> userIdentifier [
 ^ userIdentifier ifNil: ['']
]

{ #category : 'live users' }
CUUser >> userIdentifier: value [
 (userIdentifier notNil and: [userIdentifier ~= value]) ifTrue: [self error: 'User identity is immutable.'].
 userIdentifier := value
]
