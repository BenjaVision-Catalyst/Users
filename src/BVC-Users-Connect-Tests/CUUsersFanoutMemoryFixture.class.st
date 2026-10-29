"
Data-only export sink for sampler lifecycle examples; performs no native I/O.
"
Class {
	#name : 'CUUsersFanoutMemoryFixture',
	#superclass : 'CUUsersFanoutApplicationFixture',
	#instVars : [
		'writes'
	],
	#category : 'BVC-Users-Connect-Tests',
	#package : 'BVC-Users-Connect-Tests'
}

{ #category : 'qualification' }
CUUsersFanoutMemoryFixture >> writeDiagnostic: value name: name [
 writes ifNil: [writes := OrderedCollection new].
 writes add: {name. value}
]

{ #category : 'qualification' }
CUUsersFanoutMemoryFixture >> writes [
 ^ writes ifNil: [#()]
]
