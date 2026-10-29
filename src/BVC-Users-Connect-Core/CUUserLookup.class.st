"
Installed description-owned exact-name lookup input. No storage or transport state.
"
Class {
	#name : 'CUUserLookup',
	#superclass : 'Object',
	#instVars : [
		'name'
	],
	#category : 'BVC-Users-Connect-Core',
	#package : 'BVC-Users-Connect-Core'
}

{ #category : 'initialization' }
CUUserLookup >> initialize [
 super initialize. name := ''
]

{ #category : 'magritte' }
CUUserLookup >> magritteDescription [
 ^ MAContainer withAll: {CUUser new descriptionName}
]

{ #category : 'accessing' }
CUUserLookup >> name [
 ^ name
]

{ #category : 'accessing' }
CUUserLookup >> name: exactName [
 name := exactName
]
