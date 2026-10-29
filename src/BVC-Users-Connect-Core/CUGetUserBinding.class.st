"
Installed lookup outcome mapping: a CUUser uses its existing description; nil is not found, and an ambiguous name is refused. No domain codec.
"
Class {
	#name : 'CUGetUserBinding',
	#superclass : 'CCObjectBinding',
	#category : 'BVC-Users-Connect-Core',
	#package : 'BVC-Users-Connect-Core'
}

{ #category : 'object messaging' }
CUGetUserBinding >> statusForResult: result [
 result ifNil: [^ 404].
 result = #ambiguous ifTrue: [^ 422].
 ^ super statusForResult: result
]
