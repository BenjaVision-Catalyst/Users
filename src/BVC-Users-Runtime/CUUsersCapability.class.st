"
Narrow Users creation and exact-name lookup capability for installed CUUsersWorkUnit subclasses. Bound to one service activation epoch; expires across stop/restart. Carries no service-control or authentication authority.
"
Class {
	#name : 'CUUsersCapability',
	#superclass : 'CRServiceBoundCapability',
	#instVars : [
		'epoch'
	],
	#category : 'BVC-Users-Runtime',
	#package : 'BVC-Users-Runtime'
}

{ #category : 'authority' }
CUUsersCapability class >> canBeGrantedToServiceClass: serviceClass [
^ false
]

{ #category : 'authority' }
CUUsersCapability class >> canBeGrantedToWorkUnitClass: workClass [
^ workClass inheritsFrom: CUUsersWorkUnit
]

{ #category : 'initialization' }
CUUsersCapability >> bindService: aService [
 super bindService: aService.
 epoch := aService resultEpoch
]

{ #category : 'users api' }
CUUsersCapability >> createUser: aUser [
 (service isCurrentResultEpoch: epoch) ifFalse: [CRCapabilityDeniedException signal: 'Users capability has expired.'].
 ^ service createUser: aUser
]

{ #category : 'push updates' }
CUUsersCapability >> drainChanges [
 (service isCurrentResultEpoch: epoch) ifFalse: [CRCapabilityDeniedException signal: 'Users capability has expired.'].
 ^ service drainChanges
]

{ #category : 'users api' }
CUUsersCapability >> getUser: exactName [
 (service isCurrentResultEpoch: epoch) ifFalse: [CRCapabilityDeniedException signal: 'Users capability has expired.'].
 ^ service getUser: exactName
]

{ #category : 'live users' }
CUUsersCapability >> liveUser: change operation: code principal: principal [
 (service isCurrentResultEpoch: epoch) ifFalse: [CRCapabilityDeniedException signal: 'Users capability has expired.'].
 ^ service liveUser: change operation: code principal: principal
]

{ #category : 'result publication' }
CUUsersCapability >> liveUser: change operation: code principal: principal completion: completion in: context [
 (service isCurrentResultEpoch: epoch) ifFalse: [CRCapabilityDeniedException signal: 'Users capability has expired.'].
 ((context capability: CUUsersCapability) == self and: [context envelope resultCompletion == completion]) ifFalse: [self error: 'Bound Users result completion required'].
 completion preparePublicationUsing: self in: context.
 ^ service liveUser: change operation: code principal: principal stagingChanges: false
]

{ #category : 'result publication' }
CUUsersCapability >> publicationFailedFor: completion in: context onWorker: worker [
 self verifyPublicationCompletion: completion in: context onWorker: worker.
 service closePublicationFeeds
]

{ #category : 'result publication' }
CUUsersCapability >> publishCommittedUser: state completion: completion in: context onWorker: worker [
 self verifyPublicationCompletion: completion in: context onWorker: worker.
 state class == CULiveUserState ifFalse: [self error: 'Bounded live User state required'].
 (#('created' 'updated') includes: state outcome) ifFalse: [^ self].
 service publishChanges: {(CULiveUserState from: state outcome: 'current')} epoch: epoch
]

{ #category : 'result publication' }
CUUsersCapability >> verifyPublicationCompletion: completion in: context onWorker: worker [
 ((worker isKindOf: CRAbstractWorker) and: [
  (completion isKindOf: CRWorkUnitResultCompletion) and: [
  (worker isCompletingResult: completion in: context) and: [
  (context capability: CUUsersCapability) == self and: [service isCurrentResultEpoch: epoch]]]])
 ifFalse: [self error: 'Current Users publication completion required.']
]
