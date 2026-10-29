"
Opt-in platform qualification only. A trusted gate directory pauses a marked Users creation after insertion and before the Runtime-owned commit; payloads never supply file paths.
"
Class {
	#name : 'CUUsersCommitGateMessageFixture',
	#superclass : 'CUUsersRollbackMessageFixture',
	#classVars : [
		'GateDirectory'
	],
	#category : 'BVC-Users-Connect-Tests',
	#package : 'BVC-Users-Connect-Tests'
}

{ #category : 'qualification' }
CUUsersCommitGateMessageFixture class >> gateDirectory [
 ^ GateDirectory
]

{ #category : 'qualification' }
CUUsersCommitGateMessageFixture class >> gateDirectory: aPath [
 GateDirectory := aPath
]

{ #category : 'execution' }
CUUsersCommitGateMessageFixture >> executeInContext: context [
 | input result directory deadline |
 input := self user. result := super executeInContext: context.
 (input notNil and: [input name endsWith: ':hold']) ifTrue: [
  directory := self class gateDirectory.
  (directory isString and: [directory notEmpty]) ifFalse: [self error: 'Trusted qualification gate required.'].
  CRPlatform current writeConnectEvidence: (Dictionary new at: 'name' put: input name; yourself) to: directory, '/inserted.json'.
  deadline := CRPlatform current currentMillis + 15000.
  [ (CRPlatform current connectFileExists: directory, '/release') or: [CRPlatform current currentMillis >= deadline] ]
   whileFalse: [(Delay forMilliseconds: 5) wait].
  (CRPlatform current connectFileExists: directory, '/release') ifFalse: [self error: 'Qualification commit gate timed out.'] ].
 ^ result
]
