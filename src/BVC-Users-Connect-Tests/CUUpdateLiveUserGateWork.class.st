"
Trusted native qualification only: hold an edit before finalization or fail it after mutation.
"
Class {
	#name : 'CUUpdateLiveUserGateWork',
	#superclass : 'CUUpdateLiveUserWork',
	#category : 'BVC-Users-Connect-Tests',
	#package : 'BVC-Users-Connect-Tests'
}

{ #category : 'push updates' }
CUUpdateLiveUserGateWork >> executeInContext: context [
 | input result directory deadline |
 input := change. result := super executeInContext: context.
 (input notNil and: [input name endsWith: ':push-held']) ifTrue: [
  directory := CUUsersCommitGateMessageFixture gateDirectory.
  (directory isString and: [directory notEmpty]) ifFalse: [self error: 'Trusted qualification gate required.'].
  CRPlatform current writeConnectEvidence: (Dictionary new at: 'name' put: input name; yourself) to: directory, '/push-inserted.json'.
  deadline := CRPlatform current currentMillis + 15000.
  [(CRPlatform current connectFileExists: directory, '/push-release') or: [CRPlatform current currentMillis >= deadline]] whileFalse: [(Delay forMilliseconds: 5) wait].
  (CRPlatform current connectFileExists: directory, '/push-release') ifFalse: [self error: 'Push qualification gate timed out.']].
 (input notNil and: [input name endsWith: ':push-rollback']) ifTrue: [self error: 'Qualification failure after watched Users update.'].
 ^ result
]
