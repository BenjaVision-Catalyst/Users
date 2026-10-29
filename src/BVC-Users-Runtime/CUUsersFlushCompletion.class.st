"
Publishes reread states only at Runtime's verified finalization boundary: confirmed commit in GemStone, explicit volatile finalization in GT. Callback failure cannot replay mutations.
"
Class {
	#name : 'CUUsersFlushCompletion',
	#superclass : 'CRWorkUnitResultCompletion',
	#instVars : [
		'service',
		'epoch'
	],
	#category : 'BVC-Users-Runtime',
	#package : 'BVC-Users-Runtime'
}

{ #category : 'push updates' }
CUUsersFlushCompletion >> acceptResult: result in: context onWorker: worker [
 (worker isCompletingResult: self in: context) ifFalse: [self error: 'Runtime completion required.'].
 service publishChanges: result epoch: epoch
]

{ #category : 'push updates' }
CUUsersFlushCompletion >> acceptsInMemoryFinalization [
 ^ true
]

{ #category : 'push updates' }
CUUsersFlushCompletion >> afterCommit [
 ^ true
]

{ #category : 'push updates' }
CUUsersFlushCompletion >> afterFinalization [
 ^ true
]

{ #category : 'push updates' }
CUUsersFlushCompletion >> releaseCompletion [
 service := nil. epoch := nil
]

{ #category : 'push updates' }
CUUsersFlushCompletion >> service: value epoch: stamp [
 service := value. epoch := stamp
]
