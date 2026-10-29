"
Opt-in native qualification: hold a marked live creation before outer commit so the original connection can be lost. The trusted controller owns the file gate.
"
Class {
	#name : 'CUCreateLiveUserGateWork',
	#superclass : 'CUCreateLiveUserWork',
	#category : 'BVC-Users-Connect-Tests',
	#package : 'BVC-Users-Connect-Tests'
}

{ #category : 'execution' }
CUCreateLiveUserGateWork >> executeInContext: context [
 | input result directory deadline |
 input := change. result := super executeInContext: context.
 (input notNil and: [input name endsWith: ':lost-create']) ifTrue: [
  directory := CUUsersCommitGateMessageFixture gateDirectory.
  (directory isString and: [directory notEmpty]) ifFalse: [self error: 'Trusted qualification gate required.'].
  CRPlatform current writeConnectEvidence: (Dictionary new at: 'name' put: input name; yourself) to: directory, '/live-inserted.json'.
  deadline := CRPlatform current currentMillis + 15000.
  [(CRPlatform current connectFileExists: directory, '/live-release') or: [CRPlatform current currentMillis >= deadline]]
   whileFalse: [(Delay forMilliseconds: 5) wait].
  (CRPlatform current connectFileExists: directory, '/live-release') ifFalse: [self error: 'Live qualification gate timed out.']].
 (input notNil and: [input name endsWith: ':live-rollback']) ifTrue: [self error: 'Qualification failure after live Users insertion.'].
 ^ result
]
