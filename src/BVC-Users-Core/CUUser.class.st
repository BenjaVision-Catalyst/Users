"
A Catalyst Users model object. A name labels the user; isSuperUser identifies the designated super user. Identity, tenant ownership and further domain state will extend this model.
"
Class {
	#name : 'CUUser',
	#superclass : 'Object',
	#instVars : [
		'name',
		'superUser'
	],
	#category : 'BVC-Users-Core',
	#package : 'BVC-Users-Core'
}

{ #category : 'testing' }
CUUser >> isSuperUser [
 ^ superUser ifNil: [false]
]

{ #category : 'accessing' }
CUUser >> isSuperUser: aBoolean [
 superUser := aBoolean
]

{ #category : 'accessing' }
CUUser >> name [
 ^ name
]

{ #category : 'accessing' }
CUUser >> name: aString [
 name := aString
]
