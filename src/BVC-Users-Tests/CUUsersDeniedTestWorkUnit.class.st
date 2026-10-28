"
Unrelated work requesting the Users capability to prove denial before execution.
"
Class {
	#name : 'CUUsersDeniedTestWorkUnit',
	#superclass : 'CRWorkUnit',
	#instVars : [
		'executed'
	],
	#category : 'BVC-Users-Tests',
	#package : 'BVC-Users-Tests'
}

{ #category : 'contracts' }
CUUsersDeniedTestWorkUnit class >> requiredCapabilities [
^ {CUUsersCapability}
]

{ #category : 'contracts' }
CUUsersDeniedTestWorkUnit class >> serviceClass [
^ CUUsersService
]

{ #category : 'execution' }
CUUsersDeniedTestWorkUnit >> executeInContext: context [
executed := true
]

{ #category : 'accessing' }
CUUsersDeniedTestWorkUnit >> executed [
^ executed == true
]
