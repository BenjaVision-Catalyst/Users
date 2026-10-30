"
One Runtime-verified completion for a live User mutation: publishes only the bounded committed result, then completes the existing object response. No mutation replay or additional transaction.
"
Class {
	#name : 'CUUsersMutationResultCompletion',
	#superclass : 'CCObjectResultCompletion',
	#instVars : [
		'publicationCapability',
		'publicationContext'
	],
	#category : 'BVC-Users-Connect-Core',
	#package : 'BVC-Users-Connect-Core'
}

{ #category : 'result publication' }
CUUsersMutationResultCompletion >> completeVerifiedResult: result in: context onWorker: worker [
 | encoded |
 (context == publicationContext and: [publicationCapability notNil]) ifFalse: [self error: 'Prepared Users mutation completion required'].
 [encoded := binding responseForResult: result probe: false.
  encoded second = 0 ifTrue: [
   publicationCapability publishCommittedUser: result completion: self in: context onWorker: worker].
  response complete: encoded first status: encoded second]
 on: Error do: [:error |
  publicationCapability publicationFailedFor: self in: context onWorker: worker. error pass]
]

{ #category : 'result publication' }
CUUsersMutationResultCompletion >> preparePublicationUsing: capability in: context [
 (self state == #pending and: [publicationCapability isNil and: [probe == false and: [
  context envelope resultCompletion == self and: [
  (context envelope workUnit isKindOf: CULiveUserWork) and: [
  (#(3 5) includes: binding operation) and: [context envelope workUnit class operation = binding operation]]]]]])
 ifFalse: [self error: 'One installed Users mutation completion required'].
 publicationCapability := capability. publicationContext := context
]

{ #category : 'result publication' }
CUUsersMutationResultCompletion >> releaseCompletion [
 [super releaseCompletion] ensure: [publicationCapability := nil. publicationContext := nil]
]
