"
Connect adapter for authoritative lookup. Probes are read-only. Missing and ambiguous results are distinct installed outcomes, published only through Runtime completion.
"
Class {
	#name : 'CUGetUserMessageWork',
	#superclass : 'CUGetUserWorkUnit',
	#instVars : [
		'probe'
	],
	#category : 'BVC-Users-Connect-Core',
	#package : 'BVC-Users-Connect-Core'
}

{ #category : 'execution' }
CUGetUserMessageWork >> executeInContext: context [
 CCObjectCaller from: context.
 ^ [[probe == true ifTrue: [true] ifFalse: [super executeInContext: context]]
  on: CUAmbiguousUserError do: [:error | #ambiguous]] ensure: [self name: nil]
]

{ #category : 'object messaging' }
CUGetUserMessageWork >> message: query [
 self name: query name
]

{ #category : 'object messaging' }
CUGetUserMessageWork >> probe: aBoolean [
 probe := aBoolean
]
